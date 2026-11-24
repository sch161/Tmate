// src/utils/qr.ts 회귀 테스트. 실행: node scripts/test-qr.mjs
// 아래 기대값은 이 구현이 만든 QR 을 독립 판독기(OpenCV QRCodeDetector)로 읽어 원래 글자가 나오는 것을 확인한 뒤 고정한 것이다.
// (칸을 '1'/'0' 줄로 적어 줄바꿈으로 이은 글자의 SHA-256). 구현을 바꿔 값이 달라지면 실제 폰 카메라로 다시 읽어 확인하고 갱신한다.
import { createHash } from 'node:crypto';
import { createQrMatrix, createQrSvg } from '../src/utils/qr.ts';

const EXPECTED = [
  {
    "text": "A",
    "size": 21,
    "sha256": "bc9009ae87ca68f1d256b69eb26362086d73d9f0b95f1e9f3dccae752626c3b6"
  },
  {
    "text": "https://t-mate.vercel.app/",
    "size": 25,
    "sha256": "48a6559add71f7999be3287babb1de2c5c6cb7928cd6d2cfb2d8942177352e84"
  },
  {
    "text": "hello world 1234567890 abcdefghij",
    "size": 29,
    "sha256": "2c0e253bb75ce22e5a11120cab9183827831a2f40ba7d302a72851704baf92e7"
  },
  {
    "text": "https://t-mate.vercel.app/src/pages/match-photo.html?t=123e4567-e89b-12d3-a456-426614174000",
    "size": 41,
    "sha256": "b810d7361c822a6fe97e2a456f72c6c7bdfeab4a65635d938bb2985a99290af5"
  },
  {
    "text": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "size": 41,
    "sha256": "898a791db8daf87950e6fd89cebf33096e6b40e0b49b39bdd015fdd3c07d3ec9"
  },
  {
    "text": "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy",
    "size": 49,
    "sha256": "3a3833c490a0690918a110567e84be0d2059f09529f07fc524d855cc2f2efa16"
  }
];

let failed = 0;
const check = (ok, name) => {
  if (!ok) failed += 1;
  console.log(`${ok ? 'ok' : 'FAIL'} - ${name}`);
};
for (const item of EXPECTED) {
  const matrix = createQrMatrix(item.text);
  const hash = createHash('sha256').update(matrix.map((row) => row.map((dark) => (dark ? '1' : '0')).join('')).join('\n')).digest('hex');
  check(matrix.length === item.size && hash === item.sha256, `${item.size}칸, ${item.text.length}자: ${item.text.slice(0, 30)}`);
}
const svg = createQrSvg('https://t-mate.vercel.app/');
check(svg.startsWith('<svg') && svg.includes('viewBox="0 0 33 33"'), 'SVG: 25칸 + 여백 4칸씩 = 33');
let tooLong = false;
try {
  createQrMatrix('x'.repeat(153));
} catch {
  tooLong = true;
}
check(tooLong, '153바이트는 너무 길다고 알려준다');
console.log(`${EXPECTED.length + 2 - failed}/${EXPECTED.length + 2} passed`);
if (failed > 0) process.exit(1);
