// 내가 평가한 메뉴: 평가 목록 + 수정/삭제. 평가는 브랜드 메뉴 단위다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 이 화면이 없다)
import { getMyProfile } from '../api/auth';
import { deleteReview, getMyReviews, type MyReviewItem } from '../api/reviews';
import { findBranchInRegion } from '../api/saved';
import { PATHS } from '../lib/constants';
import { getAllergenStatusInfo } from '../utils/allergen-status';
import { requireAuth } from '../utils/auth-guard';
import { el, qs, showToast } from '../utils/dom';
import { createImage } from '../utils/image';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';

const PAGE_SIZE = 20;
const FALLBACK_ERROR = '문제가 발생했어요. 잠시 후 다시 시도해주세요';
const NO_BRANCH_MESSAGE = '이 지역에는 이 브랜드의 지점이 없어요. 위치를 바꿔 보세요';

const body = qs<HTMLElement>('#body');
const countText = qs('#count');
const backButton = qs<HTMLButtonElement>('#back');

let items: MyReviewItem[] = [];
let expanded = false;
let myRegion: string | null = null;
let navigating = false;
const deleting = new Set<number>();

function leave(): void {
  if (window.history.length > 1) window.history.back();
  else window.location.replace(PATHS.mypage);
}

/** ISO 날짜 → YYYY.MM.DD (잘못된 값이면 빈 문자열) */
function formatDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}`;
}

/** 메뉴·브랜드를 누르면 내 지역에서 그 브랜드의 가장 작은 id 지점의 상세로 간다 (저장 화면과 같은 규칙) */
async function openBranch(item: MyReviewItem): Promise<void> {
  if (navigating) return;
  navigating = true;
  try {
    const branchId = myRegion ? await findBranchInRegion(item.brandId, myRegion) : null;
    if (branchId === null) {
      showToast(NO_BRANCH_MESSAGE);
      return;
    }
    window.location.href = `${PATHS.restaurant}?id=${encodeURIComponent(String(branchId))}`;
  } catch (e) {
    showToast(e instanceof Error ? e.message : FALLBACK_ERROR);
  } finally {
    navigating = false;
  }
}

/** 삭제: 확인 후 낙관적으로 목록에서 빼고, 실패하면 원래 자리로 되돌린다 */
async function removeReview(item: MyReviewItem): Promise<void> {
  if (deleting.has(item.menuId)) return;
  if (!window.confirm('이 평가를 삭제할까요?')) return;
  const index = items.indexOf(item);
  if (index < 0) return;
  deleting.add(item.menuId);
  items.splice(index, 1);
  render();
  try {
    await deleteReview(item.menuId);
    showToast('평가를 삭제했어요');
  } catch (e) {
    items.splice(Math.min(index, items.length), 0, item);
    render();
    showToast(e instanceof Error ? e.message : FALLBACK_ERROR);
  } finally {
    deleting.delete(item.menuId);
  }
}

function createCard(item: MyReviewItem): HTMLElement {
  const status = getAllergenStatusInfo(item.allergenStatus);
  const info = el(
    'div',
    { class: 'review-card__info' },
    el('p', { class: 'review-card__name' }, item.menuName),
    el('p', { class: 'review-card__brand' }, item.brandName),
    el('p', { class: 'review-card__rating' }, `${item.rating}점`),
  );
  const main = el('button', { class: 'review-card__main', type: 'button' }, createImage(item.imageUrl, 'review-card__image', item.categoryName), info);
  main.addEventListener('click', () => void openBranch(item));

  const card = el('article', { class: 'review-card' }, main);
  if (item.tasteTags.length > 0) {
    const tags = el('div', { class: 'review-card__tags' });
    item.tasteTags.forEach((tag, index) => tags.append(el('span', { class: index === 0 ? 'chip is-active' : 'chip' }, tag)));
    card.append(tags);
  }
  // 알레르기 안전: 겹치면 경고 칩, 상태 라벨은 항상(unknown/estimated 는 "정보 없음" 계열 그대로)
  const safety = el('div', { class: 'review-card__tags' });
  if (item.conflictsWithMyAllergens) safety.append(el('span', { class: 'chip chip--warn' }, '내 알레르기와 겹쳐요'));
  safety.append(el('span', { class: status.unverified ? 'review-card__status review-card__status--unverified text-wrap-ko' : 'review-card__status text-wrap-ko' }, status.label));
  card.append(safety);

  // 수정 링크: 대표 지점이 있으면 돌아갈 지점 id 도 같이 넘긴다 (지점이 하나도 없는 브랜드는 menuId 만)
  const menuQuery = `menuId=${encodeURIComponent(String(item.menuId))}`;
  const href = item.restaurantId !== null ? `${PATHS.review}?${menuQuery}&restaurantId=${encodeURIComponent(String(item.restaurantId))}` : `${PATHS.review}?${menuQuery}`;
  const del = el('button', { class: 'review-card__delete', type: 'button', 'aria-label': `${item.menuName} 평가 삭제` }, '삭제');
  del.addEventListener('click', () => void removeReview(item));
  const actions = el('div', { class: 'review-card__actions' }, el('a', { class: 'review-card__edit', href }, '수정하기'), del);
  card.append(el('div', { class: 'review-card__foot' }, el('span', { class: 'review-card__date' }, formatDate(item.createdAt)), actions));
  return card;
}

function render(): void {
  if (!body) return;
  if (countText) countText.textContent = `${items.length}개`;
  if (items.length === 0) {
    renderEmpty(body, '아직 평가한 메뉴가 없어요', '메뉴를 평가하면 입맛이 비슷한 사람을 찾아드려요');
    body.append(el('a', { class: 'my-reviews__home-link', href: PATHS.home }, '홈으로'));
    return;
  }
  const visible = expanded ? items : items.slice(0, PAGE_SIZE);
  body.replaceChildren(el('div', { class: 'my-reviews__list' }, ...visible.map(createCard)));
  if (!expanded && items.length > PAGE_SIZE) {
    const more = el('button', { class: 'my-reviews__more', type: 'button' }, `더 보기 (${items.length - PAGE_SIZE}개)`);
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
    const [reviews, profile] = await Promise.all([getMyReviews(), getMyProfile().catch(() => null)]);
    // 지역을 못 읽어도 목록은 보여준다 (이동 시 지점이 없다는 안내가 나온다)
    myRegion = profile?.region ?? null;
    items = reviews;
    render();
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '평가한 메뉴를 불러오지 못했어요', () => void load());
  }
}

async function start(): Promise<void> {
  backButton?.addEventListener('click', leave);
  if (!(await requireAuth())) return;
  await load();
}

void start();

// 평가 화면에서 뒤로 가기로 돌아오면(bfcache) 목록이 낡아 있으므로 새로 불러온다
window.addEventListener('pageshow', (event) => {
  if (event.persisted) window.location.reload();
});
