// 내 입맛 자세히 보기 (마이페이지 → "내 입맛 자세히 보기"). get_my_summary 의 값만 읽어서 보여준다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 이 화면이 없다)
import { getMySummary, type MySummary } from '../api/me';
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

function render(summary: MySummary): void {
  if (!body) return;
  const nodes: HTMLElement[] = [];

  if (summary.tasteRatios.length === 0) {
    // 비율 데이터가 없으면 안내와 입맛 등록 링크로 대체한다
    nodes.push(el('div', { class: 'type-box' }, el('p', { class: 'type-box__name text-wrap-ko' }, '입맛 정보를 등록해 주세요'), el('a', { class: 'taste-detail__empty-link', href: withReturnTo(PATHS.tasteEdit) }, '입맛 등록하기')));
  } else {
    const box = el('div', { class: 'type-box' }, el('p', { class: 'type-box__label' }, 'My Taste Type'));
    if (summary.tasteTypeName) box.append(el('p', { class: 'type-box__name' }, summary.tasteTypeName));
    if (summary.tasteTypeDesc) box.append(el('p', { class: 'type-box__desc text-wrap-ko' }, summary.tasteTypeDesc));
    nodes.push(box);
    // 맛 비율 전체(최대 3개). get_my_summary 가 비율 큰 순으로 준다
    nodes.push(
      el(
        'section',
        { class: 'taste-detail__section' },
        el('h2', { class: 'section-title' }, '맛 비율'),
        el('div', { class: 'ratio-rows' }, ...summary.tasteRatios.slice(0, 3).map((r) => createRatioRow(r.name, r.ratio))),
      ),
    );
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
  nodes.push(el('p', { class: 'taste-detail__hint text-wrap-ko' }, '평가를 남길수록 입맛이 더 정확해져요'));
  if (summary.tasteRatios.length > 0) nodes.push(el('a', { class: 'taste-detail__edit', href: withReturnTo(PATHS.tasteEdit) }, '입맛 수정하기'));
  body.replaceChildren(...nodes);
}

async function load(): Promise<void> {
  if (!body) return;
  renderLoading(body);
  try {
    const summary = await getMySummary();
    if (!summary) {
      renderError(body, '내 정보를 찾지 못했어요', () => void load());
      return;
    }
    render(summary);
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
