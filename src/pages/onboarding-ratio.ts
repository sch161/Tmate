import { getTasteTags } from '../api/lookups';
import { PATHS } from '../lib/constants';
import { qs } from '../utils/dom';
import { enterStep } from '../utils/onboarding-flow';
import { hasValidRatios, updateState } from '../utils/onboarding-state';
import { equalSplit } from '../utils/ratio';
import { createRatioSliders } from '../utils/ratio-sliders';
import { renderError, renderLoading } from '../utils/state-views';

const body = qs<HTMLElement>('#body');
const next = qs<HTMLButtonElement>('#next');

async function start(): Promise<void> {
  if (!body || !next) return;
  renderLoading(body);
  try {
    const state = await enterStep('ratio');
    if (!state) return;

    // 맛이 1개면 이 화면을 건너뛴다 (뒤로가기로 와도 history 에 남지 않도록 replace)
    if (state.tasteIds.length === 1) {
      updateState({ ratios: { [state.tasteIds[0]]: 100 } });
      window.location.replace(PATHS.onboardingAllergy);
      return;
    }

    const tags = await getTasteTags();
    const items = state.tasteIds
      .map((id) => tags.find((t) => t.id === id))
      .filter((t): t is { id: number; code: string; name: string } => Boolean(t));
    if (items.length !== state.tasteIds.length) {
      // 선택했던 맛이 목록에서 사라졌다면 맛 선택부터 다시 한다
      window.location.replace(PATHS.onboardingFlavor);
      return;
    }
    render(items, state.ratios);
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요', () => void start());
  }
}

function render(items: { id: number; name: string }[], savedRatios: Record<number, number>): void {
  if (!body || !next) return;

  const saved = { tasteIds: items.map((i) => i.id), ratios: savedRatios, region: null, allergenIds: [] };
  let values = hasValidRatios(saved) ? items.map((i) => savedRatios[i.id]) : equalSplit(items.length);

  const persist = (current: number[]): void => {
    updateState({ ratios: Object.fromEntries(items.map((item, i) => [item.id, current[i]])) });
  };

  body.replaceChildren(createRatioSliders(items, values, (current) => {
    values = current;
    persist(current);
  }));
  next.disabled = false;

  next.addEventListener('click', () => {
    persist(values);
    window.location.href = PATHS.onboardingAllergy;
  });
}

void start();
