// 맛 선택 카드 그리드(최대 MAX_TASTE_SELECTION 개). 온보딩 맛 선택과 마이페이지 입맛 수정이 같이 쓴다.
import { MAX_TASTE_SELECTION } from '../lib/constants';
import { el, showToast } from './dom';
import { createSelectCard, setCardSelected } from './select-card';
import { getTasteIcon } from './taste-icons';

export interface TasteTagItem {
  id: number;
  code: string;
  name: string;
}

/**
 * 3열 선택 카드 그리드. selected 는 호출한 쪽이 넘긴 Set 을 그대로 갱신하고, 바뀔 때마다 onChange 를 부른다.
 * 최대 개수를 넘기려 하면 토스트만 보여주고 선택하지 않는다.
 */
export function createTasteGrid(tags: TasteTagItem[], selected: Set<number>, onChange: (selected: Set<number>) => void): HTMLElement {
  const grid = el('div', { class: 'select-grid' });
  for (const tag of tags) {
    const card = createSelectCard(tag.name, getTasteIcon(tag.code), selected.has(tag.id));
    card.addEventListener('click', () => {
      if (selected.has(tag.id)) {
        selected.delete(tag.id);
      } else if (selected.size >= MAX_TASTE_SELECTION) {
        showToast(`최대 ${MAX_TASTE_SELECTION}개까지 선택할 수 있어요`);
        return;
      } else {
        selected.add(tag.id);
      }
      setCardSelected(card, selected.has(tag.id));
      onChange(selected);
    });
    grid.append(card);
  }
  return grid;
}
