// MXW01 미니 감열 프린터(BLE "cat printer")의 프로토콜. 순수 함수만 둔다 (DOM·Bluetooth 에 의존하지 않아 node 로 테스트한다: scripts/test-mxw01.mjs).
// 전송(Web Bluetooth)은 mxw01-printer.ts 가 맡는다.
//
// 출처: 아래 공개 저장소의 문서와 동작을 참고해 이 프로젝트에 맞게 직접 다시 작성했다 (코드를 옮겨 붙이지 않았다).
//   - dave9123/MXW01-catprinter, jeremy46231/MXW01-catprinter : PROTOCOL.md, catprinter/cmds.py · ble.py (MIT, Copyright (c) 2021 rbaron)
//   - clementvp/mxw01-thermal-printer : src/services/protocol.ts · printer.ts, src/core/ThermalPrinterClient.ts (MIT, package.json 표기)
// 출처끼리 다르거나 불확실한 부분은 "주의" 주석으로 남겼다. 실제 기기에서 처음 시험할 때 확인할 곳이다.

/** GATT 서비스·특성 UUID. macOS 에서는 서비스가 af30 으로 보일 수 있다는 보고가 있어 둘 다 찾는다 */
export const MXW01_UUID = {
  service: '0000ae30-0000-1000-8000-00805f9b34fb',
  serviceAlt: '0000af30-0000-1000-8000-00805f9b34fb',
  control: '0000ae01-0000-1000-8000-00805f9b34fb', // 명령 쓰기 (write without response)
  notify: '0000ae02-0000-1000-8000-00805f9b34fb', // 프린터 → 응답·상태 알림
  data: '0000ae03-0000-1000-8000-00805f9b34fb', // 이미지 데이터 쓰기 (write without response)
} as const;

/** 한 줄의 점 수(가로 해상도)와 그 바이트 수 */
export const MXW01_WIDTH = 384;
export const MXW01_ROW_BYTES = MXW01_WIDTH / 8; // 48

/** 이보다 짧은 이미지는 흰 줄로 채워 보낸다 (두 출처 모두 4320바이트 = 90줄 미만이면 0 으로 채운다. "꼭 필요한지는 확실하지 않다"고 적혀 있다) */
export const MXW01_MIN_LINES = 90;

/** 데이터 한 번에 보내는 크기(= 한 줄)와 그 사이 쉬는 시간. 두 출처가 같은 값을 쓴다 */
export const MXW01_CHUNK_BYTES = MXW01_ROW_BYTES;
export const MXW01_CHUNK_DELAY_MS = 15;

/** 인쇄 농도 기본값 (0x00~0xFF, 클수록 진하다. 두 출처 모두 0x5D 를 기본으로 쓴다) */
export const MXW01_DEFAULT_INTENSITY = 0x5d;

export const MXW01_CMD = {
  getStatus: 0xa1,
  setIntensity: 0xa2,
  printRequest: 0xa9,
  printComplete: 0xaa, // 알림 전용: 실제 인쇄가 끝났다
  flush: 0xad,
} as const;

const PREAMBLE_1 = 0x22;
const PREAMBLE_2 = 0x21;
const FOOTER = 0xff;

/**
 * CRC-8 (다항식 0x07, 초기값 0x00, 비트 반전 없음, 최종 XOR 없음). payload 에만 계산한다.
 * 주의: PROTOCOL.md 는 이름을 "DALLAS-MAXIM" 이라 적었지만 적힌 매개변수와 두 출처의 표는 표준 CRC-8(SMBus)이다. 표를 따른다.
 */
export function crc8(data: Uint8Array): number {
  let crc = 0;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) {
      crc = crc & 0x80 ? ((crc << 1) ^ 0x07) & 0xff : (crc << 1) & 0xff;
    }
  }
  return crc;
}

/** 명령 패킷: 22 21 | 명령 | 00 | 길이(LE 2바이트) | payload | CRC8(payload) | FF */
export function buildCommand(commandId: number, payload: Uint8Array): Uint8Array {
  if (payload.length > 0xffff) throw new Error('명령 payload 가 너무 깁니다');
  const packet = new Uint8Array(payload.length + 8);
  packet[0] = PREAMBLE_1;
  packet[1] = PREAMBLE_2;
  packet[2] = commandId & 0xff;
  packet[3] = 0x00;
  packet[4] = payload.length & 0xff;
  packet[5] = (payload.length >> 8) & 0xff;
  packet.set(payload, 6);
  packet[6 + payload.length] = crc8(payload);
  packet[7 + payload.length] = FOOTER;
  return packet;
}

export function cmdGetStatus(): Uint8Array {
  return buildCommand(MXW01_CMD.getStatus, Uint8Array.of(0x00));
}

export function cmdSetIntensity(intensity: number): Uint8Array {
  const value = Math.max(0, Math.min(255, Math.round(intensity)));
  return buildCommand(MXW01_CMD.setIntensity, Uint8Array.of(value));
}

/**
 * 인쇄 요청: 줄 수(LE 2바이트), 0x30, 모드.
 * 주의: 모드는 두 출처의 코드가 모두 0x00(1bpp 흑백)을 보낸다. PROTOCOL.md 의 표에는 0x01 로 적힌 곳이 있지만(같은 문서의 각주·예시는 0), 코드를 따른다.
 */
export function cmdPrintRequest(lineCount: number): Uint8Array {
  if (!Number.isInteger(lineCount) || lineCount < 1 || lineCount > 0xffff) throw new Error('인쇄 줄 수가 올바르지 않습니다');
  return buildCommand(MXW01_CMD.printRequest, Uint8Array.of(lineCount & 0xff, (lineCount >> 8) & 0xff, 0x30, 0x00));
}

export function cmdFlush(): Uint8Array {
  return buildCommand(MXW01_CMD.flush, Uint8Array.of(0x00));
}

export interface Mxw01Notification {
  commandId: number;
  payload: Uint8Array;
  /** CRC 와 끝 바이트(FF)까지 온 경우의 CRC 일치 여부. 알림이 payload 까지만 오면 null (출처에 따르면 알림에는 CRC 가 없을 수 있다) */
  crcOk: boolean | null;
}

/** 프린터가 보낸 알림을 푼다. 형식이 아니면 null */
export function parseNotification(bytes: Uint8Array): Mxw01Notification | null {
  if (bytes.length < 6 || bytes[0] !== PREAMBLE_1 || bytes[1] !== PREAMBLE_2) return null;
  const length = bytes[4] | (bytes[5] << 8);
  if (bytes.length < 6 + length) return null;
  const payload = bytes.slice(6, 6 + length);
  const crcOk = bytes.length >= 8 + length ? bytes[6 + length] === crc8(payload) : null;
  return { commandId: bytes[2], payload, crcOk };
}

export interface Mxw01Status {
  /** true = 인쇄 가능, false = 오류, null = 응답이 짧아 알 수 없음 */
  ok: boolean | null;
  errorCode: number | null;
  /** 0 = 대기, 1 = 인쇄 중 … (ok 일 때만 의미가 있다) */
  state: number | null;
  /** 배터리 (대략, %) */
  battery: number | null;
  temperature: number | null;
}

/**
 * 상태 응답(A1) payload 해석. PROTOCOL.md 기준: [6]=상태, [9]=배터리, [10]=온도, [12]=오류 플래그(0=정상), [13]=오류 코드.
 * 주의: clementvp 구현에는 payload[6] 을 비트 필드(용지 없음 0x04 등)로 읽는 코드도 있어 서로 다르다.
 *       인쇄를 막는 판단은 두 출처가 함께 쓰는 [12]/[13] 만 따른다. 원본 바이트는 진단 로그에 그대로 남긴다.
 */
export function parseStatus(payload: Uint8Array): Mxw01Status {
  if (payload.length < 13) return { ok: null, errorCode: null, state: payload.length > 6 ? payload[6] : null, battery: null, temperature: null };
  const ok = payload[12] === 0;
  return {
    ok,
    errorCode: ok ? null : payload.length > 13 ? payload[13] : 0,
    state: payload[6],
    battery: payload[9],
    temperature: payload[10],
  };
}

/** 오류 코드 → 사용자에게 보여줄 문구 (PROTOCOL.md: 1/9 = 용지 없음, 4 = 과열, 8 = 배터리 부족) */
export function statusErrorMessage(errorCode: number | null): string {
  switch (errorCode) {
    case 1:
    case 9:
      return '용지가 없어요. 용지를 넣고 덮개를 닫은 뒤 다시 시도해주세요';
    case 4:
      return '프린터가 뜨거워요. 잠시 식힌 뒤 다시 시도해주세요';
    case 8:
      return '프린터 배터리가 부족해요. 충전한 뒤 다시 시도해주세요';
    default:
      return `프린터가 오류를 알렸어요 (코드 ${errorCode ?? '알 수 없음'}). 용지와 덮개를 확인해주세요`;
  }
}

/** 인쇄 완료(AA) 알림을 기다릴 시간. 출처(ble.py): 15초 + 줄 수 / 초당 15줄 */
export function printCompleteTimeoutMs(lineCount: number): number {
  return Math.round(15000 + (lineCount / 15) * 1000);
}

// ---------- 이미지 → 1비트 ----------

export type DitherMethod = 'floyd-steinberg' | 'threshold';

export interface MonoOptions {
  /** 사진에는 floyd-steinberg, 글자·선에는 threshold 가 맞다. 기본 floyd-steinberg */
  dither?: DitherMethod;
  /** dither 를 이 줄 범위(from 이상 to 미만)에만 적용하고 나머지는 threshold 로 자른다 (사진 영역만 디더링해 글자를 또렷하게 둔다) */
  ditherRows?: { from: number; to: number };
  /** 이 값보다 어두우면 검정 (0~255). 기본 128 */
  threshold?: number;
}

/** RGBA(캔버스 ImageData.data) → 밝기 0~255. 투명한 곳은 흰 종이로 본다 */
export function rgbaToGray(rgba: Uint8Array | Uint8ClampedArray, width: number, height: number): Float32Array {
  if (rgba.length !== width * height * 4) throw new Error('이미지 크기와 데이터 길이가 맞지 않습니다');
  const gray = new Float32Array(width * height);
  for (let i = 0; i < gray.length; i++) {
    const alpha = rgba[i * 4 + 3] / 255;
    const luma = 0.299 * rgba[i * 4] + 0.587 * rgba[i * 4 + 1] + 0.114 * rgba[i * 4 + 2];
    gray[i] = luma * alpha + 255 * (1 - alpha);
  }
  return gray;
}

/** 밝기 → 점(1 = 검정, 0 = 흰색). 픽셀마다 1바이트 */
export function grayToMono(gray: Float32Array, width: number, height: number, options: MonoOptions = {}): Uint8Array {
  if (gray.length !== width * height) throw new Error('이미지 크기와 데이터 길이가 맞지 않습니다');
  const threshold = options.threshold ?? 128;
  const method = options.dither ?? 'floyd-steinberg';
  const from = method === 'threshold' ? 0 : Math.max(0, options.ditherRows?.from ?? 0);
  const to = method === 'threshold' ? 0 : Math.min(height, options.ditherRows?.to ?? height);
  const work = Float32Array.from(gray);
  const mono = new Uint8Array(width * height);

  for (let y = 0; y < height; y++) {
    const dithered = y >= from && y < to;
    for (let x = 0; x < width; x++) {
      const i = y * width + x;
      const black = work[i] < threshold;
      mono[i] = black ? 1 : 0;
      if (!dithered) continue;
      // Floyd–Steinberg: 버린 밝기 차이를 오른쪽 7/16, 왼쪽 아래 3/16, 아래 5/16, 오른쪽 아래 1/16 로 넘긴다 (디더링 범위 안에서만)
      const error = work[i] - (black ? 0 : 255);
      if (x + 1 < width) work[i + 1] += (error * 7) / 16;
      if (y + 1 < to) {
        if (x > 0) work[i + width - 1] += (error * 3) / 16;
        work[i + width] += (error * 5) / 16;
        if (x + 1 < width) work[i + width + 1] += error / 16;
      }
    }
  }
  return mono;
}

export function rgbaToMono(rgba: Uint8Array | Uint8ClampedArray, width: number, height: number, options: MonoOptions = {}): Uint8Array {
  return grayToMono(rgbaToGray(rgba, width, height), width, height, options);
}

/** 점 → 화면 미리보기용 RGBA (검정/흰색). 인쇄될 모습 그대로를 보여줄 때 쓴다 */
export function monoToRgba(mono: Uint8Array): Uint8ClampedArray {
  const rgba = new Uint8ClampedArray(mono.length * 4);
  for (let i = 0; i < mono.length; i++) {
    const value = mono[i] ? 0 : 255;
    rgba[i * 4] = value;
    rgba[i * 4 + 1] = value;
    rgba[i * 4 + 2] = value;
    rgba[i * 4 + 3] = 255;
  }
  return rgba;
}

/**
 * 점(가로 384)을 프린터 데이터로 묶는다: 한 줄 48바이트, 위에서 아래로, 왼쪽에서 오른쪽으로.
 * 바이트 안에서는 가장 낮은 비트(bit 0)가 가장 왼쪽 점이다 (두 출처가 같다). 1 = 검정.
 */
export function packRows(mono: Uint8Array, height: number): Uint8Array {
  if (mono.length !== MXW01_WIDTH * height) throw new Error(`이미지 가로는 ${MXW01_WIDTH}점이어야 합니다`);
  const data = new Uint8Array(MXW01_ROW_BYTES * height);
  for (let i = 0; i < mono.length; i++) {
    if (mono[i]) data[i >> 3] |= 1 << (i & 7);
  }
  return data;
}

export interface Mxw01PrintData {
  /** 프린터에 보낼 바이트 (최소 줄 수까지 흰 줄로 채운 것) */
  data: Uint8Array;
  /** 인쇄 요청에 넣을 줄 수 (= data.length / 48) */
  lineCount: number;
}

/**
 * 점 → 인쇄 데이터. 90줄보다 짧으면 흰 줄을 붙인다.
 * 주의: 줄 수는 채운 뒤의 줄 수를 보낸다(ble.py 방식). clementvp 구현은 채우기 전 줄 수를 보내 서로 다르다. 90줄 이상인 이미지에서는 차이가 없다.
 */
export function buildPrintData(mono: Uint8Array, height: number): Mxw01PrintData {
  const rows = packRows(mono, height);
  const lineCount = Math.max(height, MXW01_MIN_LINES);
  if (lineCount > 0xffff) throw new Error('이미지가 너무 깁니다');
  const data = new Uint8Array(lineCount * MXW01_ROW_BYTES);
  data.set(rows);
  return { data, lineCount };
}

export function splitChunks(data: Uint8Array, size: number = MXW01_CHUNK_BYTES): Uint8Array[] {
  if (size < 1) throw new Error('조각 크기가 올바르지 않습니다');
  const chunks: Uint8Array[] = [];
  for (let offset = 0; offset < data.length; offset += size) chunks.push(data.slice(offset, offset + size));
  return chunks;
}

export interface Mxw01Write {
  /** control = AE01(명령), data = AE03(이미지 데이터) */
  target: 'control' | 'data';
  bytes: Uint8Array;
}

/**
 * 인쇄 한 번에 프린터로 보내는 쓰기의 전체 순서 (응답 대기는 mxw01-printer.ts 가 한다):
 *   농도(A2) → 상태 요청(A1, A1 알림 대기) → 인쇄 요청(A9, A9 알림 대기) → 데이터 48바이트씩 → 끝 알림(AD) → AA 알림 대기
 */
export function buildPrintWrites(print: Mxw01PrintData, intensity: number = MXW01_DEFAULT_INTENSITY): Mxw01Write[] {
  return [
    { target: 'control', bytes: cmdSetIntensity(intensity) },
    { target: 'control', bytes: cmdGetStatus() },
    { target: 'control', bytes: cmdPrintRequest(print.lineCount) },
    ...splitChunks(print.data).map((bytes): Mxw01Write => ({ target: 'data', bytes })),
    { target: 'control', bytes: cmdFlush() },
  ];
}

// ---------- 테스트 인쇄 무늬 ----------

/** 테스트 무늬의 줄 수 (아래쪽 흰 여백 포함) */
export const MXW01_TEST_PATTERN_HEIGHT = 240;

/**
 * 글꼴 없이 만드는 테스트 무늬 (언제나 같은 결과). 위에서부터:
 *   굵은 가로줄(양 끝까지 찍히는지) → 왼쪽 위가 직각인 삼각형(빗변이 매끈해야 한다. 톱니 모양이면 비트 순서가 반대다)
 *   → 왼쪽이 검고 오른쪽으로 밝아지는 띠(농도 확인) → 16점 체크무늬 → 가로줄 → 흰 여백(뜯는 곳까지 밀어내기)
 */
export function buildTestPatternMono(): Uint8Array {
  const width = MXW01_WIDTH;
  const height = MXW01_TEST_PATTERN_HEIGHT;
  const gray = new Float32Array(width * height).fill(255);
  const fill = (y0: number, y1: number, value: (x: number, y: number) => number): void => {
    for (let y = y0; y < y1; y++) for (let x = 0; x < width; x++) gray[y * width + x] = value(x, y - y0);
  };
  fill(0, 4, () => 0);
  // 빗변이 바이트 경계(8점)와 어긋나게 줄마다 5점씩 줄인다 → 비트 순서가 반대면 빗변에 8점 단위 틈이 생긴다
  fill(12, 60, (x, y) => (x < 20 + (47 - y) * 5 ? 0 : 255));
  fill(68, 116, (x) => (x / (width - 1)) * 255);
  fill(124, 156, (x, y) => (((x >> 4) + (y >> 4)) % 2 === 0 ? 0 : 255));
  fill(164, 168, () => 0);
  return grayToMono(gray, width, height, { dither: 'floyd-steinberg', ditherRows: { from: 68, to: 116 } });
}

/** 진단 로그용 16진수 표기 */
export function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join(' ');
}
