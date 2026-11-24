import { signUp } from '../api/auth';
import { updateMyNickname } from '../api/me';
import { PATHS } from '../lib/constants';
import { bindAuthForm } from '../utils/auth-form';
import { redirectIfAuthed } from '../utils/auth-guard';

void redirectIfAuthed();

bindAuthForm(
  async (username, password, nickname) => {
    // 이메일 인증이 꺼져 있어 가입 즉시 로그인 상태가 된다
    await signUp(username, password);
    // 가입은 끝났으므로 닉네임 저장이 실패해도 막지 않는다 (그때는 아이디가 닉네임으로 남고, 프로필 수정에서 바꿀 수 있다)
    if (nickname) await updateMyNickname(nickname).catch(() => undefined);
    window.location.replace(PATHS.onboardingStart);
  },
  '회원가입',
  '가입 중...',
);
