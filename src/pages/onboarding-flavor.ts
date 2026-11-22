import { getTasteTags } from '../api/lookups';
import { MAX_TASTE_SELECTION, PATHS } from '../lib/constants';
import { el, qs, showToast } from '../utils/dom';
import { enterStep } from '../utils/onboarding-flow';
import { updateState } from '../utils/onboarding-state';
import { createSelectCard, setCardSelected } from '../utils/select-card';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';
import { getTasteIcon } from '../utils/taste-icons';

const body = qs<HTMLElement>('#body');
const next = qs<HTMLButtonElement>('#next');

async function start(): Promise<void> {
  if (!body || !next) return;
  renderLoading(body);
  try {
    const state = await enterStep('flavor');
    if (!state) return;
    const tags = await getTasteTags();
    if (tags.length === 0) {
      renderEmpty(body, '선택할 수 있는 맛이 없어요', '잠시 후 다시 시도해주세요');
      return;
    }
    render(tags, state.tasteIds, state.ratios);
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요', () => void start());
  }
}

function render(
  tags: { id: number; code: string; name: string }[],
  savedIds: number[],
  savedRatios: Record<number, number>,
): void {
  if (!body || !next) return;
  // 뒤로가기로 돌아왔을 때 이전 선택을 채운다 (목록에 없는 id 는 버린다)
  const selected = new Set(savedIds.filter((id) => tags.some((t) => t.id === id)));

  const grid = el('div', { class: 'select-grid' });
  const cards = new Map<number, HTMLButtonElement>();
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
      next!.disabled = selected.size === 0;
    });
    cards.set(tag.id, card);
    grid.append(card);
  }
  body.replaceChildren(grid);
  next.disabled = selected.size === 0;

  next.addEventListener('click', () => {
    if (selected.size === 0) return;
    // 태그 목록 순서로 정렬해 저장한다
    const tasteIds = tags.filter((t) => selected.has(t.id)).map((t) => t.id);
    const same = tasteIds.length === savedIds.length && tasteIds.every((id) => savedIds.includes(id));
    if (tasteIds.length === 1) {
      // 맛이 1개면 100% 로 정하고 비율 화면을 건너뛴다
      updateState({ tasteIds, ratios: { [tasteIds[0]]: 100 } });
      window.location.href = PATHS.onboardingAllergy;
      return;
    }
    // 선택이 바뀌었으면 이전 비율은 버린다
    updateState({ tasteIds, ratios: same ? savedRatios : {} });
    window.location.href = PATHS.onboardingRatio;
  });
}

void start();
