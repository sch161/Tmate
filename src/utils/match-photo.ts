// 궁합 영수증용 사진: 폰에서 고른(찍은) 사진을 영수증 비율로 가운데를 잘라 작은 JPEG data URL 로 만든다.
// 프린터 가로가 384점이라 480×360 이면 충분하다. 작게 만들어 DB 에 그대로 넣는다(약 30~60KB).
import { RECEIPT_PHOTO_ASPECT } from './match-receipt';

const PHOTO_WIDTH = 480;
const JPEG_QUALITY = 0.8;

function loadImage(file: File): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('사진을 읽지 못했어요. 다시 찍어주세요'));
    };
    image.src = url;
  });
}

/** 사진 파일 → 영수증 비율(4:3)로 가운데를 자른 JPEG data URL */
export async function fileToReceiptPhoto(file: File): Promise<string> {
  if (!file.type.startsWith('image/')) throw new Error('사진 파일만 올릴 수 있어요');
  const image = await loadImage(file);
  const canvas = document.createElement('canvas');
  canvas.width = PHOTO_WIDTH;
  canvas.height = Math.round(PHOTO_WIDTH / RECEIPT_PHOTO_ASPECT);
  const context = canvas.getContext('2d');
  if (!context || image.naturalWidth === 0 || image.naturalHeight === 0) throw new Error('사진을 읽지 못했어요. 다시 찍어주세요');
  // 가운데를 기준으로 영수증 비율만큼 잘라 그린다
  const sourceWidth = Math.min(image.naturalWidth, image.naturalHeight * RECEIPT_PHOTO_ASPECT);
  const sourceHeight = sourceWidth / RECEIPT_PHOTO_ASPECT;
  context.drawImage(image, (image.naturalWidth - sourceWidth) / 2, (image.naturalHeight - sourceHeight) / 2, sourceWidth, sourceHeight, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL('image/jpeg', JPEG_QUALITY);
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
