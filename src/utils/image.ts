import { getBrandLogo, getBrandPhoto, isDarkBackgroundLogo } from './brand-logos';
import { CATEGORY_IMAGE_SIZE, getCategoryImage } from './category-images';
import { el } from './dom';
import { safeHttpUrl } from './url';

/**
 * 서버 이미지 주소는 http(s) 만 쓴다. 이미지가 없거나 불러오기에 실패하면 음식 카테고리 기본 이미지를,
 * 카테고리가 없거나 매핑에 없으면 토큰 색 플레이스홀더(div)로 바꾼다. brandName 을 주면 카테고리 그림보다 브랜드 그림을 먼저 쓴다.
 * prefer 가 'photo' 이면 브랜드 대표 메뉴 사진 → 로고 순, 'logo'(기본)이면 로고만 쓴다 (메뉴 카드에 브랜드 대표 사진을 쓰면 그 메뉴 사진으로 오해한다).
 */
export function createImage(url: string | null, className: string, categoryName?: string | null, brandName?: string | null, prefer: 'photo' | 'logo' = 'logo'): HTMLElement {
  const placeholder = (): HTMLElement =>
    (prefer === 'photo' ? createBrandPhoto(className, brandName) : null) ?? createBrandLogo(className, brandName) ?? createCategoryFallback(className, categoryName) ?? el('div', { class: className });
  const safe = safeHttpUrl(url);
  if (!safe) return placeholder();
  const img = el('img', { class: className, src: safe, alt: '', loading: 'lazy' });
  img.addEventListener('error', () => img.replaceWith(placeholder()));
  return img;
}

/** 브랜드 로고 <img>. 로고가 없는 브랜드면 null. 잘리지 않게 contain 으로 보여준다(common.css 의 .image--brand) */
export function createBrandLogo(className: string, brandName: string | null | undefined): HTMLElement | null {
  const src = getBrandLogo(brandName);
  if (!src) return null;
  return el('img', { class: `${className} image--category image--brand${isDarkBackgroundLogo(brandName) ? ' image--brand-dark' : ''}`, src, alt: '', loading: 'lazy' });
}

/** 브랜드 대표 메뉴 사진 <img>. 사진이 없는 브랜드면 null */
export function createBrandPhoto(className: string, brandName: string | null | undefined): HTMLElement | null {
  const src = getBrandPhoto(brandName);
  if (!src) return null;
  return el('img', { class: className, src, alt: '', loading: 'lazy' });
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
