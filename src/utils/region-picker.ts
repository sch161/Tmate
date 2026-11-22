// 디자인 대기: 화면 나오면 교체
// 지역 선택 하단 시트. 온보딩에 종속되지 않는 공용 모듈이다 (홈의 "위치 변경하기", 설정 화면에서도 재사용).
import '../css/region-picker.css';
import { getAvailableRegions } from '../api/lookups';
import { el } from './dom';
import { renderEmpty, renderError, renderLoading } from './state-views';

export interface PickRegionOptions {
  /** 현재 선택된 지역 (목록에서 강조) */
  current?: string | null;
}

/** 지역 선택 시트를 띄우고 고른 region 을 돌려준다. 닫으면(바깥 클릭·Esc·닫기) null. */
export function pickRegion(options: PickRegionOptions = {}): Promise<string | null> {
  return new Promise((resolve) => {
    const title = el('h2', { class: 'region-picker__title', id: 'region-picker-title' }, '지역을 선택해 주세요');
    const content = el('div', { class: 'region-picker__content' });
    const closeBtn = el('button', { class: 'region-picker__close', type: 'button' }, '닫기');
    const backdrop = el('button', { class: 'region-picker__backdrop', type: 'button', 'aria-label': '닫기', tabindex: '-1' });
    const sheet = el(
      'div',
      { class: 'region-picker__sheet', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'region-picker-title' },
      title,
      content,
      closeBtn,
    );
    const root = el('div', { class: 'region-picker' }, backdrop, sheet);

    const previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;

    function finish(value: string | null): void {
      document.removeEventListener('keydown', onKeydown);
      root.remove();
      previousFocus?.focus();
      resolve(value);
    }

    function onKeydown(event: KeyboardEvent): void {
      if (event.key === 'Escape') finish(null);
    }

    function renderList(regions: string[]): void {
      if (regions.length === 0) {
        renderEmpty(content, '선택할 수 있는 지역이 없어요', '잠시 후 다시 시도해주세요');
        return;
      }
      const list = el('ul', { class: 'region-picker__list' });
      let focusTarget: HTMLElement | null = null;
      for (const region of regions) {
        const selected = region === options.current;
        const item = el('button', {
          class: selected ? 'region-picker__item is-selected' : 'region-picker__item',
          type: 'button',
          'aria-pressed': String(selected),
        }, region);
        item.addEventListener('click', () => finish(region));
        list.append(el('li', {}, item));
        if (selected || !focusTarget) focusTarget = item;
      }
      content.replaceChildren(list);
      focusTarget?.focus();
    }

    async function load(): Promise<void> {
      renderLoading(content);
      try {
        renderList((await getAvailableRegions()).map((option) => option.region));
      } catch (e) {
        renderError(content, e instanceof Error ? e.message : '목록을 불러오지 못했어요', () => void load());
      }
    }

    backdrop.addEventListener('click', () => finish(null));
    closeBtn.addEventListener('click', () => finish(null));
    document.addEventListener('keydown', onKeydown);
    document.body.append(root);
    void load();
  });
}
