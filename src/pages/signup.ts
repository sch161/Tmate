// 닉네임으로 시작하기 (회원가입을 대신한다). 아이디·비밀번호는 받지 않고 무작위 계정을 만들어 이 기기에 로그인해 둔다.
// 디자인 대기: 화면 나오면 교체 (Figma 의 User-Signup 1:884 는 아이디·비밀번호 가입 화면이다)
import { startAsGuest } from '../api/auth';
import { updateMyNickname, validateNickname } from '../api/me';
import { PATHS } from '../lib/constants';
import { redirectIfAuthed } from '../utils/auth-guard';
import { qs } from '../utils/dom';

void redirectIfAuthed();

const form = qs<HTMLFormElement>('#auth-form');
const nickname = qs<HTMLInputElement>('#nickname');
const nicknameError = qs<HTMLElement>('#nickname-error');
const formError = qs<HTMLElement>('#form-error');
const submit = qs<HTMLButtonElement>('#submit');

function showNicknameError(message: string | null): void {
  if (!nickname || !nicknameError) return;
  nicknameError.textContent = message ?? '';
  nicknameError.hidden = !message;
  nickname.classList.toggle('is-error', Boolean(message));
  nickname.setAttribute('aria-invalid', message ? 'true' : 'false');
}

function showFormError(message: string | null): void {
  if (!formError) return;
  formError.textContent = message ?? '';
  formError.hidden = !message;
}

nickname?.addEventListener('input', () => showNicknameError(null));

form?.addEventListener('submit', (event) => {
  event.preventDefault();
  if (!nickname || !submit || submit.disabled) return;
  showFormError(null);
  const invalid = validateNickname(nickname.value);
  showNicknameError(invalid);
  if (invalid) return;

  const name = nickname.value.trim();
  submit.disabled = true;
  submit.textContent = '시작하는 중...';
  void (async () => {
    try {
      // 이메일 인증이 꺼져 있어 가입 즉시 로그인 상태가 된다
      await startAsGuest();
      // 계정은 만들어졌으므로 닉네임 저장이 실패해도 막지 않는다 (프로필 수정에서 바꿀 수 있다)
      await updateMyNickname(name).catch(() => undefined);
      window.location.replace(PATHS.onboardingStart);
    } catch (e) {
      showFormError(e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요');
      submit.disabled = false;
      submit.textContent = '시작하기';
    }
  })();
});
