// MXW01 미니 감열 프린터의 Web Bluetooth 전송. 바이트를 만드는 일은 mxw01-protocol.ts(순수 함수)가 하고, 여기서는 연결·쓰기·알림 대기만 한다.
// Web Bluetooth 는 Chrome·Edge 에만 있고(Safari·Firefox 없음) https 또는 localhost 에서만 동작한다. 기기 선택 창은 버튼 클릭 같은 사용자 동작 안에서만 열 수 있다.
// 출처(동작 참고, 직접 작성): dave9123/MXW01-catprinter · jeremy46231/MXW01-catprinter 의 catprinter/ble.py (MIT), clementvp/mxw01-thermal-printer 의 WebBluetoothAdapter.ts · ThermalPrinterClient.ts (MIT)
import {
  MXW01_CHUNK_DELAY_MS,
  MXW01_CMD,
  MXW01_DEFAULT_INTENSITY,
  MXW01_ROW_BYTES,
  MXW01_UUID,
  buildPrintWrites,
  cmdGetStatus,
  parseNotification,
  parseStatus,
  printCompleteTimeoutMs,
  statusErrorMessage,
  toHex,
  type Mxw01PrintData,
  type Mxw01Status,
} from './mxw01-protocol';

export type PrinterState = 'idle' | 'connecting' | 'connected' | 'printing' | 'disconnected';

/** 사용자에게 그대로 보여줄 수 있는 한국어 메시지를 담은 오류 */
export class PrinterError extends Error {}

export interface PrinterListeners {
  /** 진단 로그 한 줄 (BLE 이벤트·보낸 명령·받은 알림) */
  onLog: (message: string) => void;
  onState: (state: PrinterState, deviceName: string | null) => void;
}

export interface PrintOptions {
  /** 인쇄 농도 0~255 */
  intensity?: number;
  /** 진단용: 상태(A1)·인쇄 요청(A9) 응답이 없어도 멈추지 않고 데이터를 보낸다 */
  ignoreResponses?: boolean;
  onProgress?: (sentChunks: number, totalChunks: number) => void;
}

export interface PrintResult {
  /** 프린터가 인쇄 완료(AA)를 알렸는지. false 면 시간 안에 알림이 오지 않았다 (인쇄는 됐을 수 있다) */
  completed: boolean;
}

const RESPONSE_TIMEOUT_MS = 5000; // 상태·인쇄 요청 응답 대기 (출처: 5~7초)
const IGNORED_RESPONSE_TIMEOUT_MS = 1500; // 진단용(ignoreResponses)일 때의 짧은 대기
const AFTER_COMMAND_DELAY_MS = 100; // 농도·끝 알림 명령 뒤 쉬는 시간 (출처: 50~100ms)
const CONNECT_ATTEMPTS = 2; // Chrome 은 첫 GATT 연결이 가끔 실패한다 → 한 번 더 시도
const LOG_EVERY_CHUNKS = 100;
const SEND_PHASE_TIMEOUT_MS = 10 * 60 * 1000; // 데이터를 보내는 동안의 완료 알림 대기 상한 (끝 알림을 보낸 뒤에는 printCompleteTimeoutMs 로 다시 잰다)

const sleep = (ms: number): Promise<void> => new Promise((resolve) => window.setTimeout(resolve, ms));

function describe(error: unknown): string {
  return error instanceof Error ? `${error.name}: ${error.message}` : String(error);
}

interface Waiter {
  resolve: (payload: Uint8Array) => void;
  reject: (error: Error) => void;
  timer: number;
}

/** 응답 대기 시간이 지났다 (PrinterError 와 구분해 진단용 모드에서 넘어갈 수 있게 한다) */
class ResponseTimeout extends Error {}

export class Mxw01Printer {
  private readonly listeners: PrinterListeners;
  private state: PrinterState = 'idle';
  private device: BluetoothDevice | null = null;
  private control: BluetoothRemoteGATTCharacteristic | null = null;
  private data: BluetoothRemoteGATTCharacteristic | null = null;
  private notify: BluetoothRemoteGATTCharacteristic | null = null;
  private readonly waiters = new Map<number, Waiter>();
  private busy = false;

  constructor(listeners: PrinterListeners) {
    this.listeners = listeners;
  }

  /** 이 브라우저에 Web Bluetooth 가 있는지 (Safari·Firefox 는 false) */
  static isSupported(): boolean {
    return typeof navigator !== 'undefined' && navigator.bluetooth !== undefined;
  }

  get isConnected(): boolean {
    return this.state === 'connected' || this.state === 'printing';
  }

  /** 전에 고른 기기가 있어 선택 창 없이 다시 연결할 수 있는지 */
  get canReconnect(): boolean {
    return this.device !== null && !this.isConnected && this.state !== 'connecting';
  }

  private log(message: string): void {
    this.listeners.onLog(message);
  }

  private setState(state: PrinterState): void {
    this.state = state;
    this.listeners.onState(state, this.device?.name ?? null);
  }

  /**
   * 기기 선택 창을 열고 연결한다. 반드시 클릭 핸들러에서 바로 부른다.
   * anyDevice = true 면 서비스 필터 없이 주변 모든 BLE 기기를 보여준다 (프린터가 서비스 UUID 를 광고하지 않아 목록에 안 뜰 때의 대안).
   */
  async connect(anyDevice = false): Promise<void> {
    const bluetooth = navigator.bluetooth;
    if (!bluetooth) throw new PrinterError('이 브라우저는 블루투스 프린터를 지원하지 않아요. 맥북의 Chrome 에서 열어주세요');
    if (this.busy || this.state === 'connecting') throw new PrinterError('이미 프린터 작업을 하고 있어요');

    const optionalServices = [MXW01_UUID.service, MXW01_UUID.serviceAlt];
    const options: RequestDeviceOptions = anyDevice
      ? { acceptAllDevices: true, optionalServices }
      : { filters: [{ services: [MXW01_UUID.service] }, { services: [MXW01_UUID.serviceAlt] }], optionalServices };
    this.log(`기기 선택 창 열기: ${anyDevice ? '모든 기기' : `서비스 필터 ${MXW01_UUID.service.slice(4, 8)} / ${MXW01_UUID.serviceAlt.slice(4, 8)}`}`);

    let device: BluetoothDevice;
    try {
      device = await bluetooth.requestDevice(options);
    } catch (error) {
      this.log(`기기 선택 실패 — ${describe(error)}`);
      const name = error instanceof Error ? error.name : '';
      if (name === 'NotFoundError') throw new PrinterError('프린터를 고르지 않았어요. 프린터 전원을 켜고 다시 눌러주세요');
      if (name === 'SecurityError' || name === 'NotAllowedError') throw new PrinterError('브라우저가 블루투스 사용을 막았어요. 주소가 https 인지, Chrome 의 블루투스 권한을 확인해주세요');
      throw new PrinterError('블루투스를 쓸 수 없어요. 맥북의 블루투스가 켜져 있는지 확인해주세요');
    }

    if (this.device && this.device !== device) {
      this.device.removeEventListener('gattserverdisconnected', this.onDisconnected);
      this.device.gatt?.disconnect();
    }
    this.device = device;
    device.removeEventListener('gattserverdisconnected', this.onDisconnected);
    device.addEventListener('gattserverdisconnected', this.onDisconnected);
    this.log(`기기 선택됨: 이름 "${device.name ?? '(없음)'}", id ${device.id}`);
    await this.open();
  }

  /** 전에 고른 기기에 선택 창 없이 다시 연결한다 (프린터가 꺼졌다 켜졌을 때) */
  async reconnect(): Promise<void> {
    if (!this.device) throw new PrinterError('먼저 프린터를 연결해주세요');
    if (this.busy || this.state === 'connecting') throw new PrinterError('이미 프린터 작업을 하고 있어요');
    this.log('다시 연결 시도');
    await this.open();
  }

  disconnect(): void {
    this.log('연결 끊기 요청');
    const gatt = this.device?.gatt;
    if (gatt?.connected) gatt.disconnect();
    else this.onDisconnected();
  }

  private async open(): Promise<void> {
    const gatt = this.device?.gatt;
    if (!gatt) throw new PrinterError('이 기기는 연결할 수 없어요 (GATT 없음). 다른 기기를 골랐는지 확인해주세요');
    this.setState('connecting');
    let lastError: unknown = null;
    for (let attempt = 1; attempt <= CONNECT_ATTEMPTS; attempt++) {
      try {
        this.log(`GATT 연결 시도 ${attempt}/${CONNECT_ATTEMPTS}`);
        const server = await gatt.connect();
        const service = await this.findService(server);
        this.log(`서비스 찾음: ${service.uuid}`);
        const [control, notify, data] = await Promise.all([service.getCharacteristic(MXW01_UUID.control), service.getCharacteristic(MXW01_UUID.notify), service.getCharacteristic(MXW01_UUID.data)]);
        this.log(`특성 찾음: ae01 ${this.describeProps(control)} / ae02 ${this.describeProps(notify)} / ae03 ${this.describeProps(data)}`);
        this.notify?.removeEventListener('characteristicvaluechanged', this.onNotification);
        notify.addEventListener('characteristicvaluechanged', this.onNotification);
        await notify.startNotifications();
        this.log('알림 구독 시작 (ae02)');
        this.control = control;
        this.notify = notify;
        this.data = data;
        this.setState('connected');
        return;
      } catch (error) {
        lastError = error;
        this.log(`연결 실패 — ${describe(error)}`);
        if (gatt.connected) gatt.disconnect();
      }
    }
    this.clearCharacteristics();
    this.setState('disconnected');
    const name = lastError instanceof Error ? lastError.name : '';
    if (name === 'NotFoundError') throw new PrinterError('이 기기에서 프린터 서비스를 찾지 못했어요. MXW01 프린터를 골랐는지 확인해주세요');
    throw new PrinterError('프린터에 연결하지 못했어요. 프린터 전원이 켜져 있는지 확인하고 다시 시도해주세요');
  }

  private async findService(server: BluetoothRemoteGATTServer): Promise<BluetoothRemoteGATTService> {
    try {
      return await server.getPrimaryService(MXW01_UUID.service);
    } catch (error) {
      this.log(`서비스 ae30 없음(${describe(error)}) → af30 으로 다시 찾기`);
      return server.getPrimaryService(MXW01_UUID.serviceAlt);
    }
  }

  private describeProps(characteristic: BluetoothRemoteGATTCharacteristic): string {
    const p = characteristic.properties;
    const names = [p.write && 'write', p.writeWithoutResponse && 'writeWithoutResponse', p.notify && 'notify'].filter(Boolean);
    return `[${names.join(', ') || '없음'}]`;
  }

  private clearCharacteristics(): void {
    this.notify?.removeEventListener('characteristicvaluechanged', this.onNotification);
    this.control = null;
    this.data = null;
    this.notify = null;
  }

  // 화살표 함수 속성: add/removeEventListener 에 같은 참조를 넘기기 위해서다
  private readonly onDisconnected = (): void => {
    // 연결을 시도하는 중의 끊김은 open() 이 다시 시도하거나 실패로 처리한다
    if (this.state === 'idle' || this.state === 'disconnected' || this.state === 'connecting') return;
    this.log('연결 끊김 (gattserverdisconnected)');
    this.clearCharacteristics();
    this.rejectWaiters(new PrinterError('프린터 연결이 끊어졌어요. 전원을 확인하고 다시 연결해주세요'));
    this.setState('disconnected');
  };

  private readonly onNotification = (event: Event): void => {
    const view = (event.target as BluetoothRemoteGATTCharacteristic).value;
    if (!view) return;
    const bytes = new Uint8Array(view.buffer.slice(view.byteOffset, view.byteOffset + view.byteLength));
    const parsed = parseNotification(bytes);
    if (!parsed) {
      this.log(`알림(형식 모름): ${toHex(bytes)}`);
      return;
    }
    const id = parsed.commandId.toString(16);
    this.log(`알림 ${id}: ${toHex(bytes)}${parsed.crcOk === false ? ' (CRC 불일치)' : ''}`);
    if (parsed.commandId === MXW01_CMD.getStatus) this.logStatus(parseStatus(parsed.payload));
    const waiter = this.waiters.get(parsed.commandId);
    if (waiter) {
      this.waiters.delete(parsed.commandId);
      window.clearTimeout(waiter.timer);
      waiter.resolve(parsed.payload);
    }
  };

  private logStatus(status: Mxw01Status): void {
    const flag = status.ok === null ? '판단 불가(응답이 짧음)' : status.ok ? '정상' : `오류 코드 ${status.errorCode}`;
    this.log(`상태 해석: ${flag}, 상태값 ${status.state ?? '-'}, 배터리 ${status.battery ?? '-'}, 온도 ${status.temperature ?? '-'}`);
  }

  private waitFor(commandId: number, timeoutMs: number): Promise<Uint8Array> {
    const previous = this.waiters.get(commandId);
    if (previous) {
      window.clearTimeout(previous.timer);
      previous.reject(new ResponseTimeout('새 요청으로 대체됨'));
    }
    return new Promise<Uint8Array>((resolve, reject) => {
      const timer = window.setTimeout(() => {
        this.waiters.delete(commandId);
        reject(new ResponseTimeout(`알림 ${commandId.toString(16)} 을(를) ${timeoutMs}ms 안에 받지 못함`));
      }, timeoutMs);
      this.waiters.set(commandId, { resolve, reject, timer });
    });
  }

  /** 기다리는 중인 알림의 제한 시간을 지금부터 다시 잰다 */
  private restartWaiterTimer(commandId: number, timeoutMs: number): void {
    const waiter = this.waiters.get(commandId);
    if (!waiter) return;
    window.clearTimeout(waiter.timer);
    waiter.timer = window.setTimeout(() => {
      this.waiters.delete(commandId);
      waiter.reject(new ResponseTimeout(`알림 ${commandId.toString(16)} 을(를) ${timeoutMs}ms 안에 받지 못함`));
    }, timeoutMs);
  }

  private cancelWaiter(commandId: number): void {
    const waiter = this.waiters.get(commandId);
    if (!waiter) return;
    this.waiters.delete(commandId);
    window.clearTimeout(waiter.timer);
  }

  private rejectWaiters(error: Error): void {
    for (const waiter of this.waiters.values()) {
      window.clearTimeout(waiter.timer);
      waiter.reject(error);
    }
    this.waiters.clear();
  }

  private async write(characteristic: BluetoothRemoteGATTCharacteristic | null, bytes: Uint8Array): Promise<void> {
    if (!characteristic) throw new PrinterError('프린터가 연결되어 있지 않아요. 다시 연결해주세요');
    // 두 특성 모두 "응답 없는 쓰기"로 알려져 있다. 기기가 응답 있는 쓰기만 알리면 그쪽을 쓴다
    const payload = bytes as Uint8Array<ArrayBuffer>;
    try {
      if (characteristic.properties.writeWithoutResponse || !characteristic.properties.write) await characteristic.writeValueWithoutResponse(payload);
      else await characteristic.writeValueWithResponse(payload);
    } catch (error) {
      this.log(`쓰기 실패 (${characteristic.uuid.slice(4, 8)}) — ${describe(error)}`);
      throw new PrinterError('프린터로 데이터를 보내지 못했어요. 연결을 확인하고 다시 시도해주세요');
    }
  }

  /** 명령을 보내고 같은 번호의 알림을 기다린다. 대기를 먼저 걸어 두고 쓴다 (응답이 쓰기보다 먼저 처리되는 것을 막는다) */
  private async request(command: Uint8Array, responseId: number, timeoutMs: number): Promise<Uint8Array> {
    const response = this.waitFor(responseId, timeoutMs);
    response.catch(() => undefined); // 쓰기가 먼저 실패해도 처리되지 않은 거부가 남지 않게 한다
    this.log(`명령 ${responseId.toString(16)}: ${toHex(command)}`);
    try {
      await this.write(this.control, command);
    } catch (error) {
      this.cancelWaiter(responseId);
      throw error;
    }
    return response;
  }

  /** 프린터 상태를 묻는다 (연결 확인용) */
  async getStatus(): Promise<Mxw01Status> {
    if (this.busy) throw new PrinterError('이미 프린터 작업을 하고 있어요');
    this.busy = true;
    try {
      return parseStatus(await this.request(cmdGetStatus(), MXW01_CMD.getStatus, RESPONSE_TIMEOUT_MS));
    } catch (error) {
      if (error instanceof ResponseTimeout) throw new PrinterError('프린터가 상태 요청에 응답하지 않아요');
      throw error;
    } finally {
      this.busy = false;
    }
  }

  /**
   * 인쇄한다: 농도 → 상태 확인 → 인쇄 요청 → 데이터(48바이트씩, 15ms 간격) → 끝 알림 → 인쇄 완료 대기.
   * 용지 없음 같은 상태 오류와 연결 문제는 한국어 메시지의 PrinterError 로 던진다.
   */
  async print(print: Mxw01PrintData, options: PrintOptions = {}): Promise<PrintResult> {
    if (this.busy) throw new PrinterError('이미 인쇄하고 있어요. 끝난 뒤 다시 눌러주세요');
    if (!this.isConnected) {
      if (!this.device) throw new PrinterError('먼저 프린터를 연결해주세요');
      await this.reconnect();
    }
    if (print.data.length !== print.lineCount * MXW01_ROW_BYTES) throw new PrinterError('인쇄 데이터가 올바르지 않아요');

    const ignore = options.ignoreResponses === true;
    const responseTimeout = ignore ? IGNORED_RESPONSE_TIMEOUT_MS : RESPONSE_TIMEOUT_MS;
    const [intensity, status, request, ...rest] = buildPrintWrites(print, options.intensity ?? MXW01_DEFAULT_INTENSITY);
    const flush = rest[rest.length - 1];
    const chunks = rest.slice(0, -1);

    this.busy = true;
    this.setState('printing');
    try {
      this.log(`인쇄 시작: ${print.lineCount}줄, ${print.data.length}바이트, 조각 ${chunks.length}개${ignore ? ' (진단용: 응답 무시)' : ''}`);
      this.log(`명령 a2: ${toHex(intensity.bytes)}`);
      await this.write(this.control, intensity.bytes);
      await sleep(AFTER_COMMAND_DELAY_MS);

      try {
        const parsed = parseStatus(await this.request(status.bytes, MXW01_CMD.getStatus, responseTimeout));
        if (parsed.ok === false && !ignore) throw new PrinterError(statusErrorMessage(parsed.errorCode));
      } catch (error) {
        if (!(error instanceof ResponseTimeout)) throw error;
        this.log(`상태 응답 없음 — ${error.message}`);
        if (!ignore) throw new PrinterError('프린터가 상태 요청에 응답하지 않아요. 전원을 껐다 켜고 다시 연결해주세요');
      }

      try {
        const ack = await this.request(request.bytes, MXW01_CMD.printRequest, responseTimeout);
        if (ack.length > 0 && ack[0] !== 0 && !ignore) throw new PrinterError('프린터가 인쇄 요청을 거절했어요. 용지와 덮개를 확인하고 다시 시도해주세요');
      } catch (error) {
        if (!(error instanceof ResponseTimeout)) throw error;
        this.log(`인쇄 요청 응답 없음 — ${error.message}`);
        if (!ignore) throw new PrinterError('프린터가 인쇄 요청에 응답하지 않아요. 전원을 껐다 켜고 다시 연결해주세요');
      }

      // 완료 알림은 데이터를 보내는 동안에도 올 수 있어 미리 기다리기 시작하고, 끝 알림을 보낸 뒤부터 시간을 잰다
      const done: { completed: boolean; error: Error | null } = { completed: false, error: null };
      const finished = this.waitFor(MXW01_CMD.printComplete, SEND_PHASE_TIMEOUT_MS).then(
        () => {
          done.completed = true;
        },
        (error: Error) => {
          done.error = error;
        },
      );

      for (let i = 0; i < chunks.length; i++) {
        await this.write(this.data, chunks[i].bytes);
        await sleep(MXW01_CHUNK_DELAY_MS);
        if (done.error instanceof PrinterError) throw done.error; // 보내는 중에 연결이 끊겼다
        options.onProgress?.(i + 1, chunks.length);
        if ((i + 1) % LOG_EVERY_CHUNKS === 0 || i + 1 === chunks.length) this.log(`데이터 ${i + 1}/${chunks.length} 조각 보냄`);
      }

      this.log(`명령 ad: ${toHex(flush.bytes)}`);
      await this.write(this.control, flush.bytes);

      const timeoutMs = printCompleteTimeoutMs(print.lineCount);
      if (!done.completed) this.log(`인쇄 완료(aa) 알림 대기 — 최대 ${Math.round(timeoutMs / 1000)}초`);
      this.restartWaiterTimer(MXW01_CMD.printComplete, timeoutMs);
      await finished;
      if (done.error instanceof PrinterError) throw done.error;
      this.log(done.completed ? '인쇄 완료 알림 받음' : '인쇄 완료 알림을 시간 안에 받지 못함 (인쇄는 끝났을 수 있음)');
      return { completed: done.completed };
    } catch (error) {
      this.cancelWaiter(MXW01_CMD.printComplete);
      this.log(`인쇄 중단 — ${describe(error)}`);
      throw error instanceof PrinterError ? error : new PrinterError('인쇄하지 못했어요. 진단 로그를 확인해주세요');
    } finally {
      this.busy = false;
      // 인쇄 중에 끊겼으면 onDisconnected 가 이미 disconnected 로 바꿔 두었다
      if (this.state === 'printing') this.setState('connected');
    }
  }
}
