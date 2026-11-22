// 디자인 대기: 알레르기 이름 → 아이콘 매핑은 이 파일 한 곳에서만 관리한다.
// 키는 DB 의 allergens.name. 매핑에 없는 카드는 이름만 표시된다.
import eggIcon from '../assets/icons/allergens/egg.svg';
import milkIcon from '../assets/icons/allergens/milk.svg';
import beanIcon from '../assets/icons/allergens/bean.svg';

const ALLERGEN_ICONS: Record<string, string> = {
  계란: eggIcon,
  우유: milkIcon,
  콩: beanIcon,
};

export function getAllergenIcon(name: string): string | undefined {
  return ALLERGEN_ICONS[name];
}
