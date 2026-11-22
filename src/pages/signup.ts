import { signUp } from '../api/auth';
import { PATHS } from '../lib/constants';
import { bindAuthForm } from '../utils/auth-form';
import { redirectIfAuthed } from '../utils/auth-guard';

void redirectIfAuthed();

bindAuthForm(
  async (username, password) => {
    // 이메일 인증이 꺼져 있어 가입 즉시 로그인 상태가 된다
    await signUp(username, password);
    window.location.replace(PATHS.onboardingStart);
  },
  '회원가입',
  '가입 중...',
);
