// 디자인 대기: 화면 나오면 교체 (영수증 배치는 임시다)
// 맛궁합 영수증: 미니 감열 프린터(가로 384점)에 찍을 그림을 캔버스에 그리고, 인쇄될 1비트 점으로 바꾼다.
// 감열 프린터는 검정 점만 찍으므로 흰 바탕에 검정으로만 그린다. 사진 영역만 디더링하고 글자는 또렷하게 둔다.
import { MXW01_WIDTH, rgbaToMono } from './mxw01-protocol';
import { getMatchTier, type MatchResultCard } from './match-results';

export const RECEIPT_SITE = 't-mate.vercel.app';
export const RECEIPT_MAX_CARDS = 4;
/** 사진 비율 (가로:세로 = 4:3). 촬영 화면의 틀도 같은 비율을 쓴다 */
export const RECEIPT_PHOTO_ASPECT = 4 / 3;

export interface ReceiptInput {
  nicknameA: string;
  nicknameB: string;
  /** 궁합(%) 0~100 */
  score: number;
  /** 음식 결과 카드 (buildResultCards 결과). 앞에서부터 RECEIPT_MAX_CARDS 개만 쓴다 */
  cards: MatchResultCard[];
  /** 촬영한 사진. 없으면 사진 없이 그린다 */
  photo: HTMLCanvasElement | null;
  /** 사진 중간 톤 보정. 1 = 그대로, 1 보다 작으면 밝게, 크면 어둡게 (기본 1). 프린터·조명에 따라 진행자가 고른다 */
  photoGamma?: number;
  date: Date;
}

export interface ReceiptImage {
  width: number;
  height: number;
  /** 인쇄될 점 (1 = 검정). 미리보기와 인쇄에 같은 값을 쓴다 */
  mono: Uint8Array;
}

// 프린터의 점 색이다 (화면 UI 색이 아니라서 디자인 토큰을 쓰지 않는다)
const INK = '#000000';
const PAPER = '#ffffff';

const WIDTH = MXW01_WIDTH;
const MARGIN = 16;
const INNER = WIDTH - MARGIN * 2;
const PHOTO_HEIGHT = Math.round(INNER / RECEIPT_PHOTO_ASPECT);
const MAX_HEIGHT = 2400; // 그릴 때 쓰는 넉넉한 높이. 다 그린 뒤 쓴 만큼만 잘라 낸다
const BOTTOM_FEED = 120; // 뜯는 곳까지 종이를 밀어내는 아래 여백 (약 15mm)
const FONT_WEIGHTS = [400, 500, 700];

function fontFamily(): string {
  return getComputedStyle(document.documentElement).getPropertyValue('--font-family-base').trim() || 'sans-serif';
}

/** 웹폰트(Paperlogy)가 준비된 뒤에 그려야 캔버스에 기본 글꼴로 찍히지 않는다 */
async function waitForFonts(family: string): Promise<void> {
  try {
    await Promise.all(FONT_WEIGHTS.map((weight) => document.fonts.load(`${weight} 24px ${family}`, '가A1%')));
    await document.fonts.ready;
  } catch {
    // 글꼴을 못 불러와도 기본 글꼴로 그린다
  }
}

/** 어절 단위로 줄을 나누고, 한 어절이 폭을 넘으면 글자 단위로 끊는다 */
function wrapText(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string[] {
  const lines: string[] = [];
  let line = '';
  for (const word of text.split(/\s+/).filter(Boolean)) {
    const joined = line ? `${line} ${word}` : word;
    if (ctx.measureText(joined).width <= maxWidth) {
      line = joined;
      continue;
    }
    if (line) lines.push(line);
    line = '';
    for (const char of word) {
      if (line && ctx.measureText(line + char).width > maxWidth) {
        lines.push(line);
        line = '';
      }
      line += char;
    }
  }
  if (line) lines.push(line);
  return lines;
}

/** 폭을 넘는 글은 끝을 … 로 줄인다 */
function ellipsize(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string {
  if (ctx.measureText(text).width <= maxWidth) return text;
  let cut = text;
  while (cut.length > 1 && ctx.measureText(`${cut}…`).width > maxWidth) cut = cut.slice(0, -1);
  return `${cut}…`;
}

function drawHeart(ctx: CanvasRenderingContext2D, cx: number, top: number, size: number): void {
  const half = size / 2;
  ctx.beginPath();
  ctx.moveTo(cx, top + size);
  ctx.bezierCurveTo(cx - size * 1.1, top + size * 0.45, cx - half * 0.9, top - size * 0.15, cx, top + size * 0.3);
  ctx.bezierCurveTo(cx + half * 0.9, top - size * 0.15, cx + size * 1.1, top + size * 0.45, cx, top + size);
  ctx.fill();
}

/** 사진을 감열 인쇄에 맞게 다듬는다: 흑백으로 바꾸고, 어두운 쪽·밝은 쪽 1% 를 잘라 명암을 편 뒤 gamma 로 중간 톤을 조절한다 */
function tonePhoto(image: ImageData, gamma: number): void {
  const { data } = image;
  const pixels = data.length / 4;
  const histogram = new Uint32Array(256);
  for (let i = 0; i < pixels; i++) {
    const gray = Math.round(0.299 * data[i * 4] + 0.587 * data[i * 4 + 1] + 0.114 * data[i * 4 + 2]);
    data[i * 4] = gray;
    histogram[gray] += 1;
  }
  const clip = pixels * 0.01;
  let low = 0;
  let high = 255;
  for (let sum = 0; low < 255 && (sum += histogram[low]) < clip; low++);
  for (let sum = 0; high > 0 && (sum += histogram[high]) < clip; high--);
  // 밝기가 거의 한 가지뿐인 사진(단색 배경 등)을 억지로 펴면 전부 검정이나 흰색이 된다 → 펴는 폭에 하한을 둔다
  const MIN_RANGE = 96;
  if (high - low < MIN_RANGE) {
    const middle = (high + low) / 2;
    low = Math.max(0, Math.min(255 - MIN_RANGE, Math.round(middle - MIN_RANGE / 2)));
    high = low + MIN_RANGE;
  }
  const range = high - low;
  for (let i = 0; i < pixels; i++) {
    const stretched = Math.min(1, Math.max(0, (data[i * 4] - low) / range));
    const value = Math.round(255 * stretched ** gamma);
    data[i * 4] = value;
    data[i * 4 + 1] = value;
    data[i * 4 + 2] = value;
    data[i * 4 + 3] = 255;
  }
}

/** 영수증을 그리고 인쇄될 점으로 바꾼다 */
export async function renderMatchReceipt(input: ReceiptInput): Promise<ReceiptImage> {
  const family = fontFamily();
  await waitForFonts(family);

  const canvas = document.createElement('canvas');
  canvas.width = WIDTH;
  canvas.height = MAX_HEIGHT;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) throw new Error('영수증을 그리지 못했어요');
  ctx.fillStyle = PAPER;
  ctx.fillRect(0, 0, WIDTH, MAX_HEIGHT);
  ctx.fillStyle = INK;
  ctx.strokeStyle = INK;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';

  const center = WIDTH / 2;
  let y = 24;
  const setFont = (weight: number, size: number): void => {
    ctx.font = `${weight} ${size}px ${family}`;
  };
  /** 가운데 정렬로 여러 줄을 그리고 y 를 내린다 */
  const paragraph = (text: string, weight: number, size: number, gap = 6): void => {
    setFont(weight, size);
    for (const line of wrapText(ctx, text, INNER)) {
      ctx.fillText(line, center, y);
      y += size + gap;
    }
  };
  const rule = (): void => {
    y += 10;
    ctx.save();
    ctx.lineWidth = 2;
    ctx.setLineDash([8, 6]);
    ctx.beginPath();
    ctx.moveTo(MARGIN, y + 1);
    ctx.lineTo(WIDTH - MARGIN, y + 1);
    ctx.stroke();
    ctx.restore();
    y += 16;
  };

  // 제목
  paragraph('T:MATE', 700, 52, 4);
  paragraph('친구랑 맛궁합 검사', 500, 22);
  rule();

  // 사진 (가운데를 4:3 으로 잘라 넣는다)
  let photoRows: { from: number; to: number } | undefined;
  if (input.photo && input.photo.width > 0 && input.photo.height > 0) {
    const source = input.photo;
    const sourceAspect = source.width / source.height;
    const cropWidth = sourceAspect > RECEIPT_PHOTO_ASPECT ? source.height * RECEIPT_PHOTO_ASPECT : source.width;
    const cropHeight = sourceAspect > RECEIPT_PHOTO_ASPECT ? source.height : source.width / RECEIPT_PHOTO_ASPECT;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(source, (source.width - cropWidth) / 2, (source.height - cropHeight) / 2, cropWidth, cropHeight, MARGIN, y, INNER, PHOTO_HEIGHT);
    const image = ctx.getImageData(MARGIN, y, INNER, PHOTO_HEIGHT);
    tonePhoto(image, input.photoGamma ?? 1);
    ctx.putImageData(image, MARGIN, y);
    photoRows = { from: y, to: y + PHOTO_HEIGHT };
    y += PHOTO_HEIGHT;
    // 테두리는 디더링 범위 밖(아래 줄)과 안쪽 양옆에 그린다. 순수한 검정이라 디더링해도 그대로 검정이다
    ctx.lineWidth = 3;
    ctx.strokeRect(MARGIN + 1.5, photoRows.from + 1.5, INNER - 3, PHOTO_HEIGHT - 3);
    y += 18;
  }

  // 닉네임 ♥ 닉네임: 한 줄에 들어가면 한 줄, 길면 세 줄(이름 / ♥ / 이름)
  const HEART = 24;
  const NAME_SIZE = 30;
  setFont(700, NAME_SIZE);
  const widthA = ctx.measureText(input.nicknameA).width;
  const widthB = ctx.measureText(input.nicknameB).width;
  const heartSpace = HEART + 20;
  if (widthA + heartSpace + widthB <= INNER) {
    const left = center - (widthA + heartSpace + widthB) / 2;
    ctx.textAlign = 'left';
    ctx.fillText(input.nicknameA, left, y);
    drawHeart(ctx, left + widthA + heartSpace / 2, y + 4, HEART);
    ctx.fillText(input.nicknameB, left + widthA + heartSpace, y);
    ctx.textAlign = 'center';
    y += NAME_SIZE + 10;
  } else {
    ctx.fillText(ellipsize(ctx, input.nicknameA, INNER), center, y);
    y += NAME_SIZE + 8;
    drawHeart(ctx, center, y, HEART);
    y += HEART + 8;
    ctx.fillText(ellipsize(ctx, input.nicknameB, INNER), center, y);
    y += NAME_SIZE + 10;
  }

  // 점수와 결과 문구
  const tier = getMatchTier(input.score);
  paragraph(`${input.score}%`, 700, 112, 8);
  paragraph(tier.title, 700, 28, 8);
  paragraph(tier.desc, 400, 22, 6);

  // 음식 카드
  const cards = input.cards.slice(0, RECEIPT_MAX_CARDS);
  for (const card of cards) {
    rule();
    paragraph(card.label, 500, 20, 6);
    paragraph(card.foodName, 700, 30, 8);
    // "A 5점 · B 4점" 이 한 줄에 안 들어가면 사람별로 줄을 나눈다
    setFont(400, 20);
    const details = ctx.measureText(card.detail).width <= INNER ? [card.detail] : card.detail.split(' · ');
    for (const detail of details) paragraph(detail, 400, 20, 4);
  }
  rule();

  // 날짜와 사이트 주소
  paragraph(new Intl.DateTimeFormat('ko-KR', { dateStyle: 'medium', timeStyle: 'short' }).format(input.date), 400, 20, 8);
  paragraph(RECEIPT_SITE, 700, 24, 0);
  const height = Math.min(MAX_HEIGHT, y + BOTTOM_FEED);

  const rgba = ctx.getImageData(0, 0, WIDTH, height).data;
  // 사진이 없으면 디더링할 곳이 없다 → 전부 threshold
  const mono = photoRows ? rgbaToMono(rgba, WIDTH, height, { dither: 'floyd-steinberg', ditherRows: photoRows }) : rgbaToMono(rgba, WIDTH, height, { dither: 'threshold' });
  return { width: WIDTH, height, mono };
}
