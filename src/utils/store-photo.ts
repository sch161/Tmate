// 가게 사진: 폰 사진을 올리기 좋은 크기(긴 변 960px)의 JPEG 로 줄인다. 자르지 않는다(화면이 object-fit 으로 맞춘다).
import { loadDrawable } from './match-photo';

const MAX_SIDE = 960;
/** 버킷 한도(600KB)보다 조금 작게 잡는다 */
const MAX_BYTES = 560 * 1024;

export interface StorePhoto {
  blob: Blob;
  extension: 'jpg' | 'png';
}

function toBlob(canvas: HTMLCanvasElement, type: string, quality: number): Promise<Blob | null> {
  return new Promise((resolve) => {
    try {
      canvas.toBlob((blob) => resolve(blob), type, quality);
    } catch {
      resolve(null);
    }
  });
}

export async function fileToStorePhoto(file: File): Promise<StorePhoto> {
  // 일부 폰은 찍은 사진의 형식(type)을 비워서 준다. 형식이 적혀 있는데 사진이 아닐 때만 막는다
  if (file.type !== '' && !file.type.startsWith('image/')) throw new Error('사진 파일만 올릴 수 있어요');
  const image = await loadDrawable(file);
  const scale = Math.min(1, MAX_SIDE / Math.max(image.width, image.height));
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(image.width * scale));
  canvas.height = Math.max(1, Math.round(image.height * scale));
  const context = canvas.getContext('2d');
  if (!context) throw new Error('사진을 처리하지 못했어요. 다시 시도해주세요');
  context.fillStyle = '#ffffff'; // JPEG 는 투명한 곳이 검게 나와서 흰 바탕을 먼저 칠한다 (화면 색이 아니라 사진 바탕이라 토큰을 쓰지 않는다)
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.drawImage(image.source, 0, 0, canvas.width, canvas.height);

  for (const quality of [0.82, 0.65, 0.45]) {
    const blob = await toBlob(canvas, 'image/jpeg', quality);
    if (blob && blob.type === 'image/jpeg' && blob.size <= MAX_BYTES) return { blob, extension: 'jpg' };
  }
  // 일부 브라우저는 JPEG 로 내보내지 못하고 PNG 만 준다. 그때는 크기를 줄여 PNG 로 보낸다
  for (const side of [480, 320]) {
    const small = document.createElement('canvas');
    const ratio = side / Math.max(canvas.width, canvas.height);
    small.width = Math.max(1, Math.round(canvas.width * ratio));
    small.height = Math.max(1, Math.round(canvas.height * ratio));
    small.getContext('2d')?.drawImage(canvas, 0, 0, small.width, small.height);
    const blob = await toBlob(small, 'image/png', 1);
    if (blob && blob.type === 'image/png' && blob.size <= MAX_BYTES) return { blob, extension: 'png' };
  }
  throw new Error('이 브라우저에서는 사진을 만들지 못했어요. 다른 브라우저(사파리·크롬)로 열어주세요');
}
