// 궁합 영수증용 사진: 폰에서 고른(찍은) 사진을 자르지 않고 영수증 비율의 흰 바탕 안에 줄여 넣어 작은 JPEG data URL 로 만든다.
// 프린터 가로가 384점이라 480×360 이면 충분하다. 작게 만들어 DB 에 그대로 넣는다(약 30~60KB).
import { RECEIPT_PHOTO_ASPECT } from './match-receipt';

const PHOTO_WIDTH = 480;
const JPEG_QUALITY = 0.8;

/** 올릴 수 있는 data URL 최대 길이 (DB 는 200,000자까지 받는다. 여유를 둔다) */
const MAX_DATA_URL_LENGTH = 180000;

interface Drawable {
  source: CanvasImageSource;
  width: number;
  height: number;
}

function loadWithImageElement(file: File): Promise<Drawable> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      if (image.naturalWidth === 0 || image.naturalHeight === 0) reject(new Error('empty'));
      else resolve({ source: image, width: image.naturalWidth, height: image.naturalHeight });
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('decode'));
    };
    image.src = url;
  });
}

/** 사진을 그릴 수 있는 형태로 읽는다. 폰 카메라의 큰 사진도 읽히도록 createImageBitmap 을 먼저 쓰고, 안 되면 img 로 읽는다 */
async function loadDrawable(file: File): Promise<Drawable> {
  if (typeof createImageBitmap === 'function') {
    try {
      const bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
      if (bitmap.width > 0 && bitmap.height > 0) return { source: bitmap, width: bitmap.width, height: bitmap.height };
    } catch {
      // 아래 img 방식으로 다시 시도한다
    }
  }
  try {
    return await loadWithImageElement(file);
  } catch {
    throw new Error('이 사진 형식은 읽지 못했어요. 폰의 기본 카메라로 다시 찍어주세요');
  }
}

/** 사진 파일 → 영수증 비율(4:3)의 흰 바탕에 전체가 보이게 줄여 넣은 JPEG data URL (세로 사진·투명 배경 그림도 잘리거나 검게 나오지 않는다) */
export async function fileToReceiptPhoto(file: File): Promise<string> {
  // 일부 폰은 찍은 사진의 형식(type)을 비워서 준다. 형식이 적혀 있는데 사진이 아닐 때만 막는다
  if (file.type !== '' && !file.type.startsWith('image/')) throw new Error('사진 파일만 올릴 수 있어요');
  const image = await loadDrawable(file);
  const canvas = document.createElement('canvas');
  canvas.width = PHOTO_WIDTH;
  canvas.height = Math.round(PHOTO_WIDTH / RECEIPT_PHOTO_ASPECT);
  const context = canvas.getContext('2d');
  if (!context) throw new Error('사진을 처리하지 못했어요. 다시 시도해주세요');
  // 흰 바탕을 먼저 칠하고(JPEG 는 투명한 곳이 검게 나온다), 사진 전체가 들어가도록 줄여 가운데에 그린다
  context.fillStyle = '#ffffff'; // 종이 색. 화면 색이 아니라 인쇄용 그림이라 토큰을 쓰지 않는다
  context.fillRect(0, 0, canvas.width, canvas.height);
  const scale = Math.min(canvas.width / image.width, canvas.height / image.height);
  const width = image.width * scale;
  const height = image.height * scale;
  context.drawImage(image.source, (canvas.width - width) / 2, (canvas.height - height) / 2, width, height);
  // 너무 크면 화질을 낮춰 다시 만든다
  for (const quality of [JPEG_QUALITY, 0.6, 0.4]) {
    const dataUrl = canvas.toDataURL('image/jpeg', quality);
    if (!dataUrl.startsWith('data:image/jpeg;base64,')) throw new Error('이 브라우저에서는 사진을 만들지 못했어요. 다른 브라우저로 열어주세요');
    if (dataUrl.length <= MAX_DATA_URL_LENGTH) return dataUrl;
  }
  throw new Error('사진이 너무 커요. 다시 찍어주세요');
}

/** JPEG data URL → 캔버스 (인쇄 화면에서 영수증에 넣을 때 쓴다) */
export function dataUrlToCanvas(dataUrl: string): Promise<HTMLCanvasElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = image.naturalWidth;
      canvas.height = image.naturalHeight;
      const context = canvas.getContext('2d');
      if (!context) {
        reject(new Error('사진을 그리지 못했어요'));
        return;
      }
      context.drawImage(image, 0, 0);
      resolve(canvas);
    };
    image.onerror = () => reject(new Error('사진을 읽지 못했어요'));
    image.src = dataUrl;
  });
}
