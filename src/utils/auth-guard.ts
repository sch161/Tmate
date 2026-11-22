import { getMyProfile, getSession } from '../api/auth';
import { PATHS } from '../lib/constants';

/** 세션이 없으면 로그인 화면으로 보낸다. 세션이 있으면 true. */
export async function requireAuth(): Promise<boolean> {
  try {
    if (await getSession()) return true;
  } catch {
    // 세션 확인 실패는 비로그인으로 취급한다
  }
  window.location.replace(PATHS.login);
  return false;
}

/** 세션이 있으면 온보딩 완료 여부에 따라 온보딩/홈으로 보낸다. 이동했으면 true. */
export async function redirectIfAuthed(): Promise<boolean> {
  try {
    if (!(await getSession())) return false;
    const profile = await getMyProfile();
    window.location.replace(profile?.onboarding_done ? PATHS.home : PATHS.onboardingStart);
    return true;
  } catch {
    return false;
  }
}
