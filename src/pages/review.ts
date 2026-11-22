// 메뉴 평가 작성/수정. 평가는 브랜드 메뉴 단위라 같은 브랜드의 모든 지점이 공유한다.
// 디자인 대기: 화면 나오면 교체 (Figma 파일에 평가 작성 화면이 아직 없다)
import { getTasteTags, type TasteTag } from '../api/lookups';
import { deleteReview, getMenuForReview, upsertReview, type MenuForReview } from '../api/reviews';
import starIcon from '../assets/icons/star.svg';
import { PATHS } from '../lib/constants';
import { requireAuth } from '../utils/auth-guard';
import { el, qs, showToast } from '../utils/dom';
import { createImage } from '../utils/image';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';

const MAX_RATING = 5;
const LEAVE_DELAY_MS = 900;
const FALLBACK_ERROR = '문제가 발생했어요. 잠시 후 다시 시도해주세요';

const area = qs('#review-area');
const backButton = qs<HTMLButtonElement>('#back');

let menuId = 0;
let restaurantId: number | null = null;

function parseId(raw: string | null): number | null {
  return raw !== null && /^[1-9]\d{0,15}$/.test(raw) ? Number(raw) : null;
}

/** 돌아가기: 지점 id 가 있으면 그 상세로(새로 불러와 평점이 갱신된다), 없으면 이전 화면, 그것도 없으면 홈 */
function leave(): void {
  if (restaurantId !== null) window.location.replace(`${PATHS.restaurant}?id=${encodeURIComponent(String(restaurantId))}`);
  else if (window.history.length > 1) window.history.back();
  else window.location.replace(PATHS.home);
}

function renderProblem(message: string, retry: (() => void) | null): void {
  if (!area) return;
  if (retry) renderError(area, message, retry);
  else renderEmpty(area, message, '홈에서 다른 메뉴를 찾아보세요');
  area.append(el('a', { class: 'review__home-link', href: PATHS.home }, '홈으로'));
}

// ---------- 별점 입력 ----------

interface StarInput {
  root: HTMLElement;
  get: () => number;
}

function createStarInput(initial: number, onChange: () => void): StarInput {
  let value = initial;
  const root = el('div', { class: 'stars', role: 'radiogroup', 'aria-label': '별점' });
  const valueText = el('span', { class: 'stars__value', 'aria-live': 'polite' });
  const buttons: HTMLButtonElement[] = [];

  const paint = (): void => {
    buttons.forEach((button, index) => {
      const n = index + 1;
      button.classList.toggle('is-on', n <= value);
      button.setAttribute('aria-checked', String(n === value));
      // 선택값이 없으면 첫 별이 탭 진입점, 있으면 선택된 별만
      button.tabIndex = n === (value || 1) ? 0 : -1;
    });
    valueText.textContent = value > 0 ? `${value}점` : '별을 눌러 선택하세요';
  };
  const select = (next: number, focus: boolean): void => {
    value = Math.min(MAX_RATING, Math.max(1, next));
    paint();
    if (focus) buttons[value - 1]?.focus();
    onChange();
  };

  for (let n = 1; n <= MAX_RATING; n += 1) {
    const button = el('button', { class: 'stars__star', type: 'button', role: 'radio', 'aria-label': `${n}점` }, el('img', { src: starIcon, alt: '', 'aria-hidden': 'true' }));
    // 같은 별을 다시 눌러도 값을 유지한다(해제하지 않는다)
    button.addEventListener('click', () => select(n, false));
    button.addEventListener('keydown', (event) => {
      const step = event.key === 'ArrowRight' || event.key === 'ArrowUp' ? 1 : event.key === 'ArrowLeft' || event.key === 'ArrowDown' ? -1 : 0;
      if (step === 0) return;
      event.preventDefault();
      select((value || n) + step, true);
    });
    buttons.push(button);
    root.append(button);
  }
  root.append(valueText);
  paint();
  return { root, get: () => value };
}

// ---------- 화면 ----------

function renderForm(data: MenuForReview, tags: TasteTag[]): void {
  if (!area) return;
  const { menu, myReview } = data;
  const isEdit = myReview !== null;
  const submitLabel = isEdit ? '수정하기' : '저장하기';
  const selectedTags = new Set<number>(myReview?.tagIds ?? []);

  const info = el('div', { class: 'review__menu-info' }, el('h1', { class: 'review__name text-wrap-ko' }, menu.name));
  if (menu.brandName) info.append(el('p', { class: 'review__brand' }, menu.brandName));
  if (menu.description) info.append(el('p', { class: 'review__desc text-wrap-ko' }, menu.description));

  const submit = el('button', { class: 'btn-primary', type: 'button' }, submitLabel);
  const deleteButton = el('button', { class: 'review__delete', type: 'button' }, '평가 삭제');
  const errorLine = el('p', { class: 'review__error', role: 'alert' });
  errorLine.hidden = true;

  let busy = false;
  const stars = createStarInput(myReview?.rating ?? 0, () => sync());
  function sync(): void {
    submit.disabled = busy || stars.get() < 1;
    deleteButton.disabled = busy;
  }
  function showError(message: string): void {
    errorLine.textContent = message;
    errorLine.hidden = false;
  }

  submit.addEventListener('click', async () => {
    const rating = stars.get();
    if (busy || rating < 1) return;
    errorLine.hidden = true;
    busy = true;
    submit.textContent = '저장 중...';
    sync();
    try {
      await upsertReview(menuId, rating, [...selectedTags]);
      showToast(isEdit ? '평가를 수정했어요' : '평가를 저장했어요');
      window.setTimeout(leave, LEAVE_DELAY_MS);
    } catch (e) {
      showError(e instanceof Error ? e.message : FALLBACK_ERROR);
      busy = false;
      submit.textContent = submitLabel;
      sync();
    }
  });

  deleteButton.addEventListener('click', async () => {
    if (busy || !window.confirm('이 메뉴의 평가를 삭제할까요?')) return;
    errorLine.hidden = true;
    busy = true;
    sync();
    try {
      await deleteReview(menuId);
      showToast('평가를 삭제했어요');
      window.setTimeout(leave, LEAVE_DELAY_MS);
    } catch (e) {
      showError(e instanceof Error ? e.message : FALLBACK_ERROR);
      busy = false;
      sync();
    }
  });

  const chips = el('div', { class: 'chip-group' });
  for (const tag of tags) {
    const chip = el('button', { class: 'chip', type: 'button', 'aria-pressed': String(selectedTags.has(tag.id)) }, tag.name);
    chip.classList.toggle('is-active', selectedTags.has(tag.id));
    chip.addEventListener('click', () => {
      const on = !selectedTags.has(tag.id);
      if (on) selectedTags.add(tag.id);
      else selectedTags.delete(tag.id);
      chip.classList.toggle('is-active', on);
      chip.setAttribute('aria-pressed', String(on));
    });
    chips.append(chip);
  }

  const actions = el('div', { class: 'review__actions' }, errorLine, submit);
  if (isEdit) actions.append(deleteButton);

  area.replaceChildren(
    el(
      'div',
      { class: 'review__form' },
      el('section', { class: 'review__menu' }, createImage(menu.imageUrl, 'review__image'), info),
      el('section', { class: 'review__section' }, el('h2', { class: 'review__title' }, '별점'), stars.root),
      el('section', { class: 'review__section' }, el('h2', { class: 'review__title' }, '맛 태그'), el('p', { class: 'review__hint text-wrap-ko' }, '이 메뉴에서 느낀 맛을 골라주세요'), chips),
      actions,
    ),
  );
  document.title = `${menu.name} 평가 - T:MATE`;
  sync();
}

async function load(): Promise<void> {
  if (!area) return;
  renderLoading(area);
  try {
    const [data, tags] = await Promise.all([getMenuForReview(menuId), getTasteTags()]);
    if (!data) {
      renderProblem('찾을 수 없는 메뉴예요', null);
      return;
    }
    renderForm(data, tags);
  } catch (e) {
    renderProblem(e instanceof Error ? e.message : '메뉴 정보를 불러오지 못했어요', () => void load());
  }
}

async function start(): Promise<void> {
  backButton?.addEventListener('click', leave);
  if (!(await requireAuth())) return;
  const params = new URLSearchParams(window.location.search);
  const id = parseId(params.get('menuId'));
  restaurantId = parseId(params.get('restaurantId'));
  if (id === null) {
    renderProblem('찾을 수 없는 메뉴예요', null);
    return;
  }
  menuId = id;
  await load();
}

void start();
