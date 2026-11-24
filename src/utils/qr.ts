// QR 코드 만들기 (라이브러리를 추가하지 않기 위해 직접 구현). 바이트 모드, 오류 정정 수준 M, 버전 1~8(최대 152바이트)만 지원한다.
// 주소 한 줄을 화면에 QR 로 띄우는 용도다. 만든 QR 은 독립 판독기(OpenCV QRCodeDetector)로 읽어 확인했고, 그 결과를 scripts/test-qr.mjs 가 고정값으로 지킨다.

/** 버전별(1~8) 오류 정정 M 구성: 블록마다 붙는 오류 정정 코드워드 수, [블록 수, 블록의 데이터 코드워드 수] 묶음 */
const VERSIONS: { ec: number; groups: [number, number][]; align: number[] }[] = [
  { ec: 10, groups: [[1, 16]], align: [] },
  { ec: 16, groups: [[1, 28]], align: [6, 18] },
  { ec: 26, groups: [[1, 44]], align: [6, 22] },
  { ec: 18, groups: [[2, 32]], align: [6, 26] },
  { ec: 24, groups: [[2, 43]], align: [6, 30] },
  { ec: 16, groups: [[4, 27]], align: [6, 34] },
  { ec: 18, groups: [[4, 31]], align: [6, 22, 38] },
  { ec: 22, groups: [[2, 38], [2, 39]], align: [6, 24, 42] },
];

// GF(256) 지수·로그 표 (원시 다항식 0x11d)
const EXP = new Uint8Array(512);
const LOG = new Uint8Array(256);
for (let i = 0, x = 1; i < 255; i++) {
  EXP[i] = x;
  LOG[x] = i;
  x <<= 1;
  if (x & 0x100) x ^= 0x11d;
}
for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255];

const multiply = (a: number, b: number): number => (a === 0 || b === 0 ? 0 : EXP[LOG[a] + LOG[b]]);

/** 리드-솔로몬 오류 정정 코드워드 */
function reedSolomon(data: number[], ecCount: number): number[] {
  let generator = [1];
  for (let i = 0; i < ecCount; i++) {
    const next = new Array<number>(generator.length + 1).fill(0);
    for (let j = 0; j < generator.length; j++) {
      next[j] ^= generator[j];
      next[j + 1] ^= multiply(generator[j], EXP[i]);
    }
    generator = next;
  }
  const remainder = new Array<number>(ecCount).fill(0);
  for (const byte of data) {
    const factor = byte ^ remainder[0];
    remainder.shift();
    remainder.push(0);
    for (let i = 0; i < ecCount; i++) remainder[i] ^= multiply(generator[i + 1], factor);
  }
  return remainder;
}

const MASKS: ((row: number, col: number) => boolean)[] = [
  (r, c) => (r + c) % 2 === 0,
  (r) => r % 2 === 0,
  (_r, c) => c % 3 === 0,
  (r, c) => (r + c) % 3 === 0,
  (r, c) => (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0,
  (r, c) => ((r * c) % 2) + ((r * c) % 3) === 0,
  (r, c) => (((r * c) % 2) + ((r * c) % 3)) % 2 === 0,
  (r, c) => (((r + c) % 2) + ((r * c) % 3)) % 2 === 0,
];

/** BCH 나머지를 붙인 값 (형식 정보 15비트, 버전 정보 18비트에 쓴다) */
function bch(value: number, bits: number, generator: number, generatorBits: number): number {
  let remainder = value << (generatorBits - 1);
  for (let i = bits + generatorBits - 2; i >= generatorBits - 1; i--) {
    if (remainder & (1 << i)) remainder ^= generator << (i - generatorBits + 1);
  }
  return (value << (generatorBits - 1)) | remainder;
}

/** 마스크 벌점 (규격의 네 가지 규칙). 가장 낮은 마스크를 고른다 */
function penalty(m: boolean[][]): number {
  const size = m.length;
  let score = 0;
  // 1) 같은 색이 5칸 이상 이어짐 (가로·세로)
  for (let pass = 0; pass < 2; pass++) {
    for (let i = 0; i < size; i++) {
      let run = 1;
      for (let j = 1; j <= size; j++) {
        const same = j < size && (pass === 0 ? m[i][j] === m[i][j - 1] : m[j][i] === m[j - 1][i]);
        if (same) run += 1;
        else {
          if (run >= 5) score += run - 2;
          run = 1;
        }
      }
    }
  }
  // 2) 같은 색 2×2 덩어리
  for (let r = 0; r < size - 1; r++) for (let c = 0; c < size - 1; c++) if (m[r][c] === m[r][c + 1] && m[r][c] === m[r + 1][c] && m[r][c] === m[r + 1][c + 1]) score += 3;
  // 3) 위치 찾기 무늬와 닮은 1:1:3:1:1 (앞뒤로 흰 4칸)
  const patterns = [
    [true, false, true, true, true, false, true, false, false, false, false],
    [false, false, false, false, true, false, true, true, true, false, true],
  ];
  for (let i = 0; i < size; i++) {
    for (let j = 0; j <= size - 11; j++) {
      for (const pattern of patterns) {
        if (pattern.every((dark, k) => m[i][j + k] === dark)) score += 40;
        if (pattern.every((dark, k) => m[j + k][i] === dark)) score += 40;
      }
    }
  }
  // 4) 검은 칸 비율이 50% 에서 벗어난 정도
  let dark = 0;
  for (const row of m) for (const cell of row) if (cell) dark += 1;
  score += Math.floor(Math.abs((dark * 100) / (size * size) - 50) / 5) * 10;
  return score;
}

/**
 * 글자를 QR 코드 칸으로 바꾼다. true = 검은 칸. 테두리 여백(조용한 영역)은 포함하지 않는다.
 * forcedMask 는 검증용이다 (보통은 벌점이 가장 낮은 마스크를 고른다).
 */
export function createQrMatrix(text: string, forcedMask?: number): boolean[][] {
  const bytes = Array.from(new TextEncoder().encode(text));
  const versionIndex = VERSIONS.findIndex((v) => bytes.length + 2 <= v.groups.reduce((sum, [count, size]) => sum + count * size, 0));
  if (versionIndex < 0) throw new Error('QR 코드에 넣기에는 글자가 너무 길어요');
  const spec = VERSIONS[versionIndex];
  const version = versionIndex + 1;
  const size = 17 + version * 4;
  const dataCount = spec.groups.reduce((sum, [count, blockSize]) => sum + count * blockSize, 0);

  // 데이터 비트: 모드(0100) + 글자 수(8비트) + 바이트들 + 끝 표시 + 채움
  const bits: number[] = [];
  const push = (value: number, length: number): void => {
    for (let i = length - 1; i >= 0; i--) bits.push((value >> i) & 1);
  };
  push(0b0100, 4);
  push(bytes.length, 8);
  for (const byte of bytes) push(byte, 8);
  push(0, Math.min(4, dataCount * 8 - bits.length));
  while (bits.length % 8 !== 0) bits.push(0);
  const data: number[] = [];
  for (let i = 0; i < bits.length; i += 8) data.push(bits.slice(i, i + 8).reduce((value, bit) => (value << 1) | bit, 0));
  for (let pad = 0xec; data.length < dataCount; pad ^= 0xec ^ 0x11) data.push(pad);

  // 블록으로 나누고 오류 정정을 붙인 뒤 번갈아 섞는다
  const blocks: { data: number[]; ec: number[] }[] = [];
  let offset = 0;
  for (const [count, blockSize] of spec.groups) {
    for (let i = 0; i < count; i++) {
      const block = data.slice(offset, offset + blockSize);
      blocks.push({ data: block, ec: reedSolomon(block, spec.ec) });
      offset += blockSize;
    }
  }
  const codewords: number[] = [];
  const longest = Math.max(...blocks.map((block) => block.data.length));
  for (let i = 0; i < longest; i++) for (const block of blocks) if (i < block.data.length) codewords.push(block.data[i]);
  for (let i = 0; i < spec.ec; i++) for (const block of blocks) codewords.push(block.ec[i]);

  // 고정 무늬
  const matrix = Array.from({ length: size }, () => new Array<boolean>(size).fill(false));
  const reserved = Array.from({ length: size }, () => new Array<boolean>(size).fill(false));
  const set = (row: number, col: number, dark: boolean): void => {
    matrix[row][col] = dark;
    reserved[row][col] = true;
  };
  const finder = (row: number, col: number): void => {
    for (let r = -1; r <= 7; r++) {
      for (let c = -1; c <= 7; c++) {
        const y = row + r;
        const x = col + c;
        if (y < 0 || y >= size || x < 0 || x >= size) continue;
        const inside = r >= 0 && r <= 6 && c >= 0 && c <= 6;
        set(y, x, inside && (r === 0 || r === 6 || c === 0 || c === 6 || (r >= 2 && r <= 4 && c >= 2 && c <= 4)));
      }
    }
  };
  finder(0, 0);
  finder(0, size - 7);
  finder(size - 7, 0);
  for (const row of spec.align) {
    for (const col of spec.align) {
      if (reserved[row][col]) continue; // 위치 찾기 무늬와 겹치는 곳은 건너뛴다
      for (let r = -2; r <= 2; r++) for (let c = -2; c <= 2; c++) set(row + r, col + c, Math.max(Math.abs(r), Math.abs(c)) !== 1);
    }
  }
  for (let i = 8; i < size - 8; i++) {
    if (!reserved[6][i]) set(6, i, i % 2 === 0);
    if (!reserved[i][6]) set(i, 6, i % 2 === 0);
  }
  set(size - 8, 8, true); // 항상 검은 칸
  // 형식 정보 자리(값은 마스크를 고른 뒤 쓴다)와 버전 정보(버전 7 이상)
  for (let i = 0; i < 9; i++) {
    if (!reserved[8][i]) set(8, i, false);
    if (!reserved[i][8]) set(i, 8, false);
  }
  for (let i = 0; i < 8; i++) {
    set(8, size - 1 - i, false);
    if (!reserved[size - 1 - i][8]) set(size - 1 - i, 8, false);
  }
  if (version >= 7) {
    const info = bch(version, 6, 0x1f25, 13);
    for (let i = 0; i < 18; i++) {
      const dark = ((info >> i) & 1) === 1;
      set(Math.floor(i / 3), size - 11 + (i % 3), dark);
      set(size - 11 + (i % 3), Math.floor(i / 3), dark);
    }
  }

  // 데이터 칸: 오른쪽 아래에서 두 열씩 지그재그로 채운다
  const dataCells: [number, number][] = [];
  for (let col = size - 1, upward = true; col > 0; col -= 2, upward = !upward) {
    if (col === 6) col -= 1; // 세로 타이밍 줄은 건너뛴다
    for (let i = 0; i < size; i++) {
      const row = upward ? size - 1 - i : i;
      for (const c of [col, col - 1]) if (!reserved[row][c]) dataCells.push([row, c]);
    }
  }
  dataCells.forEach(([row, col], index) => {
    const byte = codewords[index >> 3];
    matrix[row][col] = byte !== undefined && ((byte >> (7 - (index & 7))) & 1) === 1;
  });

  const build = (mask: number): boolean[][] => {
    const result = matrix.map((row) => row.slice());
    for (const [row, col] of dataCells) if (MASKS[mask](row, col)) result[row][col] = !result[row][col];
    // 형식 정보: 오류 정정 수준 M(00) + 마스크 번호, BCH 를 붙이고 0x5412 와 XOR
    const format = bch(mask, 5, 0x537, 11) ^ 0x5412;
    const bit = (i: number): boolean => ((format >> i) & 1) === 1;
    for (let i = 0; i <= 5; i++) result[8][i] = bit(14 - i);
    result[8][7] = bit(8);
    result[8][8] = bit(7);
    result[7][8] = bit(6);
    for (let i = 0; i <= 5; i++) result[5 - i][8] = bit(5 - i);
    for (let i = 0; i <= 6; i++) result[size - 1 - i][8] = bit(14 - i);
    for (let i = 0; i <= 7; i++) result[8][size - 8 + i] = bit(7 - i);
    return result;
  };

  if (forcedMask !== undefined) return build(forcedMask);
  let best = build(0);
  let bestScore = penalty(best);
  for (let mask = 1; mask < 8; mask++) {
    const candidate = build(mask);
    const score = penalty(candidate);
    if (score < bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}

/** QR 코드를 SVG 글자로 만든다 (테두리 여백 4칸 포함). 흰 바탕에 검은 칸이라 색 토큰을 쓰지 않는다(카메라가 읽어야 한다) */
export function createQrSvg(text: string): string {
  const matrix = createQrMatrix(text);
  const border = 4;
  const size = matrix.length + border * 2;
  let path = '';
  matrix.forEach((row, r) => row.forEach((dark, c) => {
    if (dark) path += `M${c + border} ${r + border}h1v1h-1z`;
  }));
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" shape-rendering="crispEdges"><path fill="#fff" d="M0 0h${size}v${size}H0z"/><path fill="#000" d="${path}"/></svg>`;
}
