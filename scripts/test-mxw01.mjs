// MXW01 프린터 프로토콜(src/utils/mxw01-protocol.ts) 자체 테스트: node scripts/test-mxw01.mjs (Node 22.18+ 의 .ts 직접 실행 사용)
// 기대값은 참고한 공개 구현(dave9123/MXW01-catprinter 의 PROTOCOL.md·cmds.py·ble.py, clementvp/mxw01-thermal-printer 의 protocol.ts·테스트)이
// 보내는 바이트를 문서에서 손으로 옮긴 것이다. 구현과 같은 코드로 기대값을 만들지 않는다.
import assert from 'node:assert/strict';
import {
  MXW01_CHUNK_BYTES,
  MXW01_MIN_LINES,
  MXW01_ROW_BYTES,
  MXW01_TEST_PATTERN_HEIGHT,
  MXW01_UUID,
  MXW01_WIDTH,
  buildCommand,
  buildPrintData,
  buildPrintWrites,
  buildTestPatternMono,
  cmdFlush,
  cmdGetStatus,
  cmdPrintRequest,
  cmdSetIntensity,
  crc8,
  grayToMono,
  monoToRgba,
  packRows,
  parseNotification,
  parseStatus,
  printCompleteTimeoutMs,
  rgbaToGray,
  rgbaToMono,
  splitChunks,
  statusErrorMessage,
  toHex,
} from '../src/utils/mxw01-protocol.ts';

let passed = 0;
function test(name, fn) {
  fn();
  passed += 1;
  console.log(`ok - ${name}`);
}
const bytes = (hex) => Uint8Array.from(hex.trim().split(/\s+/).map((h) => parseInt(h, 16)));
const hex = (u8) => toHex(u8);

// ---------- CRC ----------

test('crc8: 참고 구현 테스트의 벡터 [01 02 03] → 0x48', () => {
  assert.equal(crc8(Uint8Array.of(1, 2, 3)), 0x48);
});

test('crc8: 빈 입력 0, CRC-8(poly 0x07) 표준 검사값 "123456789" → 0xF4', () => {
  assert.equal(crc8(new Uint8Array()), 0);
  assert.equal(crc8(new TextEncoder().encode('123456789')), 0xf4);
});

test('crc8: 한 바이트 결과가 참고 구현의 조회표 값과 같다 (표에서 고른 12칸)', () => {
  // 참고 구현 _CRC8_TABLE / CRC8_TABLE 의 [색인] = 값
  const table = { 0x00: 0x00, 0x01: 0x07, 0x02: 0x0e, 0x0f: 0x2d, 0x10: 0x70, 0x30: 0x90, 0x5d: 0x94, 0x5a: 0x81, 0x80: 0x89, 0xaa: 0x5f, 0xf0: 0xde, 0xff: 0xf3 };
  for (const [index, value] of Object.entries(table)) assert.equal(crc8(Uint8Array.of(Number(index))), value, `table[${index}]`);
});

test('crc8: 독립 구현(다항식 나눗셈)과 0~255 전부, 그리고 여러 바이트에서 같다', () => {
  // x^8 + x^2 + x + 1 로 나눈 나머지를 비트열 나눗셈으로 직접 구한다
  const reference = (data) => {
    const bits = [];
    for (const b of data) for (let i = 7; i >= 0; i--) bits.push((b >> i) & 1);
    for (let i = 0; i < 8; i++) bits.push(0);
    const poly = [1, 0, 0, 0, 0, 0, 1, 1, 1];
    for (let i = 0; i + 8 < bits.length; i++) if (bits[i]) for (let j = 0; j < 9; j++) bits[i + j] ^= poly[j];
    return parseInt(bits.slice(-8).join(''), 2);
  };
  for (let b = 0; b < 256; b++) assert.equal(crc8(Uint8Array.of(b)), reference([b]));
  for (const sample of [[0x5a, 0x00, 0x30, 0x00], [0xff, 0xff, 0x30, 0x00], [1, 2, 3, 4, 5, 6, 7, 8, 9]]) assert.equal(crc8(Uint8Array.from(sample)), reference(sample));
});

// ---------- 명령 패킷 ----------

test('명령 틀: 22 21 | id | 00 | 길이 LE | payload | crc | FF', () => {
  assert.equal(hex(buildCommand(0xa9, Uint8Array.of(0x10, 0x20, 0x30, 0x40))).slice(0, 29), '22 21 a9 00 04 00 10 20 30 40');
  const empty = buildCommand(0xa1, new Uint8Array());
  assert.equal(hex(empty), '22 21 a1 00 00 00 00 ff');
  const long = buildCommand(0xa1, new Uint8Array(300));
  assert.deepEqual([long[4], long[5], long.length], [0x2c, 0x01, 308]);
});

test('농도(A2 5D), 상태(A1 00), 끝 알림(AD 00) 패킷', () => {
  assert.equal(hex(cmdSetIntensity(0x5d)), '22 21 a2 00 01 00 5d 94 ff');
  assert.equal(hex(cmdGetStatus()), '22 21 a1 00 01 00 00 00 ff');
  assert.equal(hex(cmdFlush()), '22 21 ad 00 01 00 00 00 ff');
  assert.equal(cmdSetIntensity(999)[6], 0xff, '범위를 넘으면 255 로 자른다');
  assert.equal(cmdSetIntensity(-5)[6], 0x00);
});

test('인쇄 요청(A9): 줄 수 LE, 0x30, 모드 0', () => {
  // crc8([5a 00 30 00]) 를 참고 구현의 조회표로 손으로 따라가면: 0→T[5a]=81→T[81]=8e→T[8e^30=be]=33→T[33]=99
  assert.equal(hex(cmdPrintRequest(90)), '22 21 a9 00 04 00 5a 00 30 00 99 ff');
  const big = cmdPrintRequest(1234); // 0x04d2
  assert.deepEqual(Array.from(big.slice(6, 10)), [0xd2, 0x04, 0x30, 0x00]);
  assert.throws(() => cmdPrintRequest(0));
  assert.throws(() => cmdPrintRequest(70000));
});

// ---------- 알림 ----------

test('알림 풀기: CRC·끝 바이트가 있는 것, payload 까지만 온 것, 형식이 아닌 것', () => {
  const ack = parseNotification(bytes('22 21 a9 00 01 00 00 00 ff'));
  assert.deepEqual([ack.commandId, Array.from(ack.payload), ack.crcOk], [0xa9, [0], true]);
  const short = parseNotification(bytes('22 21 a1 00 02 00 aa bb'));
  assert.deepEqual([short.commandId, Array.from(short.payload), short.crcOk], [0xa1, [0xaa, 0xbb], null]);
  assert.equal(parseNotification(bytes('22 21 aa 00 00 00')).payload.length, 0);
  assert.equal(parseNotification(bytes('22 21 a1 00 01 00 00 77 ff')).crcOk, false);
  assert.equal(parseNotification(bytes('00 21 a1 00 01 00 aa')), null);
  assert.equal(parseNotification(bytes('22 00 a1 00 01 00 aa')), null);
  assert.equal(parseNotification(bytes('22 21 a1 00 05 00 aa')), null, '적힌 길이보다 짧으면 버린다');
  assert.equal(parseNotification(bytes('22 21')), null);
});

test('상태 해석: [12]=0 이면 정상, 아니면 [13] 이 오류 코드', () => {
  const ok = parseStatus(bytes('00 00 00 00 00 00 00 00 00 5f 1c 00 00'));
  assert.deepEqual(ok, { ok: true, errorCode: null, state: 0, battery: 0x5f, temperature: 0x1c });
  const noPaper = parseStatus(bytes('00 00 00 00 00 00 00 00 00 5f 1c 00 01 09'));
  assert.deepEqual([noPaper.ok, noPaper.errorCode], [false, 9]);
  assert.equal(parseStatus(bytes('00 00 00')).ok, null, '짧은 응답은 판단하지 않는다');
  assert.match(statusErrorMessage(1), /용지/);
  assert.match(statusErrorMessage(9), /용지/);
  assert.match(statusErrorMessage(4), /뜨거워/);
  assert.match(statusErrorMessage(8), /배터리/);
  assert.match(statusErrorMessage(77), /코드 77/);
});

test('완료 대기 시간: 15초 + 줄 수/15초', () => {
  assert.equal(printCompleteTimeoutMs(90), 21000);
  assert.equal(printCompleteTimeoutMs(1500), 115000);
});

// ---------- 이미지 ----------

test('줄 묶기: 한 줄 48바이트, bit 0 이 가장 왼쪽 점', () => {
  const mono = new Uint8Array(MXW01_WIDTH * 2);
  mono[0] = 1; // 첫 줄 x=0 → 바이트 0 의 bit 0
  mono[7] = 1; // x=7 → 바이트 0 의 bit 7
  mono[9] = 1; // x=9 → 바이트 1 의 bit 1
  mono[383] = 1; // x=383 → 바이트 47 의 bit 7
  mono[MXW01_WIDTH + 8] = 1; // 둘째 줄 x=8 → 바이트 48+1 의 bit 0
  const data = packRows(mono, 2);
  assert.equal(data.length, 96);
  assert.deepEqual([data[0], data[1], data[47], data[48], data[49]], [0x81, 0x02, 0x80, 0x00, 0x01]);
  assert.equal(data.reduce((sum, b) => sum + b, 0), 0x81 + 0x02 + 0x80 + 0x01);
  assert.throws(() => packRows(new Uint8Array(100), 1), /384/);
});

test('밝기 변환: 검정·흰색·투명(흰 종이)', () => {
  const gray = rgbaToGray(Uint8Array.of(0, 0, 0, 255, 255, 255, 255, 255, 0, 0, 0, 0, 255, 0, 0, 255), 4, 1);
  assert.deepEqual(Array.from(gray, Math.round), [0, 255, 255, 76]);
  assert.throws(() => rgbaToGray(new Uint8Array(3), 1, 1));
});

test('threshold: 128 미만만 검정, 디더링 없음', () => {
  const mono = grayToMono(Float32Array.of(0, 127, 128, 255), 4, 1, { dither: 'threshold' });
  assert.deepEqual(Array.from(mono), [1, 1, 0, 0]);
});

test('Floyd–Steinberg: 순수 검정·흰색은 그대로, 회색은 밝기에 비례한 점 비율', () => {
  const w = 64;
  const h = 64;
  const ratio = (value) => grayToMono(new Float32Array(w * h).fill(value), w, h).reduce((s, v) => s + v, 0) / (w * h);
  assert.equal(ratio(0), 1);
  assert.equal(ratio(255), 0);
  assert.ok(Math.abs(ratio(127.5) - 0.5) < 0.02, `50% 회색 → ${ratio(127.5)}`);
  assert.ok(Math.abs(ratio(191.25) - 0.25) < 0.02, `75% 밝기 → ${ratio(191.25)}`);
  // 손으로 계산한 2×2: 100 → 검정(오차 +100: 오른쪽 +43.75, 아래 +31.25, 오른쪽 아래 +6.25) → 143.75 → 흰색(오차 −111.25: 왼쪽 아래 −20.86, 아래 −34.77) → 110.39 → 검정(오른쪽 +48.3) → 119.78 → 검정
  assert.deepEqual(Array.from(grayToMono(Float32Array.of(100, 100, 100, 100), 2, 2)), [1, 0, 1, 1]);
});

test('ditherRows: 범위 밖은 threshold, 오차가 범위 밖으로 넘어가지 않는다', () => {
  const w = 16;
  const gray = new Float32Array(w * 6).fill(120); // 전부 threshold 로는 검정
  const mono = grayToMono(gray, w, 6, { ditherRows: { from: 2, to: 4 } });
  const rowSum = (y) => mono.slice(y * w, (y + 1) * w).reduce((s, v) => s + v, 0);
  assert.deepEqual([rowSum(0), rowSum(1), rowSum(4), rowSum(5)], [w, w, w, w]);
  assert.ok(rowSum(2) < w && rowSum(3) < w, '범위 안은 디더링되어 흰 점이 섞인다');
});

test('미리보기 RGBA: 검정 점 0, 흰 점 255, 불투명 — 다시 점으로 바꾸면 같다', () => {
  const mono = Uint8Array.of(1, 0, 0, 1);
  const rgba = monoToRgba(mono);
  assert.deepEqual(Array.from(rgba), [0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 0, 0, 255]);
  assert.deepEqual(Array.from(rgbaToMono(rgba, 4, 1, { dither: 'threshold' })), Array.from(mono));
});

test('인쇄 데이터: 90줄 미만은 흰 줄로 채우고 줄 수도 90', () => {
  const tiny = buildPrintData(new Uint8Array(MXW01_WIDTH * 2).fill(1), 2);
  assert.equal(tiny.lineCount, MXW01_MIN_LINES);
  assert.equal(tiny.data.length, 4320);
  assert.ok(tiny.data.slice(0, 96).every((b) => b === 0xff) && tiny.data.slice(96).every((b) => b === 0));
  const tall = buildPrintData(new Uint8Array(MXW01_WIDTH * 200), 200);
  assert.deepEqual([tall.lineCount, tall.data.length], [200, 9600]);
});

test('조각 나누기: 48바이트씩, 마지막 조각은 남은 만큼', () => {
  const chunks = splitChunks(Uint8Array.from({ length: 100 }, (_, i) => i));
  assert.deepEqual(chunks.map((c) => c.length), [48, 48, 4]);
  assert.deepEqual([chunks[1][0], chunks[2][3]], [48, 99]);
  assert.equal(splitChunks(new Uint8Array()).length, 0);
  assert.equal(MXW01_CHUNK_BYTES, MXW01_ROW_BYTES);
});

test('전체 쓰기 순서(2줄짜리 이미지): 참고 구현 run_ble / ThermalPrinterClient.print 가 보내는 순서와 바이트', () => {
  const mono = new Uint8Array(MXW01_WIDTH * 2);
  mono[0] = 1;
  mono[MXW01_WIDTH + 383] = 1;
  const writes = buildPrintWrites(buildPrintData(mono, 2), 0x5d);
  // ble.py: 농도(A2) → 상태(A1) → 인쇄 요청(A9, 채운 뒤 90줄) → AE03 에 48바이트씩 90번 → 끝 알림(AD)
  assert.equal(writes.length, 3 + 90 + 1);
  assert.deepEqual(writes.map((w) => w.target).join(',').replace(/(data,)+/, 'data×N,'), 'control,control,control,data×N,control');
  assert.equal(hex(writes[0].bytes), '22 21 a2 00 01 00 5d 94 ff');
  assert.equal(hex(writes[1].bytes), '22 21 a1 00 01 00 00 00 ff');
  assert.equal(hex(writes[2].bytes), '22 21 a9 00 04 00 5a 00 30 00 99 ff');
  assert.equal(hex(writes[3].bytes), ['01', ...Array(47).fill('00')].join(' '));
  assert.equal(hex(writes[4].bytes), [...Array(47).fill('00'), '80'].join(' '));
  for (let i = 5; i < 93; i++) assert.ok(writes[i].bytes.length === 48 && writes[i].bytes.every((b) => b === 0), `채운 줄 ${i}`);
  assert.equal(hex(writes[93].bytes), '22 21 ad 00 01 00 00 00 ff');
});

test('테스트 무늬: 384×240, 언제나 같은 결과, 줄별 모양', () => {
  const mono = buildTestPatternMono();
  assert.equal(mono.length, MXW01_WIDTH * MXW01_TEST_PATTERN_HEIGHT);
  assert.deepEqual(Array.from(mono), Array.from(buildTestPatternMono()));
  const row = (y) => mono.slice(y * MXW01_WIDTH, (y + 1) * MXW01_WIDTH);
  const count = (y) => row(y).reduce((s, v) => s + v, 0);
  assert.equal(count(0), 384, '맨 위 가로줄은 양 끝까지 검정');
  assert.equal(count(6), 0);
  assert.deepEqual([count(12), count(59)], [255, 20], '삼각형: 위가 넓고 아래가 좁다');
  assert.ok(row(90).slice(0, 96).reduce((s, v) => s + v, 0) > row(90).slice(288).reduce((s, v) => s + v, 0) * 3, '밝기 띠: 왼쪽이 훨씬 어둡다');
  assert.deepEqual([row(124)[0], row(124)[16], row(140)[0], row(140)[16]], [1, 0, 0, 1], '체크무늬');
  assert.equal(count(200), 0, '아래는 흰 여백');
  const print = buildPrintData(mono, MXW01_TEST_PATTERN_HEIGHT);
  assert.deepEqual([print.lineCount, print.data.length], [240, 11520]);
});

test('UUID', () => {
  assert.equal(MXW01_UUID.service, '0000ae30-0000-1000-8000-00805f9b34fb');
  assert.equal(MXW01_UUID.serviceAlt, '0000af30-0000-1000-8000-00805f9b34fb');
  assert.deepEqual([MXW01_UUID.control.slice(4, 8), MXW01_UUID.notify.slice(4, 8), MXW01_UUID.data.slice(4, 8)], ['ae01', 'ae02', 'ae03']);
});

console.log(`${passed}/${passed} passed`);
