// 궁합 영수증용 사진: 폰에서 고른(찍은) 사진을 자르지 않고 영수증 비율의 흰 바탕 안에 줄여 넣어 작은 JPEG data URL 로 만든다.
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

/** 사진 파일 → 영수증 비율(4:3)의 흰 바탕에 전체가 보이게 줄여 넣은 JPEG data URL (세로 사진·투명 배경 그림도 잘리거나 검게 나오지 않는다) */
export async function fileToReceiptPhoto(file: File): Promise<string> {
  if (!file.type.startsWith('image/')) throw new Error('사진 파일만 올릴 수 있어요');
  const image = await loadImage(file);
  const canvas = document.createElement('canvas');
  canvas.width = PHOTO_WIDTH;
  canvas.height = Math.round(PHOTO_WIDTH / RECEIPT_PHOTO_ASPECT);
  const context = canvas.getContext('2d');
  if (!context || image.naturalWidth === 0 || image.naturalHeight === 0) throw new Error('사진을 읽지 못했어요. 다시 찍어주세요');
  // 흰 바탕을 먼저 칠하고(JPEG 는 투명한 곳이 검게 나온다), 사진 전체가 들어가도록 줄여 가운데에 그린다
  context.fillStyle = '#ffffff'; // 종이 색. 화면 색이 아니라 인쇄용 그림이라 토큰을 쓰지 않는다
  context.fillRect(0, 0, canvas.width, canvas.height);
  const scale = Math.min(canvas.width / image.naturalWidth, canvas.height / image.naturalHeight);
  const width = image.naturalWidth * scale;
  const height = image.naturalHeight * scale;
  context.drawImage(image, (canvas.width - width) / 2, (canvas.height - height) / 2, width, height);
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
