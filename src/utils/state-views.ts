import { el } from './dom';

/** 비동기 호출의 로딩·빈 상태·에러 상태를 컨테이너에 그린다. */
export function renderLoading(container: HTMLElement): void {
  container.replaceChildren(el('div', { class: 'loading', role: 'status', 'aria-label': '불러오는 중' }, el('div', { class: 'spinner' })));
}

export function renderEmpty(container: HTMLElement, title: string, desc: string): void {
  container.replaceChildren(
    el('div', { class: 'empty-state' }, el('p', { class: 'empty-state__title' }, title), el('p', { class: 'empty-state__desc' }, desc)),
  );
}

export function renderError(container: HTMLElement, message: string, onRetry: () => void): void {
  const retry = el('button', { class: 'btn-primary', type: 'button' }, '다시 시도');
  retry.addEventListener('click', onRetry);
  container.replaceChildren(el('div', { class: 'empty-state', role: 'alert' }, el('p', { class: 'empty-state__title' }, message), retry));
}
