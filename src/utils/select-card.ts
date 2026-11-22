import { el } from './dom';

/** 선택 카드(.select-card) 버튼. 아이콘이 없으면 이름만 가운데에 표시된다. */
export function createSelectCard(label: string, icon: string | undefined, selected: boolean): HTMLButtonElement {
  const card = el('button', {
    class: selected ? 'select-card is-selected' : 'select-card',
    type: 'button',
    'aria-pressed': String(selected),
  });
  if (icon) card.append(el('img', { class: 'select-card__icon', src: icon, alt: '' }));
  card.append(el('span', { class: 'select-card__label' }, label));
  return card;
}

export function setCardSelected(card: HTMLElement, selected: boolean): void {
  card.classList.toggle('is-selected', selected);
  card.setAttribute('aria-pressed', String(selected));
}
