import { el } from './dom';
import { safeHttpUrl } from './url';

/** 서버 이미지 주소는 http(s) 만 쓴다. 이미지가 없거나 불러오기에 실패하면 토큰 색 플레이스홀더(div)로 바꾼다. */
export function createImage(url: string | null, className: string): HTMLElement {
  const placeholder = (): HTMLElement => el('div', { class: className });
  const safe = safeHttpUrl(url);
  if (!safe) return placeholder();
  const img = el('img', { class: className, src: safe, alt: '', loading: 'lazy' });
  img.addEventListener('error', () => img.replaceWith(placeholder()));
  return img;
}
