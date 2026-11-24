// 내 입맛 자세히 보기 (마이페이지 → "내 입맛 자세히 보기"). get_my_summary(유형·활동)와 get_my_taste_profile(평가로 보정한 맛 비율)을 읽어서 보여준다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 이 화면이 없다)
import { getMySummary, getMyTasteProfile, type MySummary, type TasteProfile } from '../api/me';
import { PATHS } from '../lib/constants';
import { requireAuth } from '../utils/auth-guard';
import { el, qs } from '../utils/dom';
import { withReturnTo } from '../utils/navigation';
import { renderError, renderLoading } from '../utils/state-views';

const body = qs<HTMLElement>('#body');
const backButton = qs<HTMLButtonElement>('#back');

function leave(): void {
  if (window.history.length > 1) window.history.back();
  else window.location.replace(PATHS.mypage);
}

function createRatioRow(name: string, ratio: number): HTMLElement {
  const fill = el('div', { class: 'ratio-row__fill' });
  fill.style.setProperty('--value', String(ratio));
  return el('div', { class: 'ratio-row' }, el('div', { class: 'ratio-row__head' }, el('span', {}, name), el('span', {}, `${Math.round(ratio)}%`)), el('div', { class: 'ratio-row__track' }, fill));
}

function createActivity(count: number, label: string): HTMLElement {
  return el('div', { class: 'activity-box' }, el('p', { class: 'activity-box__count' }, String(count)), el('p', { class: 'activity-box__label' }, label));
}

/** 한 화면에 보여줄 맛 비율 줄 수 (고른 맛 3개 + 평가로 새로 드러난 맛) */
const MAX_RATIO_ROWS = 5;

// 디자인 대기: 평가 반영 안내는 Figma 에 없는 임시 UI
function createLearnNote(profile: TasteProfile): HTMLElement {
  const declared = profile.items
    .filter((item) => item.declared > 0)
    .sort((a, b) => b.declared - a.declared)
    .map((item) => `${item.name} ${item.declared}%`)
    .join(' · ');
  return el(
    'div',
    { class: 'learn-note' },
    el('p', { class: 'learn-note__title text-wrap-ko' }, `내 평가 ${profile.reviewCount}개를 ${profile.learnPercent}% 반영한 비율이에요`),
    el('p', { class: 'learn-note__desc text-wrap-ko' }, `처음 고른 입맛: ${declared}`),
  );
}

function render(summary: MySummary, profile: TasteProfile): void {
  if (!body) return;
  const nodes: HTMLElement[] = [];

  const ratios = profile.items.filter((item) => item.ratio > 0);
  if (ratios.length === 0) {
    // 비율 데이터가 없으면 안내와 입맛 등록 링크로 대체한다
    nodes.push(el('div', { class: 'type-box' }, el('p', { class: 'type-box__name text-wrap-ko' }, '입맛 정보를 등록해 주세요'), el('a', { class: 'taste-detail__empty-link', href: withReturnTo(PATHS.tasteEdit) }, '입맛 등록하기')));
  } else {
    const box = el('div', { class: 'type-box' }, el('p', { class: 'type-box__label' }, 'My Taste Type'));
    if (summary.tasteTypeName) box.append(el('p', { class: 'type-box__name' }, summary.tasteTypeName));
    if (summary.tasteTypeDesc) box.append(el('p', { class: 'type-box__desc text-wrap-ko' }, summary.tasteTypeDesc));
    nodes.push(box);
    // 맛 비율(평가로 보정한 지금 입맛). get_my_taste_profile 이 비율 큰 순으로 준다
    const section = el(
      'section',
      { class: 'taste-detail__section' },
      el('h2', { class: 'section-title' }, '맛 비율'),
      el('div', { class: 'ratio-rows' }, ...ratios.slice(0, MAX_RATIO_ROWS).map((r) => createRatioRow(r.name, r.ratio))),
    );
    if (profile.learnPercent > 0) section.append(createLearnNote(profile));
    nodes.push(section);
  }

  nodes.push(
    el(
      'section',
      { class: 'taste-detail__section' },
      el('h2', { class: 'section-title' }, '나의 활동'),
      el('div', { class: 'activity-rows' }, createActivity(summary.reviewCount, '평가한 메뉴'), createActivity(summary.savedRestaurantCount, '저장한 맛집'), createActivity(summary.mateCount, '취향 메이트')),
    ),
  );
  // 디자인 대기: 안내 문구는 Figma 에 없는 임시 UI
  nodes.push(el('p', { class: 'taste-detail__hint text-wrap-ko' }, '평가를 남길수록 맛 비율이 내 입맛에 맞게 바뀌어요'));
  if (ratios.length > 0) nodes.push(el('a', { class: 'taste-detail__edit', href: withReturnTo(PATHS.tasteEdit) }, '입맛 수정하기'));
  body.replaceChildren(...nodes);
}

async function load(): Promise<void> {
  if (!body) return;
  renderLoading(body);
  try {
    const [summary, profile] = await Promise.all([getMySummary(), getMyTasteProfile()]);
    if (!summary) {
      renderError(body, '내 정보를 찾지 못했어요', () => void load());
      return;
    }
    render(summary, profile);
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

// 입맛을 수정하고 뒤로 가기로 돌아오면(bfcache) 값이 낡아 있으므로 새로 불러온다
window.addEventListener('pageshow', (event) => {
  if (event.persisted) window.location.reload();
});
