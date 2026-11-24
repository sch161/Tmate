import { CATEGORY_IMAGE_SIZE, getCategoryImage } from './category-images';
import { el } from './dom';
import { safeHttpUrl } from './url';

/**
 * 서버 이미지 주소는 http(s) 만 쓴다. 이미지가 없거나 불러오기에 실패하면 음식 카테고리 기본 이미지를,
 * 카테고리가 없거나 매핑에 없으면 토큰 색 플레이스홀더(div)로 바꾼다.
 */
export function createImage(url: string | null, className: string, categoryName?: string | null): HTMLElement {
  const placeholder = (): HTMLElement => createCategoryFallback(className, categoryName) ?? el('div', { class: className });
  const safe = safeHttpUrl(url);
  if (!safe) return placeholder();
  const img = el('img', { class: className, src: safe, alt: '', loading: 'lazy' });
  img.addEventListener('error', () => img.replaceWith(placeholder()));
  return img;
}

/** 카테고리 기본 이미지 <img>. 매핑이 없으면 null. 글자가 들어 있는 이미지라 잘리지 않게 contain 으로 보여준다(common.css 의 .image--category) */
export function createCategoryFallback(className: string, categoryName: string | null | undefined): HTMLElement | null {
  const src = getCategoryImage(categoryName);
  if (!src) return null;
  return el('img', {
    class: `${className} image--category`,
    src,
    alt: '',
    width: String(CATEGORY_IMAGE_SIZE),
    height: String(CATEGORY_IMAGE_SIZE),
    loading: 'lazy',
  });
}
