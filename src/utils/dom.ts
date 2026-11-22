/** querySelector 헬퍼. 없으면 null. */
export function qs<T extends Element = HTMLElement>(selector: string, parent: ParentNode = document): T | null {
  return parent.querySelector<T>(selector);
}

/** querySelectorAll 헬퍼. 배열로 반환한다. */
export function qsa<T extends Element = HTMLElement>(selector: string, parent: ParentNode = document): T[] {
  return Array.from(parent.querySelectorAll<T>(selector));
}

type Attrs = Record<string, string | boolean | undefined>;

/** 요소 생성 헬퍼. attrs 의 class 는 className 으로, false/undefined 값은 건너뛴다. */
export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs: Attrs = {},
  ...children: (Node | string)[]
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === undefined || value === false) continue;
    if (key === 'class') node.className = String(value);
    else node.setAttribute(key, value === true ? '' : value);
  }
  node.append(...children);
  return node;
}

let toastTimer: number | undefined;

/** 화면 하단에 토스트를 잠시 보여준다. 이전 토스트는 교체된다. */
export function showToast(message: string, duration = 2000): void {
  qs('.toast')?.remove();
  window.clearTimeout(toastTimer);
  const toast = el('div', { class: 'toast', role: 'status' }, message);
  document.body.append(toast);
  toastTimer = window.setTimeout(() => toast.remove(), duration);
}
