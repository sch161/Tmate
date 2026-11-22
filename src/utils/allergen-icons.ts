// 디자인 대기: 알레르기 이름 → 아이콘 매핑은 이 파일 한 곳에서만 관리한다.
// 키는 DB 의 allergens.name(식약처 표준 이름). 매핑에 없는 카드(나머지 16종)는 이름만 표시된다.
import eggIcon from '../assets/icons/allergens/egg.svg';
import milkIcon from '../assets/icons/allergens/milk.svg';
import beanIcon from '../assets/icons/allergens/bean.svg';

const ALLERGEN_ICONS: Record<string, string> = {
  알류: eggIcon, // 화면 표기는 '계란'
  우유: milkIcon,
  대두: beanIcon, // 화면 표기는 '콩'
};

export function getAllergenIcon(name: string): string | undefined {
  return ALLERGEN_ICONS[name];
}
