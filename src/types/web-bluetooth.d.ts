// Web Bluetooth API 중 이 프로젝트(src/utils/mxw01-printer.ts)가 쓰는 부분만 손으로 적은 타입.
// TypeScript 의 DOM 타입에 Web Bluetooth 가 없고, 라이브러리(@types/web-bluetooth)를 추가하지 않기 위해 둔다.
// 명세: https://webbluetoothcg.github.io/web-bluetooth/

interface BluetoothLEScanFilter {
  services?: string[];
  name?: string;
  namePrefix?: string;
}

type RequestDeviceOptions = { filters: BluetoothLEScanFilter[]; optionalServices?: string[] } | { acceptAllDevices: true; optionalServices?: string[] };

interface BluetoothCharacteristicProperties {
  readonly notify: boolean;
  readonly write: boolean;
  readonly writeWithoutResponse: boolean;
}

interface BluetoothRemoteGATTCharacteristic extends EventTarget {
  readonly uuid: string;
  readonly properties: BluetoothCharacteristicProperties;
  /** 알림(characteristicvaluechanged)이 오면 여기에 받은 값이 들어 있다 */
  readonly value: DataView | null;
  startNotifications(): Promise<BluetoothRemoteGATTCharacteristic>;
  stopNotifications(): Promise<BluetoothRemoteGATTCharacteristic>;
  writeValueWithResponse(value: BufferSource): Promise<void>;
  writeValueWithoutResponse(value: BufferSource): Promise<void>;
}

interface BluetoothRemoteGATTService {
  readonly uuid: string;
  getCharacteristic(characteristic: string): Promise<BluetoothRemoteGATTCharacteristic>;
}

interface BluetoothRemoteGATTServer {
  readonly connected: boolean;
  connect(): Promise<BluetoothRemoteGATTServer>;
  disconnect(): void;
  getPrimaryService(service: string): Promise<BluetoothRemoteGATTService>;
}

/** 이벤트: gattserverdisconnected */
interface BluetoothDevice extends EventTarget {
  readonly id: string;
  readonly name?: string;
  readonly gatt?: BluetoothRemoteGATTServer;
}

interface Bluetooth {
  getAvailability(): Promise<boolean>;
  requestDevice(options: RequestDeviceOptions): Promise<BluetoothDevice>;
}

interface Navigator {
  /** Chrome·Edge 에만 있다 (Safari·Firefox 에는 없다) */
  readonly bluetooth?: Bluetooth;
}
