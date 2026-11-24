// 다른 폰으로 사진 보내기: PC 에서 검사한 손님이 결과 화면의 QR 을 폰으로 찍으면 열리는 화면. 로그인하지 않고 주소의 표(?t=)로 사진만 올린다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 이 화면이 없다)
import { getMatchPhotoTokenInfo, uploadMatchPhotoByToken } from '../api/match';
import { el, qs } from '../utils/dom';
import { createMascot } from '../utils/mascots';
import { fileToReceiptPhoto } from '../utils/match-photo';
import { renderError, renderLoading } from '../utils/state-views';

const body = qs<HTMLElement>('#body');
const token = new URLSearchParams(window.location.search).get('t') ?? '';
const message = (e: unknown, fallback: string): string => (e instanceof Error ? e.message : fallback);

function renderForm(info: { nicknameA: string; nicknameB: string; score: number }): void {
  if (!body) return;
  const input = el('input', { class: 'match-photo-page__input', type: 'file', accept: 'image/*', capture: 'user', 'aria-label': '사진 찍기' });
  const button = el('button', { class: 'btn-primary', type: 'button' }, '사진 찍기');
  const status = el('p', { class: 'match-photo-page__status text-wrap-ko', role: 'status' }, '둘이 같이 사진을 찍으면 부스에서 영수증으로 뽑아드려요');
  // 얼굴이 나오는 사진이라 랭킹 화면에 띄우는 것은 손님이 고른 경우에만 한다 (기본은 꺼짐)
  const consent = el('input', { type: 'checkbox', id: 'consent' });
  const consentLabel = el('label', { class: 'match-photo-page__consent text-wrap-ko', for: 'consent' }, consent, '부스 랭킹 화면에 우리 사진 띄우기');
  let busy = false;

  button.addEventListener('click', () => input.click());
  input.addEventListener('change', () => {
    const file = input.files?.[0];
    input.value = '';
    if (!file || busy) return;
    busy = true;
    button.disabled = true;
    button.textContent = '사진 올리는 중...';
    void (async () => {
      try {
        await uploadMatchPhotoByToken(token, await fileToReceiptPhoto(file), consent.checked);
        status.textContent = '사진을 보냈어요! 부스에서 영수증을 받아가세요';
        button.textContent = '사진 다시 찍기';
      } catch (e) {
        status.textContent = message(e, '사진을 올리지 못했어요. 다시 시도해주세요');
        button.textContent = '사진 찍기';
      }
      busy = false;
      button.disabled = false;
    })();
  });

  body.replaceChildren(
    el('section', { class: 'match-photo-page__pair' }, createMascot('heart', 'lg'), el('p', { class: 'match-photo-page__names text-wrap-ko' }, `${info.nicknameA} ♥ ${info.nicknameB}`), el('p', { class: 'match-photo-page__score' }, `${info.score}%`)),
    consentLabel,
    button,
    input,
    status,
  );
}

async function load(): Promise<void> {
  if (!body) return;
  if (!/^[0-9a-f-]{36}$/i.test(token)) {
    renderError(body, 'QR 코드를 다시 찍어주세요', () => window.location.reload());
    return;
  }
  renderLoading(body);
  try {
    const info = await getMatchPhotoTokenInfo(token);
    if (!info) {
      renderError(body, '결과를 찾지 못했어요. QR 코드를 다시 띄워주세요', () => void load());
      return;
    }
    renderForm(info);
  } catch (e) {
    renderError(body, message(e, 'QR 코드를 확인하지 못했어요'), () => void load());
  }
}

void load();
