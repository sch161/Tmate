// 음식 카테고리 이름 → 기본 이미지 매핑은 이 파일 한 곳에서만 관리한다.
// 키는 DB 의 food_categories.name (RPC 의 category_name). 이미지가 없거나 매핑에 없는 값이면 undefined → 호출한 쪽이 기본 색 박스를 쓴다.
// 분식은 category-street-food.png, 카페·디저트는 category-snack.png(간식)를 쓴다.
// 카테고리가 생기면 아래에 import 와 매핑 한 줄씩만 추가하면 된다.
import chineseImage from '../assets/images/categories/category-chinese.png';
import japaneseImage from '../assets/images/categories/category-japanese.png';
import koreanImage from '../assets/images/categories/category-korean.png';
import snackImage from '../assets/images/categories/category-snack.png';
import streetFoodImage from '../assets/images/categories/category-street-food.png';
import westernImage from '../assets/images/categories/category-western.png';

const CATEGORY_IMAGES: Record<string, string> = {
  한식: koreanImage,
  중식: chineseImage,
  일식: japaneseImage,
  양식: westernImage,
  분식: streetFoodImage,
  // 카페·디저트 전용 그림이 없어 간식 그림을 쓴다. 치킨·아시안은 그림이 없어 기본 색 박스가 나온다
  '카페·디저트': snackImage,
};

/** 원본 이미지 크기(2x). <img> 의 width/height 속성에 써서 레이아웃이 흔들리지 않게 한다 */
export const CATEGORY_IMAGE_SIZE = 342;

export function getCategoryImage(categoryName: string | null | undefined): string | undefined {
  if (!categoryName) return undefined;
  return Object.prototype.hasOwnProperty.call(CATEGORY_IMAGES, categoryName) ? CATEGORY_IMAGES[categoryName] : undefined;
}
