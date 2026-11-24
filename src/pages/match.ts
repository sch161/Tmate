// 친구랑 궁합 검사: 방 만들기/들어가기 → 검사(PART 1 둘 중 하나 10문항 + PART 2 음식 5개) → 방 사람들과의 궁합.
// 디자인 대기: 화면 나오면 교체 (Figma 에 이 화면이 없다)
import {
  createMatchRoom,
  getMatchCompare,
  getMatchFoods,
  getMatchQuestions,
  getMatchRoom,
  getMyMatchRoom,
  joinMatchRoom,
  saveMatchTest,
  type MatchChoiceAnswer,
  type MatchFood,
  type MatchFoodAnswer,
  type MatchMember,
  type MatchQuestion,
  requestMatchPrint,
  getMatchPairChoices,
  createMatchPhotoToken,
  getMatchPairPlaces,
} from '../api/match';
import { getMyTastes } from '../api/me';
import starIcon from '../assets/icons/star.svg';
import { PATHS } from '../lib/constants';
import { requireAuth } from '../utils/auth-guard';
import { el, qs, showToast } from '../utils/dom';
import { createMascot, type MascotName } from '../utils/mascots';
import { getMatchFoodImage } from '../utils/match-food-images';
import { dataUrlToCanvas, fileToReceiptPhoto } from '../utils/match-photo';
import { RECEIPT_MAX_CARDS, renderMatchReceipt, type ReceiptInput } from '../utils/match-receipt';
import { monoToRgba } from '../utils/mxw01-protocol';
import { createQrSvg } from '../utils/qr';
import { buildChoiceSummary, buildResultCards, getMatchTier, type ChoiceSummary } from '../utils/match-results';
import { renderError, renderLoading } from '../utils/state-views';

const ROOM_PARAM = 'room';
const POLL_MS = 4000; // 방 화면에서 친구의 입장·완료를 다시 확인하는 간격

const body = qs<HTMLElement>('#body');
const backButton = qs<HTMLButtonElement>('#back');

let pollTimer: number | undefined;
let onBack: () => void = leave;

function leave(): void {
  window.location.href = PATHS.home;
}

function stopPolling(): void {
  if (pollTimer !== undefined) window.clearInterval(pollTimer);
  pollTimer = undefined;
}

function setRoomInUrl(code: string | null): void {
  const url = new URL(window.location.href);
  if (code) url.searchParams.set(ROOM_PARAM, code);
  else url.searchParams.delete(ROOM_PARAM);
  window.history.replaceState(null, '', url);
}

const message = (e: unknown, fallback: string): string => (e instanceof Error ? e.message : fallback);

function heading(title: string, desc?: string, mascot?: MascotName): HTMLElement {
  const head = el('header', { class: 'match__head' });
  if (mascot) head.append(createMascot(mascot, 'lg'));
  head.append(el('h1', { class: 'match__title' }, title));
  if (desc) head.append(el('p', { class: 'match__desc text-wrap-ko' }, desc));
  return head;
}

// ---------- 1. 시작: 방 만들기 / 방 번호로 들어가기 ----------

async function showStart(): Promise<void> {
  if (!body) return;
  stopPolling();
  onBack = leave;
  setRoomInUrl(null);

  const createButton = el('button', { class: 'btn-primary', type: 'button' }, '방 만들기');
  const input = el('input', { class: 'input match__code-input', type: 'text', inputmode: 'numeric', maxlength: '4', placeholder: '방 번호 4자리', 'aria-label': '방 번호 4자리', autocomplete: 'off' });
  const joinButton = el('button', { class: 'btn-primary', type: 'submit', disabled: true }, '방 들어가기');
  const form = el('form', { class: 'match__join' }, input, joinButton);
  const recent = el('div', { class: 'match__recent' });

  let busy = false;
  const sync = (): void => {
    input.value = input.value.replace(/\D/g, '').slice(0, 4);
    createButton.disabled = busy;
    joinButton.disabled = busy || input.value.length !== 4;
  };
  input.addEventListener('input', sync);

  const run = async (action: () => Promise<string>): Promise<void> => {
    if (busy) return;
    busy = true;
    sync();
    try {
      await showRoom(await action());
    } catch (e) {
      showToast(message(e, '문제가 발생했어요. 잠시 후 다시 시도해주세요'));
      busy = false;
      sync();
    }
  };
  createButton.addEventListener('click', () => void run(() => createMatchRoom()));
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    const code = input.value;
    void run(async () => {
      await joinMatchRoom(code);
      return code;
    });
  });

  body.replaceChildren(
    heading('친구랑 궁합 검사', '같이 온 친구와 같은 방에 들어가서 검사하면 둘의 맛궁합을 알려드려요', 'search'),
    el('section', { class: 'match__card' }, el('h2', { class: 'match__card-title' }, '내가 방을 만들게요'), el('p', { class: 'match__card-desc' }, '방 번호가 나오면 친구에게 알려주세요'), createButton),
    el('section', { class: 'match__card' }, el('h2', { class: 'match__card-title' }, '친구가 방을 만들었어요'), form),
    recent,
  );

  // 최근 방 안내는 편의 기능이라 못 불러와도 화면은 그대로 쓴다
  const code = await getMyMatchRoom().catch(() => null);
  if (code) {
    const link = el('button', { class: 'match__link', type: 'button' }, `최근에 들어간 방(${code})으로 돌아가기`);
    link.addEventListener('click', () => void showRoom(code));
    recent.replaceChildren(link);
  }
}

// ---------- 2. 방: 멤버 상태와 궁합 ----------

function memberRow(code: string, member: MatchMember, meCompleted: boolean): HTMLElement {
  const name = el('p', { class: 'match-member__name' }, member.isMe ? `${member.nickname} (나)` : member.nickname);
  if (member.isMe) return el('li', { class: 'match-member' }, name, el('p', { class: 'match-member__state' }, member.completed ? '검사 완료' : '검사 전'));
  if (!member.completed) return el('li', { class: 'match-member' }, name, el('p', { class: 'match-member__state' }, '검사 중...'));
  if (!meCompleted || member.score === null) return el('li', { class: 'match-member' }, name, el('p', { class: 'match-member__state' }, '검사 완료'));

  const row = el(
    'button',
    { class: 'match-member match-member--result', type: 'button' },
    el('span', { class: 'match-member__text' }, name, el('span', { class: 'match-member__tier' }, getMatchTier(member.score).title)),
    el('span', { class: 'match-member__score' }, `${member.score}%`),
  );
  row.addEventListener('click', () => void showDetail(code, member));
  return el('li', {}, row);
}

async function showRoom(code: string): Promise<void> {
  if (!body) return;
  stopPolling();
  onBack = () => void showStart();
  setRoomInUrl(code);
  renderLoading(body);

  const list = el('ul', { class: 'match__members' });
  const action = el('div', { class: 'match__actions' });
  let lastKey = '';

  const paint = (members: MatchMember[]): void => {
    // 바뀐 것이 없으면 다시 그리지 않는다 (4초마다 깜빡이지 않게)
    const key = JSON.stringify(members);
    if (key === lastKey) return;
    lastKey = key;
    const me = members.find((m) => m.isMe);
    const meCompleted = Boolean(me?.completed);
    list.replaceChildren(...members.map((m) => memberRow(code, m, meCompleted)));

    if (!meCompleted) {
      const testButton = el('button', { class: 'btn-primary', type: 'button' }, '검사 시작하기');
      testButton.addEventListener('click', () => void showTest(code));
      action.replaceChildren(testButton);
      return;
    }
    const others = members.filter((m) => !m.isMe);
    const hint = others.length === 0 ? '친구가 방에 들어오면 궁합을 볼 수 있어요' : others.some((m) => m.completed) ? '친구를 누르면 자세한 결과를 볼 수 있어요' : '친구가 검사를 마치면 궁합이 나타나요';
    const editButton = el('button', { class: 'match__link', type: 'button' }, '내 답 고치기');
    editButton.addEventListener('click', () => void showTest(code));
    // 다시 검사하면 새 방이 만들어지고 다른 음식이 나온다 (친구도 새 방 번호로 들어와야 한다)
    const againButton = el('button', { class: 'match__link', type: 'button' }, '새 방에서 다시 검사하기');
    againButton.addEventListener('click', () => {
      againButton.disabled = true;
      createMatchRoom()
        .then((newCode) => showRoom(newCode))
        .catch((e: unknown) => {
          showToast(message(e, '방을 만들지 못했어요'));
          againButton.disabled = false;
        });
    });
    action.replaceChildren(el('p', { class: 'match__hint text-wrap-ko' }, hint), editButton, againButton);
  };

  try {
    paint(await getMatchRoom(code));
  } catch (e) {
    renderError(body, message(e, '방 정보를 불러오지 못했어요'), () => void showRoom(code));
    return;
  }

  body.replaceChildren(
    heading('친구랑 궁합 검사'),
    el('section', { class: 'match__code-box' }, el('p', { class: 'match__code-label' }, '방 번호'), el('p', { class: 'match__code', 'aria-live': 'polite' }, code), el('p', { class: 'match__code-desc' }, '친구에게 이 번호를 알려주세요')),
    list,
    action,
  );
  pollTimer = window.setInterval(() => {
    // 일시적인 조회 실패는 다음 주기에 다시 시도한다
    getMatchRoom(code).then(paint).catch(() => undefined);
  }, POLL_MS);
}

// ---------- 3. 검사 ----------

type Step = { kind: 'question'; question: MatchQuestion } | { kind: 'food'; food: MatchFood };

interface FoodDraft {
  eaten: boolean | null;
  rating: number | null;
  wantTry: boolean | null;
}

function optionButton(label: string, selected: boolean, onClick: () => void): HTMLButtonElement {
  const button = el('button', { class: selected ? 'match-option is-selected' : 'match-option', type: 'button', 'aria-pressed': String(selected) }, label);
  button.addEventListener('click', onClick);
  return button;
}

/** 음식 사진과 출처 표시(작가·라이선스, 원본 페이지 링크). 사진이 없는 음식이면 빈 배열 */
function foodPhoto(foodName: string): HTMLElement[] {
  const image = getMatchFoodImage(foodName);
  if (!image) return [];
  // 음식 이름이 바로 아래에 글자로 나오므로 사진의 alt 는 비운다
  const photo = el('img', { class: 'match-step__photo', src: image.src, alt: '', width: '480', height: '480' });
  const credit = el('a', { class: 'match-step__credit', href: image.sourceUrl, target: '_blank', rel: 'noopener noreferrer' }, `사진: ${image.artist} · ${image.license}`);
  return [el('figure', { class: 'match-step__figure' }, photo, el('figcaption', {}, credit))];
}

async function showTest(code: string): Promise<void> {
  if (!body) return;
  stopPolling();
  onBack = () => void showRoom(code);
  renderLoading(body);

  let questions: MatchQuestion[];
  let foods: MatchFood[];
  try {
    [questions, foods] = await Promise.all([getMatchQuestions(code), getMatchFoods(code)]);
  } catch (e) {
    renderError(body, message(e, '검사를 불러오지 못했어요'), () => void showTest(code));
    return;
  }

  const steps: Step[] = [...questions.map((question): Step => ({ kind: 'question', question })), ...foods.map((food): Step => ({ kind: 'food', food }))];
  if (steps.length === 0) {
    renderError(body, '검사 문항이 아직 준비되지 않았어요', () => void showTest(code));
    return;
  }
  const choices = new Map<number, 1 | 2>(questions.filter((q) => q.myChoice !== null).map((q) => [q.questionId, q.myChoice as 1 | 2]));
  const drafts = new Map<number, FoodDraft>(foods.map((f) => [f.foodId, { eaten: f.myEaten, rating: f.myRating, wantTry: f.myWantTry }]));
  let index = 0;
  let busy = false;

  const answered = (step: Step): boolean => {
    if (step.kind === 'question') return choices.has(step.question.questionId);
    const d = drafts.get(step.food.foodId);
    return Boolean(d && ((d.eaten === true && d.rating !== null) || (d.eaten === false && d.wantTry !== null)));
  };

  const submit = async (): Promise<void> => {
    if (busy) return;
    busy = true;
    render();
    const choiceAnswers: MatchChoiceAnswer[] = questions.map((q) => ({ questionId: q.questionId, choice: choices.get(q.questionId) ?? 1 }));
    const foodAnswers: MatchFoodAnswer[] = foods.map((f) => {
      const d = drafts.get(f.foodId);
      return d?.eaten ? { foodId: f.foodId, eaten: true, rating: d.rating ?? 1 } : { foodId: f.foodId, eaten: false, wantTry: Boolean(d?.wantTry) };
    });
    try {
      await saveMatchTest(code, choiceAnswers, foodAnswers);
      await showRoom(code);
    } catch (e) {
      showToast(message(e, '검사 결과를 저장하지 못했어요'));
      busy = false;
      render();
    }
  };

  const go = (next: number): void => {
    index = Math.min(Math.max(next, 0), steps.length - 1);
    render();
  };

  function render(): void {
    if (!body) return;
    const step = steps[index];
    const isLast = index === steps.length - 1;
    const content = el('section', { class: 'match-step' });

    if (step.kind === 'question') {
      const q = step.question;
      const pick = (choice: 1 | 2): void => {
        choices.set(q.questionId, choice);
        // 고르면 바로 다음 문항으로 넘어간다 (마지막 단계에서는 머문다)
        if (isLast) render();
        else go(index + 1);
      };
      content.append(
        createMascot('thinking', 'sm'),
        el('p', { class: 'match-step__part' }, '맛궁합 검사'),
        el('h2', { class: 'match-step__body text-wrap-ko' }, q.body),
        el('div', { class: 'match-step__options' }, optionButton(q.optionA, choices.get(q.questionId) === 1, () => pick(1)), optionButton(q.optionB, choices.get(q.questionId) === 2, () => pick(2))),
      );
    } else {
      const f = step.food;
      const d = drafts.get(f.foodId) ?? { eaten: null, rating: null, wantTry: null };
      const update = (patch: Partial<FoodDraft>): void => {
        drafts.set(f.foodId, { ...d, ...patch });
        render();
      };
      content.append(
        el('p', { class: 'match-step__part' }, '입맛 탐구 생활'),
        ...foodPhoto(f.name),
        el('h2', { class: 'match-step__food' }, f.name),
        el('p', { class: 'match-step__ask' }, '이 음식을 먹어본 적 있나요?'),
        el(
          'div',
          { class: 'match-step__options' },
          optionButton('네, 먹어봤어요!', d.eaten === true, () => update({ eaten: true, wantTry: null })),
          optionButton('아직 안 먹어봤어요', d.eaten === false, () => update({ eaten: false, rating: null })),
        ),
      );
      if (d.eaten === true) {
        const stars = el('div', { class: 'match-stars', role: 'radiogroup', 'aria-label': '별점' });
        for (let n = 1; n <= 5; n += 1) {
          const on = d.rating !== null && n <= d.rating;
          const star = el('button', { class: on ? 'match-stars__star is-on' : 'match-stars__star', type: 'button', role: 'radio', 'aria-checked': String(d.rating === n), 'aria-label': `${n}점` }, el('img', { src: starIcon, alt: '', 'aria-hidden': 'true' }));
          star.addEventListener('click', () => update({ rating: n }));
          stars.append(star);
        }
        content.append(el('p', { class: 'match-step__ask' }, '맛은 어땠나요?'), stars);
      } else if (d.eaten === false) {
        content.append(
          el('p', { class: 'match-step__ask' }, '먹어보고 싶나요?'),
          el('div', { class: 'match-step__options' }, optionButton('먹어보고 싶어요', d.wantTry === true, () => update({ wantTry: true })), optionButton('별로 안 당겨요', d.wantTry === false, () => update({ wantTry: false }))),
        );
      }
    }

    const prev = el('button', { class: 'match-nav__prev', type: 'button', disabled: index === 0 || busy }, '이전');
    prev.addEventListener('click', () => go(index - 1));
    const next = el('button', { class: 'btn-primary match-nav__next', type: 'button', disabled: !answered(step) || busy }, isLast ? (busy ? '저장 중...' : '결과 보기') : '다음');
    next.addEventListener('click', () => {
      if (!isLast) go(index + 1);
      else if (steps.every(answered)) void submit();
      else showToast('답하지 않은 문항이 있어요');
    });

    const progress = el('div', { class: 'progress', role: 'progressbar', 'aria-valuemin': '0', 'aria-valuemax': String(steps.length), 'aria-valuenow': String(index + 1) });
    progress.style.setProperty('--value', String(Math.round(((index + 1) / steps.length) * 100)));
    body.replaceChildren(el('div', { class: 'match-step__top' }, progress, el('p', { class: 'match-step__count' }, `${index + 1} / ${steps.length}`)), content, el('footer', { class: 'match-nav' }, prev, next));
  }

  // 이어서 할 때는 답하지 않은 첫 단계부터 보여준다
  const firstOpen = steps.findIndex((s) => !answered(s));
  index = firstOpen === -1 ? 0 : firstOpen;
  render();
}

// ---------- 4. 친구와의 자세한 결과 ----------

// 디자인 대기: 사진을 찍어 부스 프린터로 보내는 영역은 Figma 에 없는 임시 UI
/** 결과 화면의 "사진 찍고 영수증 뽑기": 폰 카메라로 찍은 사진을 올리면 부스의 인쇄 화면 대기 목록에 뜬다 */
function createPhotoPrint(code: string, onPhoto: (photo: string) => void): HTMLElement {
  const input = el('input', { class: 'match-photo__input', type: 'file', accept: 'image/*', capture: 'user', 'aria-label': '사진 찍기' });
  const button = el('button', { class: 'btn-primary', type: 'button' }, '사진 찍고 영수증 뽑기');
  const status = el('p', { class: 'match__hint text-wrap-ko', role: 'status' }, '둘이 같이 사진을 찍어 올리면 부스에서 영수증으로 뽑아드려요');
  // 얼굴이 나오는 사진이라 랭킹 화면에 띄우는 것은 손님이 고른 경우에만 한다 (기본은 꺼짐)
  const consent = el('input', { type: 'checkbox', id: 'match-photo-consent' });
  const consentLabel = el('label', { class: 'match-photo__consent text-wrap-ko', for: 'match-photo-consent' }, consent, '부스 랭킹 화면에 우리 사진 띄우기');
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
        const photo = await fileToReceiptPhoto(file);
        await requestMatchPrint(code, photo, consent.checked);
        onPhoto(photo);
        status.textContent = '사진을 보냈어요! 부스에서 영수증을 받아가세요';
        button.textContent = '사진 다시 찍기';
      } catch (e) {
        status.textContent = message(e, '사진을 올리지 못했어요. 다시 시도해주세요');
        button.textContent = '사진 찍고 영수증 뽑기';
      }
      busy = false;
      button.disabled = false;
    })();
  });
  // PC 로 검사한 손님: QR 을 띄워 폰으로 사진을 찍어 보내게 한다 (QR 주소의 표는 30분 동안 쓸 수 있다)
  const qrBox = el('div', { class: 'match-photo__qr' });
  qrBox.hidden = true;
  const qrButton = el('button', { class: 'match__link', type: 'button' }, '다른 폰으로 찍어 보내기 (QR)');
  const showQr = (): void => {
    qrButton.disabled = true;
    createMatchPhotoToken(code)
      .then((token) => {
        const url = `${window.location.origin}${PATHS.matchPhoto}?t=${token}`;
        const image = el('img', { class: 'match-photo__qr-image', src: `data:image/svg+xml;utf8,${encodeURIComponent(createQrSvg(url))}`, alt: '사진 보내기 화면으로 가는 QR 코드', width: '220', height: '220' });
        qrBox.replaceChildren(image, el('p', { class: 'match__hint text-wrap-ko' }, '폰 카메라로 이 QR 을 찍으면 사진 보내는 화면이 열려요 (30분 동안 쓸 수 있어요)'));
        qrBox.hidden = false;
        qrButton.textContent = 'QR 다시 만들기';
      })
      .catch((e: unknown) => showToast(message(e, 'QR 코드를 만들지 못했어요')))
      .finally(() => {
        qrButton.disabled = false;
      });
  };
  qrButton.addEventListener('click', showQr);
  // 마우스를 쓰는 화면(PC)에서는 QR 을 바로 띄운다. 폰에서는 눌렀을 때만 만든다
  if (window.matchMedia('(pointer: fine)').matches) showQr();
  return el('section', { class: 'match-photo' }, consentLabel, button, input, status, qrButton, qrBox);
}

// 디자인 대기: 둘이 같이 가볼 만한 곳은 Figma 에 없는 임시 UI
/** 결과 화면의 "둘이 같이 가볼 만한 곳". 곁들이는 정보라 못 불러오거나 없으면 아무것도 보여주지 않는다 */
function createPairPlaces(code: string, friend: MatchMember): HTMLElement {
  const section = el('section', { class: 'match-places' });
  section.hidden = true;
  getMatchPairPlaces(code, friend.memberNo)
    .then((places) => {
      if (places.length === 0) return;
      section.replaceChildren(
        el('h2', { class: 'match-places__title' }, '둘이 같이 가볼 만한 곳'),
        ...places.map((place) =>
          el(
            'a',
            { class: 'match-places__item', href: `${PATHS.restaurant}?id=${place.restaurantId}` },
            el('span', { class: 'match-places__text' }, el('span', { class: 'match-places__name text-wrap-ko' }, place.restaurantName), el('span', { class: 'match-places__meta' }, [place.categoryName, place.region].filter(Boolean).join(' · '))),
            // 둘 다 입맛 정보가 없으면(행사 손님) 일치도 대신 화살표만 보여준다
            el('span', { class: 'match-places__match' }, place.pairMatch > 0 ? `둘의 일치도 ${place.pairMatch}%` : '보러 가기'),
          ),
        ),
      );
      section.hidden = false;
    })
    .catch(() => undefined);
  return section;
}

/** 결과를 영수증 모양 이미지(PNG)로 만든다. 부스에서 뽑는 영수증과 같은 그림이다 */
async function buildResultImage(input: Omit<ReceiptInput, 'photo'>, photo: string | null): Promise<Blob> {
  const receipt = await renderMatchReceipt({ ...input, photo: photo ? await dataUrlToCanvas(photo) : null });
  const canvas = document.createElement('canvas');
  canvas.width = receipt.width;
  canvas.height = receipt.height;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('이미지를 만들지 못했어요');
  context.putImageData(new ImageData(new Uint8ClampedArray(monoToRgba(receipt.mono)), receipt.width, receipt.height), 0, 0);
  return new Promise((resolve, reject) => canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error('이미지를 만들지 못했어요'))), 'image/png'));
}

// 디자인 대기: 맛집 추천으로 넘어가는 버튼은 Figma 에 없는 임시 UI
/** 궁합 검사만 하고 나가지 않게 결과 화면에서 맛집 추천으로 이어 준다. 입맛을 아직 등록하지 않았으면 등록부터 한다 */
function createServiceLink(): HTMLElement {
  const link = el('a', { class: 'btn-primary', href: PATHS.home }, '내 입맛에 맞는 맛집 보러 가기');
  void getMyTastes()
    .then((tastes) => {
      if (tastes.length > 0) return;
      link.textContent = '내 입맛 등록하고 맛집 추천받기';
      link.setAttribute('href', PATHS.onboardingStart);
    })
    .catch(() => {
      // 못 불러오면 홈으로 보낸다 (홈이 입맛 등록 여부를 다시 확인한다)
    });
  return link;
}

// 디자인 대기: 결과 이미지 저장 버튼은 Figma 에 없는 임시 UI
/** "결과 이미지 저장": 공유 시트를 쓸 수 있으면(폰) 공유·저장, 아니면 파일로 내려받는다 */
function createImageSave(getInput: () => Omit<ReceiptInput, 'photo'>, getPhoto: () => string | null): HTMLElement {
  const button = el('button', { class: 'match__link', type: 'button' }, '결과 이미지 저장');
  button.addEventListener('click', () => {
    button.disabled = true;
    void (async () => {
      try {
        const blob = await buildResultImage(getInput(), getPhoto());
        const file = new File([blob], 'tmate-match.png', { type: 'image/png' });
        if (typeof navigator.canShare === 'function' && navigator.canShare({ files: [file] })) {
          await navigator.share({ files: [file], title: 'T:MATE 맛궁합 결과' });
        } else {
          const url = URL.createObjectURL(blob);
          const link = el('a', { href: url, download: 'tmate-match.png' });
          document.body.append(link);
          link.click();
          link.remove();
          window.setTimeout(() => URL.revokeObjectURL(url), 1000);
          showToast('이미지를 저장했어요');
        }
      } catch (e) {
        // 공유 시트를 닫은 것(AbortError)은 오류로 보지 않는다
        if (!(e instanceof DOMException && e.name === 'AbortError')) showToast(message(e, '이미지를 만들지 못했어요'));
      }
      button.disabled = false;
    })();
  });
  return button;
}

async function showDetail(code: string, friend: MatchMember): Promise<void> {
  if (!body || friend.score === null) return;
  stopPolling();
  onBack = () => void showRoom(code);
  renderLoading(body);

  const tier = getMatchTier(friend.score);
  const cardList = el('div', { class: 'match-result__cards' });
  const backToRoom = el('button', { class: 'match__link', type: 'button' }, '방으로 돌아가기');
  backToRoom.addEventListener('click', () => void showRoom(code));

  // 결과 이미지 저장에 쓰는 값 (아래에서 채운다)
  let myNickname = '나';
  let choiceSummary: ChoiceSummary | undefined;
  let imageCards: ReturnType<typeof buildResultCards> = [];
  let lastPhoto: string | null = null;

  try {
    const [compare, members] = await Promise.all([getMatchCompare(code, friend.memberNo), getMatchRoom(code)]);
    // 통한 취향·갈린 취향 (PART 1 문항). 못 불러와도 음식 카드는 보여준다
    const me = members.find((m) => m.isMe);
    if (me) {
      myNickname = me.nickname;
      const summary = await getMatchPairChoices(code, me.memberNo, friend.memberNo)
        .then(buildChoiceSummary)
        .catch(() => null);
      choiceSummary = summary ?? undefined;
      if (summary && summary.same.length > 0) {
        cardList.append(el('article', { class: 'match-result__card' }, el('p', { class: 'match-result__label' }, `둘이 통한 취향 ${summary.same.length}개`), el('p', { class: 'match-result__food text-wrap-ko' }, summary.same.join(' · '))));
      }
      if (summary && summary.diff.length > 0) {
        cardList.append(el('article', { class: 'match-result__card' }, el('p', { class: 'match-result__label' }, '여기서 갈렸어요'), ...summary.diff.map((pair) => el('p', { class: 'match-result__detail text-wrap-ko' }, `나 ${pair.a} · ${friend.nickname} ${pair.b}`))));
      }
    }
    const cards = buildResultCards(compare);
    imageCards = buildResultCards(compare, { me: myNickname, friend: friend.nickname }).slice(0, RECEIPT_MAX_CARDS);
    if (cards.length === 0) cardList.append(el('p', { class: 'match__hint text-wrap-ko' }, '이번 음식에서는 눈에 띄는 공통점이 없었어요. 새 방에서 다시 검사하면 다른 음식이 나와요'));
    for (const card of cards) {
      cardList.append(el('article', { class: 'match-result__card' }, el('p', { class: 'match-result__label' }, card.label), el('p', { class: 'match-result__food' }, card.foodName), el('p', { class: 'match-result__detail' }, card.detail)));
    }
  } catch (e) {
    renderError(body, message(e, '결과를 불러오지 못했어요'), () => void showDetail(code, friend));
    return;
  }

  body.replaceChildren(
    el(
      'section',
      { class: 'match-result' },
      createMascot(tier.mascot, 'lg'),
      el('p', { class: 'match-result__with' }, `${friend.nickname}님과의 맛궁합`),
      el('p', { class: 'match-result__score' }, `${friend.score}%`),
      el('h1', { class: 'match-result__title text-wrap-ko' }, tier.title),
      el('p', { class: 'match-result__desc text-wrap-ko' }, tier.desc),
    ),
    cardList,
    createPairPlaces(code, friend),
    createPhotoPrint(code, (photo) => {
      lastPhoto = photo;
    }),
    el(
      'div',
      { class: 'match__actions' },
      createServiceLink(),
      createImageSave(
        () => ({ nicknameA: myNickname, nicknameB: friend.nickname, score: friend.score ?? 0, cards: imageCards, choices: choiceSummary, date: new Date() }),
        () => lastPhoto,
      ),
      backToRoom,
    ),
  );
}

async function start(): Promise<void> {
  backButton?.addEventListener('click', () => onBack());
  if (!(await requireAuth())) return;
  const code = new URL(window.location.href).searchParams.get(ROOM_PARAM);
  if (code && /^[0-9]{4}$/.test(code)) await showRoom(code);
  else await showStart();
}

void start();
