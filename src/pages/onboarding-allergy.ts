import { getAllergens, type Allergen } from '../api/lookups';
import { saveOnboarding } from '../api/onboarding';
import { PATHS } from '../lib/constants';
import { createAllergenGrid } from '../utils/allergen-grid';
import { qs, showToast } from '../utils/dom';
import { enterStep } from '../utils/onboarding-flow';
import { clearState, updateState, type OnboardingState } from '../utils/onboarding-state';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';

const body = qs<HTMLElement>('#body');
const next = qs<HTMLButtonElement>('#next');

async function start(): Promise<void> {
  if (!body || !next) return;
  next.disabled = true;
  renderLoading(body);
  try {
    const state = await enterStep('allergy');
    if (!state) return;
    const allergens = await getAllergens();
    if (allergens.length === 0) {
      // 알레르기는 선택 사항이므로 목록이 비어도 완료할 수 있다
      renderEmpty(body, '선택할 수 있는 항목이 없어요', '이대로 선택완료를 눌러주세요');
      bindSubmit(state, new Set());
      return;
    }
    render(state, allergens);
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요', () => void start());
  }
}

function render(state: OnboardingState, allergens: Allergen[]): void {
  if (!body) return;
  // 뒤로가기로 돌아왔을 때 이전 선택을 채운다
  const selected = new Set(state.allergenIds.filter((id) => allergens.some((a) => a.id === id)));

  const grid = createAllergenGrid(allergens, selected, () => updateState({ allergenIds: Array.from(selected) }));
  body.replaceChildren(grid);
  bindSubmit(state, selected);
}

function bindSubmit(state: OnboardingState, selected: Set<number>): void {
  if (!next) return;
  next.disabled = false;
  next.addEventListener('click', async () => {
    if (next.disabled || !state.region) return;
    next.disabled = true;
    next.textContent = '저장 중...';
    try {
      await saveOnboarding({
        region: state.region,
        tastes: state.tasteIds.map((id) => ({ taste_tag_id: id, ratio: state.ratios[id] })),
        allergenIds: Array.from(selected),
      });
      clearState();
      window.location.replace(PATHS.home);
    } catch (e) {
      showToast(e instanceof Error ? e.message : '저장하지 못했어요. 잠시 후 다시 시도해주세요');
      next.disabled = false;
      next.textContent = '선택완료';
    }
  });
}

void start();
