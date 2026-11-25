// 프로필 수정: 닉네임만 바꾼다(아이디는 읽기 전용, 프로필 사진은 없다).
// 디자인 대기: 화면 나오면 교체 (Figma 에 프로필 수정 화면이 없다)
import { getMyProfile, type MyProfile } from '../api/auth';
import { isGuestUsername } from '../lib/constants';
import { NICKNAME_MAX_LENGTH, updateMyNickname, validateNickname } from '../api/me';
import { requireAuth } from '../utils/auth-guard';
import { el, qs, showToast } from '../utils/dom';
import { goAfterSave, goBack } from '../utils/navigation';
import { renderError, renderLoading } from '../utils/state-views';

const LEAVE_DELAY_MS = 700;

const body = qs<HTMLElement>('#body');
const backButton = qs<HTMLButtonElement>('#back');

function leave(): void {
  goBack();
}

function renderForm(profile: MyProfile): void {
  if (!body) return;
  const initial = profile.nickname.trim();
  let busy = false;
  // 저장 실패 메시지. 입력을 다시 바꾸면 지운다
  let serverError = '';

  const username = el('input', { class: 'input profile-edit__readonly', id: 'username', type: 'text', value: profile.username, readonly: true, 'aria-readonly': 'true' });
  const nickname = el('input', { class: 'input', id: 'nickname', type: 'text', value: profile.nickname, maxlength: String(NICKNAME_MAX_LENGTH), autocomplete: 'off', placeholder: '닉네임을 입력해주세요' });
  const error = el('p', { class: 'error-message', id: 'nickname-error', role: 'alert' });
  error.hidden = true;
  const save = el('button', { class: 'btn-primary', id: 'save', type: 'button', disabled: true }, '저장하기');

  const sync = (): void => {
    const value = nickname.value;
    const invalid = validateNickname(value);
    // 입력을 건드린 뒤에만 검증 오류를 보여주고, 변경이 없거나 올바르지 않으면 저장할 수 없다
    const touched = value.trim() !== initial;
    const message = serverError || (touched && invalid ? invalid : '');
    error.textContent = message;
    error.hidden = message === '';
    nickname.classList.toggle('is-error', message !== '');
    save.disabled = busy || invalid !== null || value.trim() === initial;
  };
  nickname.addEventListener('input', () => {
    serverError = '';
    sync();
  });

  const submit = async (): Promise<void> => {
    if (busy || save.disabled) return;
    busy = true;
    serverError = '';
    save.textContent = '저장 중...';
    sync();
    try {
      await updateMyNickname(nickname.value);
      showToast('프로필을 바꿨어요');
      window.setTimeout(goAfterSave, LEAVE_DELAY_MS);
    } catch (e) {
      serverError = e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요';
      busy = false;
      save.textContent = '저장하기';
      sync();
    }
  };
  save.addEventListener('click', () => void submit());
  nickname.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') void submit();
  });

  body.replaceChildren(
    el(
      'div',
      { class: 'profile-edit__form' },
      // 닉네임만으로 시작한 계정의 아이디는 무작위 글자라 보여주지 않는다
      ...(isGuestUsername(profile.username) ? [] : [el('div', { class: 'profile-edit__field' }, el('label', { class: 'profile-edit__label', for: 'username' }, '아이디'), username, el('p', { class: 'profile-edit__hint text-wrap-ko' }, '아이디는 바꿀 수 없어요'))]),
      el('div', { class: 'profile-edit__field' }, el('label', { class: 'profile-edit__label', for: 'nickname' }, '닉네임'), nickname, el('p', { class: 'profile-edit__hint text-wrap-ko' }, `앞뒤 공백을 뺀 1~${NICKNAME_MAX_LENGTH}자로 입력해주세요`), error),
      save,
    ),
  );
  sync();
}

async function load(): Promise<void> {
  if (!body) return;
  renderLoading(body);
  try {
    const profile = await getMyProfile();
    if (!profile) {
      renderError(body, '내 정보를 찾지 못했어요', () => void load());
      return;
    }
    renderForm(profile);
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '내 정보를 불러오지 못했어요', () => void load());
  }
}

async function start(): Promise<void> {
  backButton?.addEventListener('click', leave);
  if (!(await requireAuth())) return;
  await load();
}

void start();
