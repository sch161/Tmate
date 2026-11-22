import { PASSWORD_MIN_LENGTH, USERNAME_PATTERN } from '../lib/constants';
import { qs } from './dom';

/** 아이디 형식 검증. 문제가 없으면 null, 있으면 한국어 메시지. */
export function validateUsername(username: string): string | null {
  if (!username) return '아이디를 입력해주세요';
  if (!USERNAME_PATTERN.test(username)) return '아이디는 영문 소문자·숫자·밑줄 4~20자로 입력해주세요';
  return null;
}

/** 비밀번호 길이 검증. */
export function validatePassword(password: string): string | null {
  if (!password) return '비밀번호를 입력해주세요';
  if (password.length < PASSWORD_MIN_LENGTH) return `비밀번호는 ${PASSWORD_MIN_LENGTH}자 이상 입력해주세요`;
  return null;
}

function setFieldError(input: HTMLInputElement, errorEl: HTMLElement, message: string | null): void {
  errorEl.textContent = message ?? '';
  errorEl.hidden = !message;
  input.classList.toggle('is-error', Boolean(message));
  input.setAttribute('aria-invalid', message ? 'true' : 'false');
}

/**
 * 로그인/회원가입 폼 공통 동작: 검증 → 제출 중 버튼 비활성 → 서버 에러 표시.
 * submit 이 성공하면 이동은 호출한 쪽(onSubmit)에서 한다.
 */
export function bindAuthForm(
  onSubmit: (username: string, password: string) => Promise<void>,
  idleLabel: string,
  busyLabel: string,
): void {
  const form = qs<HTMLFormElement>('#auth-form');
  const username = qs<HTMLInputElement>('#username');
  const password = qs<HTMLInputElement>('#password');
  const usernameError = qs<HTMLElement>('#username-error');
  const passwordError = qs<HTMLElement>('#password-error');
  const formError = qs<HTMLElement>('#form-error');
  const submit = qs<HTMLButtonElement>('#submit');
  if (!form || !username || !password || !usernameError || !passwordError || !formError || !submit) return;

  const showFormError = (message: string | null): void => {
    formError.textContent = message ?? '';
    formError.hidden = !message;
  };

  username.addEventListener('input', () => setFieldError(username, usernameError, null));
  password.addEventListener('input', () => setFieldError(password, passwordError, null));

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (submit.disabled) return;
    showFormError(null);

    const name = username.value.trim();
    const nameMsg = validateUsername(name);
    const pwMsg = validatePassword(password.value);
    setFieldError(username, usernameError, nameMsg);
    setFieldError(password, passwordError, pwMsg);
    if (nameMsg || pwMsg) return;

    submit.disabled = true;
    submit.textContent = busyLabel;
    try {
      await onSubmit(name, password.value);
    } catch (e) {
      showFormError(e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요');
      submit.disabled = false;
      submit.textContent = idleLabel;
    }
  });
}
