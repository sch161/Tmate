// 나의 취향 메이트: 입맛(별점)이 비슷한 다른 사용자 목록. 읽기 전용이다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 이 화면이 없다)
import { getMySummary, getTasteMates, type TasteMate } from '../api/me';
import { PATHS } from '../lib/constants';
import { requireAuth } from '../utils/auth-guard';
import { el, qs } from '../utils/dom';
import { renderError, renderLoading } from '../utils/state-views';

const PAGE_SIZE = 20;
// supabase/functions.sql 의 calc_setting 값 (조건 설명 문구에만 쓴다. 계산은 서버가 한다)
//   min_common = 3 : 두 사용자의 유사도를 계산하려면 같은 메뉴를 3개 이상 평가해야 한다
//   mate_similarity = 0.7 : 유사도 70% 이상이면 취향 메이트
const MIN_COMMON_REVIEWS = 3;
const MATE_SIMILARITY_PERCENT = 70;

const body = qs<HTMLElement>('#body');
const countText = qs('#count');
const backButton = qs<HTMLButtonElement>('#back');

let mates: TasteMate[] = [];
let expanded = false;

function leave(): void {
  if (window.history.length > 1) window.history.back();
  else window.location.replace(PATHS.mypage);
}

/** 닉네임만 쓴다. 다른 사용자의 아이디·이메일은 화면에 내지 않는다. */
function createCard(mate: TasteMate): HTMLElement {
  const fill = el('div', { class: 'mate-card__fill' });
  fill.style.setProperty('--value', String(mate.similarityPercent));
  const meta = el('div', { class: 'mate-card__meta' }, el('span', {}, `함께 평가한 메뉴 ${mate.commonMenuCount}개`));
  if (mate.tasteTypeName) meta.append(el('span', { class: 'chip is-active' }, mate.tasteTypeName));
  return el(
    'article',
    { class: 'mate-card' },
    el('div', { class: 'mate-card__top' }, el('p', { class: 'mate-card__name' }, mate.nickname), el('p', { class: 'mate-card__percent' }, `${mate.similarityPercent}%`)),
    el('div', { class: 'mate-card__bar', 'aria-hidden': 'true' }, fill),
    meta,
  );
}

function renderEmpty(reviewCount: number | null): void {
  if (!body) return;
  // 디자인 대기: 문구는 Figma 에 없는 임시 UI. 숫자는 functions.sql 의 calc_setting 값이다
  const box = el(
    'div',
    { class: 'mate-empty' },
    el('p', { class: 'mate-empty__title' }, '아직 취향 메이트가 없어요'),
    el('p', { class: 'mate-empty__desc text-wrap-ko' }, `다른 사용자와 같은 메뉴를 ${MIN_COMMON_REVIEWS}개 이상 함께 평가하고 별점이 비슷하면(유사도 ${MATE_SIMILARITY_PERCENT}% 이상) 입맛이 비슷한 사람을 찾아드려요`),
  );
  if (reviewCount !== null) box.append(el('p', { class: 'mate-empty__mine' }, `지금까지 ${reviewCount}개 평가했어요`));
  box.append(el('a', { class: 'mate-empty__link', href: PATHS.home }, '메뉴 평가하러 가기'));
  body.replaceChildren(box);
}

function render(): void {
  if (!body) return;
  const visible = expanded ? mates : mates.slice(0, PAGE_SIZE);
  body.replaceChildren(el('div', { class: 'mate-list' }, ...visible.map(createCard)));
  if (!expanded && mates.length > PAGE_SIZE) {
    const more = el('button', { class: 'taste-mates__more', type: 'button' }, `더 보기 (${mates.length - PAGE_SIZE}명)`);
    more.addEventListener('click', () => {
      expanded = true;
      render();
    });
    body.append(more);
  }
}

async function load(): Promise<void> {
  if (!body) return;
  renderLoading(body);
  try {
    const list = await getTasteMates();
    mates = list;
    if (countText) countText.textContent = `${list.length}명`;
    if (list.length === 0) {
      // 내 평가 수는 설명용이므로 못 가져와도 빈 상태는 보여준다
      const summary = await getMySummary().catch(() => null);
      renderEmpty(summary ? summary.reviewCount : null);
      return;
    }
    render();
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '취향 메이트를 불러오지 못했어요', () => void load());
  }
}

async function start(): Promise<void> {
  backButton?.addEventListener('click', leave);
  if (!(await requireAuth())) return;
  await load();
}

void start();
