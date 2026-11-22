// 디자인 대기: 화면 나오면 교체
// 지역 선택 하단 시트. 온보딩에 종속되지 않는 공용 모듈이다 (홈의 "위치 변경하기", 설정 화면에서도 재사용).
import '../css/region-picker.css';
import { getAvailableRegions } from '../api/lookups';
import { el } from './dom';
import { renderEmpty, renderError, renderLoading } from './state-views';

export interface PickRegionOptions {
  /** 현재 선택된 지역 (목록에서 강조하고, 열릴 때 그 위치로 스크롤한다) */
  current?: string | null;
}

// ---------- 뒤 페이지 스크롤 잠금 ----------
// 시트가 여러 번 열리거나 겹쳐도 잠금이 남지 않도록 카운트하고, 처음 잠글 때의 상태를 저장해 마지막에 복구한다.
// body 를 position: fixed 로 고정해야 iOS 에서도 뒤 페이지가 움직이지 않는다.
let lockCount = 0;
let savedBodyStyle: { overflow: string; position: string; top: string; width: string } | null = null;
let savedScrollY = 0;

function lockPageScroll(): void {
  lockCount += 1;
  if (lockCount > 1) return;
  const { style } = document.body;
  savedScrollY = window.scrollY;
  savedBodyStyle = { overflow: style.overflow, position: style.position, top: style.top, width: style.width };
  style.overflow = 'hidden';
  style.position = 'fixed';
  style.top = `-${savedScrollY}px`;
  style.width = '100%';
}

function unlockPageScroll(): void {
  if (lockCount === 0) return;
  lockCount -= 1;
  if (lockCount > 0 || !savedBodyStyle) return;
  const { style } = document.body;
  style.overflow = savedBodyStyle.overflow;
  style.position = savedBodyStyle.position;
  style.top = savedBodyStyle.top;
  style.width = savedBodyStyle.width;
  savedBodyStyle = null;
  window.scrollTo(0, savedScrollY);
}

const FOCUSABLE = 'button:not([disabled]), [href], input, select, textarea, [tabindex]:not([tabindex="-1"])';

/** 지역 선택 시트를 띄우고 고른 region 을 돌려준다. 닫으면(바깥 클릭·Esc·닫기) null. */
export function pickRegion(options: PickRegionOptions = {}): Promise<string | null> {
  return new Promise((resolve) => {
    const title = el('h2', { class: 'region-picker__title', id: 'region-picker-title' }, '지역을 선택해 주세요');
    const content = el('div', { class: 'region-picker__content' });
    const closeBtn = el('button', { class: 'region-picker__close', type: 'button' }, '닫기');
    const backdrop = el('button', { class: 'region-picker__backdrop', type: 'button', 'aria-label': '닫기', tabindex: '-1' });
    const sheet = el(
      'div',
      { class: 'region-picker__sheet', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'region-picker-title', tabindex: '-1' },
      title,
      content,
      closeBtn,
    );
    const root = el('div', { class: 'region-picker' }, backdrop, sheet);

    const previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    let finished = false;
    let removeFontsListener: (() => void) | null = null;

    function finish(value: string | null): void {
      if (finished) return;
      finished = true;
      document.removeEventListener('keydown', onKeydown);
      window.removeEventListener('pagehide', onPageHide);
      removeFontsListener?.();
      root.remove();
      unlockPageScroll();
      if (previousFocus?.isConnected) previousFocus.focus(); // 시트를 연 버튼으로 포커스 복귀
      resolve(value);
    }

    // 선택 중 페이지가 이동하거나 bfcache 에 들어가도 body 잠금이 남지 않게 한다
    function onPageHide(): void {
      finish(null);
    }

    function onKeydown(event: KeyboardEvent): void {
      if (event.key === 'Escape') {
        finish(null);
        return;
      }
      if (event.key !== 'Tab') return;
      // 포커스가 시트 밖으로 나가지 않게 가둔다
      const items = Array.from(sheet.querySelectorAll<HTMLElement>(FOCUSABLE));
      if (items.length === 0) {
        event.preventDefault();
        sheet.focus();
        return;
      }
      const first = items[0];
      const last = items[items.length - 1];
      const active = document.activeElement;
      if (event.shiftKey && (active === first || active === sheet)) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && active === last) {
        event.preventDefault();
        first.focus();
      } else if (!sheet.contains(active)) {
        event.preventDefault();
        first.focus();
      }
    }

    function renderList(regions: string[]): void {
      if (regions.length === 0) {
        renderEmpty(content, '선택할 수 있는 지역이 없어요', '잠시 후 다시 시도해주세요');
        return;
      }
      const list = el('ul', { class: 'region-picker__list' });
      let focusTarget: HTMLElement | null = null;
      let selectedItem: HTMLElement | null = null;
      for (const region of regions) {
        const selected = region === options.current;
        const item = el('button', {
          class: selected ? 'region-picker__item is-selected' : 'region-picker__item',
          type: 'button',
          'aria-pressed': String(selected),
        }, region);
        item.addEventListener('click', () => finish(region));
        list.append(el('li', {}, item));
        if (selected) selectedItem = item;
        if (!focusTarget) focusTarget = item;
      }
      content.replaceChildren(list);
      // 열릴 때 현재 지역이 보이도록 그 위치로 스크롤하고, 그 항목(없으면 첫 항목)으로 포커스를 옮긴다.
      // 시트가 막 나타나는 순간이라 즉시 이동한다(behavior: 'auto'). 부드러운 스크롤은 쓰지 않으므로 모션 줄이기 설정과도 충돌하지 않는다.
      (selectedItem ?? focusTarget)?.focus({ preventScroll: true });
      if (selectedItem) {
        const target = selectedItem;
        const reveal = (): void => {
          target.scrollIntoView({ block: 'center', behavior: 'auto' });
          // 목록 끝 근처 항목은 브라우저가 몇 px 덜 스크롤하는 경우가 있어, 항목이 완전히 보이도록 보정한다
          const box = content.getBoundingClientRect();
          const rect = target.getBoundingClientRect();
          if (rect.bottom > box.bottom) content.scrollTop += rect.bottom - box.bottom;
          else if (rect.top < box.top) content.scrollTop -= box.top - rect.top;
        };
        reveal();
        // 웹 폰트가 늦게 로드되어 항목 높이가 바뀌면 위치가 어긋나므로, 사용자가 아직 스크롤하지 않았다면 다시 맞춘다
        let userScrolled = false;
        for (const type of ['wheel', 'touchmove', 'pointerdown', 'keydown']) {
          content.addEventListener(type, () => (userScrolled = true), { passive: true, once: true });
        }
        const onFontsLoaded = (): void => {
          if (!finished && !userScrolled) reveal();
        };
        document.fonts.addEventListener('loadingdone', onFontsLoaded);
        removeFontsListener = () => document.fonts.removeEventListener('loadingdone', onFontsLoaded);
      }
    }

    async function load(): Promise<void> {
      renderLoading(content);
      try {
        const regions = (await getAvailableRegions()).map((option) => option.region);
        if (!finished) renderList(regions);
      } catch (e) {
        if (!finished) renderError(content, e instanceof Error ? e.message : '목록을 불러오지 못했어요', () => void load());
      }
    }

    backdrop.addEventListener('click', () => finish(null));
    // 터치 환경에서 배경을 끌어도 뒤 페이지가 움직이지 않게 한다
    backdrop.addEventListener('touchmove', (event) => event.preventDefault(), { passive: false });
    closeBtn.addEventListener('click', () => finish(null));
    document.addEventListener('keydown', onKeydown);
    window.addEventListener('pagehide', onPageHide);
    lockPageScroll();
    document.body.append(root);
    sheet.focus(); // 목록이 뜨기 전에도 포커스가 시트 안에 있게 한다
    void load();
  });
}
