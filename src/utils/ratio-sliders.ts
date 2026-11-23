// 입맛 비율 슬라이더 목록. 합계는 항상 100 이다. 온보딩 비율 화면과 마이페이지 입맛 수정이 같이 쓴다.
import { el } from './dom';
import { adjustRatios } from './ratio';

export interface RatioItem {
  id: number;
  name: string;
}

/**
 * items 순서대로 슬라이더를 만든다. initial 은 items 와 같은 순서의 비율(합 100)이다.
 * 만들어진 직후 한 번, 그리고 슬라이더를 움직일 때마다 onChange(values) 를 부른다.
 */
export function createRatioSliders(items: RatioItem[], initial: number[], onChange: (values: number[]) => void): HTMLElement {
  let values = initial.slice();
  const sliders: HTMLInputElement[] = [];
  const outputs: HTMLOutputElement[] = [];

  const paint = (): void => {
    values.forEach((v, i) => {
      sliders[i].value = String(v);
      sliders[i].style.setProperty('--value', String(v));
      sliders[i].setAttribute('aria-valuetext', `${v}%`);
      outputs[i].textContent = `${v}%`;
    });
  };

  const list = el('div', { class: 'ratio-list' });
  items.forEach((item, index) => {
    const slider = el('input', { class: 'ratio-slider', type: 'range', id: `ratio-${item.id}`, min: '1', max: '100', step: '1' });
    const output = el('output', { class: 'ratio-item__value', for: slider.id });
    slider.addEventListener('input', () => {
      values = adjustRatios(values, index, Number(slider.value));
      paint();
      onChange(values.slice());
    });
    sliders.push(slider);
    outputs.push(output);
    list.append(
      el('div', { class: 'ratio-item' }, el('div', { class: 'ratio-item__head' }, el('label', { class: 'ratio-item__name', for: slider.id }, item.name), output), slider),
    );
  });
  paint();
  onChange(values.slice());
  return list;
}
