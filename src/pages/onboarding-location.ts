import { PATHS } from '../lib/constants';
import { qs } from '../utils/dom';
import { enterStep } from '../utils/onboarding-flow';
import { updateState } from '../utils/onboarding-state';
import { pickRegion } from '../utils/region-picker';

// 위치 권한은 받지 않는다 (구 단위 필터라 좌표가 필요 없음). "허용하기" → 지역 선택 시트.
async function start(): Promise<void> {
  const next = qs<HTMLButtonElement>('#next');
  const regionText = qs<HTMLElement>('#region-text');
  if (!next || !regionText) return;
  next.disabled = true;

  let state;
  try {
    state = await enterStep('location');
  } catch (e) {
    regionText.textContent = e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요';
    regionText.hidden = false;
    regionText.classList.add('error-message');
    next.disabled = false;
    next.addEventListener('click', () => window.location.reload());
    next.textContent = '다시 시도';
    return;
  }
  if (!state) return;

  let region = state.region;
  const showRegion = (): void => {
    regionText.textContent = region ? `선택한 지역: ${region}` : '';
    regionText.hidden = !region;
  };
  showRegion();
  next.disabled = false;

  next.addEventListener('click', async () => {
    next.disabled = true;
    const picked = await pickRegion({ current: region });
    next.disabled = false;
    if (!picked) return;
    region = picked;
    showRegion();
    const saved = updateState({ region: picked });
    // 지역 선택이 곧 다음 단계로 가는 동작이다
    if (saved.region === picked) window.location.href = PATHS.onboardingFlavor;
  });
}

void start();
