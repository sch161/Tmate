import { getMyProfile } from '../api/auth';
import { PATHS } from '../lib/constants';
import { requireAuth } from './auth-guard';
import { hasValidRatios, loadState, type OnboardingState } from './onboarding-state';

export type OnboardingStep = 'location' | 'flavor' | 'ratio' | 'allergy';

/**
 * 온보딩 각 페이지의 진입 검사.
 * - 로그인 안 됨 → 로그인 / 이미 온보딩 완료 → 홈 / 이전 단계 값이 없음 → 첫 단계로 이동하고 null 을 돌려준다.
 * - 통과하면 현재 저장된 상태를 돌려준다. 프로필 조회 실패는 예외로 던진다.
 */
export async function enterStep(step: OnboardingStep): Promise<OnboardingState | null> {
  if (!(await requireAuth())) return null;

  const profile = await getMyProfile();
  if (profile?.onboarding_done) {
    window.location.replace(PATHS.home);
    return null;
  }

  const state = loadState();
  const missing =
    (step !== 'location' && !state.region) ||
    ((step === 'ratio' || step === 'allergy') && state.tasteIds.length === 0) ||
    (step === 'allergy' && !hasValidRatios(state));
  if (missing) {
    window.location.replace(PATHS.onboardingStart);
    return null;
  }
  return state;
}
