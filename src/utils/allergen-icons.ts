// 알레르기 이름 → 아이콘 매핑은 이 파일 한 곳에서만 관리한다.
// 키는 DB 의 allergens.name(식약처 표준 이름). 매핑에 없는 카드는 이름만 표시된다.
import eggIcon from '../assets/icons/allergens/egg.svg';
import milkIcon from '../assets/icons/allergens/milk.svg';
import beanIcon from '../assets/icons/allergens/bean.svg';
import shrimpIcon from '../assets/icons/allergens/shrimp.svg';
import shellfishIcon from '../assets/icons/allergens/shellfish.svg';
import chickenIcon from '../assets/icons/allergens/chicken.svg';
import peanutIcon from '../assets/icons/allergens/peanut.svg';
import wheatIcon from '../assets/icons/allergens/wheat.svg';
import crabIcon from '../assets/icons/allergens/crab.svg';
import peachIcon from '../assets/icons/allergens/peach.svg';
import tomatoIcon from '../assets/icons/allergens/tomato.svg';
import mackerelIcon from '../assets/icons/allergens/mackerel.svg';
import buckwheatIcon from '../assets/icons/allergens/buckwheat.svg';
import squidIcon from '../assets/icons/allergens/squid.svg';
import walnutIcon from '../assets/icons/allergens/walnut.svg';
import sulfiteIcon from '../assets/icons/allergens/sulfite.svg';
import beefIcon from '../assets/icons/allergens/beef.png';
import porkIcon from '../assets/icons/allergens/pork.png';
import pineNutIcon from '../assets/icons/allergens/jat.png';

const ALLERGEN_ICONS: Record<string, string> = {
  알류: eggIcon, // 화면 표기는 '계란'
  우유: milkIcon,
  대두: beanIcon, // 화면 표기는 '콩'
  새우: shrimpIcon,
  조개류: shellfishIcon,
  닭고기: chickenIcon,
  땅콩: peanutIcon,
  밀: wheatIcon,
  게: crabIcon,
  복숭아: peachIcon,
  토마토: tomatoIcon,
  고등어: mackerelIcon,
  메밀: buckwheatIcon,
  오징어: squidIcon,
  호두: walnutIcon,
  아황산류: sulfiteIcon,
  쇠고기: beefIcon,
  돼지고기: porkIcon,
  잣: pineNutIcon,
};

export function getAllergenIcon(name: string): string | undefined {
  return ALLERGEN_ICONS[name];
}
