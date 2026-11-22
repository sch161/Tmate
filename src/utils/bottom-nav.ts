import homeIcon from '../assets/icons/nav-home.svg';
import saveIcon from '../assets/icons/nav-save.svg';
import mypageIcon from '../assets/icons/nav-mypage.svg';
import { PATHS } from '../lib/constants';
import { el } from './dom';

export type NavTab = 'home' | 'save' | 'mypage';

const TABS: { key: NavTab; label: string; icon: string; href: string }[] = [
  { key: 'home', label: '홈', icon: homeIcon, href: PATHS.home },
  { key: 'save', label: '저장', icon: saveIcon, href: PATHS.save },
  { key: 'mypage', label: '마이페이지', icon: mypageIcon, href: PATHS.mypage },
];

/** 하단 네비게이션(홈/저장/마이페이지)을 만들어 반환한다. 현재 탭은 강조된다. 삽입은 호출한 쪽에서 한다. */
export function renderBottomNav(active: NavTab): HTMLElement {
  const nav = el('nav', { class: 'bottom-nav', 'aria-label': '하단 메뉴' });
  for (const tab of TABS) {
    const link = el('a', {
      class: tab.key === active ? 'bottom-nav__item is-active' : 'bottom-nav__item',
      href: tab.href,
      'aria-label': tab.label,
      'aria-current': tab.key === active ? 'page' : undefined,
    });
    link.style.setProperty('--icon', `url("${tab.icon}")`);
    nav.append(link);
  }
  return nav;
}
