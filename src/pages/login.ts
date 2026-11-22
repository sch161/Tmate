import { getMyProfile, signIn } from '../api/auth';
import { PATHS } from '../lib/constants';
import { bindAuthForm } from '../utils/auth-form';
import { redirectIfAuthed } from '../utils/auth-guard';

void redirectIfAuthed();

bindAuthForm(
  async (username, password) => {
    await signIn(username, password);
    const profile = await getMyProfile();
    window.location.replace(profile?.onboarding_done ? PATHS.home : PATHS.onboardingStart);
  },
  '로그인',
  '로그인 중...',
);
