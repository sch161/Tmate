// 알레르기 선택 카드 그리드. 온보딩 알레르기 화면과 마이페이지 알레르기 수정이 같이 쓴다.
import type { Allergen } from '../api/lookups';
import { getAllergenIcon } from './allergen-icons';
import { el } from './dom';
import { createSelectCard, setCardSelected } from './select-card';

/**
 * 3열 선택 카드 그리드. 표시는 display_name, 아이콘은 표준 이름(name) 기준, 선택은 id 기준이다.
 * selected 는 호출한 쪽이 넘긴 Set 을 그대로 갱신하고, 바뀔 때마다 onChange 를 부른다.
 */
export function createAllergenGrid(allergens: Allergen[], selected: Set<number>, onChange?: (selected: Set<number>) => void): HTMLElement {
  const grid = el('div', { class: 'select-grid' });
  for (const allergen of allergens) {
    const card = createSelectCard(allergen.display_name, getAllergenIcon(allergen.name), selected.has(allergen.id));
    card.addEventListener('click', () => {
      if (selected.has(allergen.id)) selected.delete(allergen.id);
      else selected.add(allergen.id);
      setCardSelected(card, selected.has(allergen.id));
      onChange?.(selected);
    });
    grid.append(card);
  }
  return grid;
}
