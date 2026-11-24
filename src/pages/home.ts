import { getMyProfile } from '../api/auth';
import { getFoodCategories, type FoodCategory } from '../api/lookups';
import { getMyAllergenIds, updateMyRegion } from '../api/me';
import {
  getRecommendedMenus,
  getRestaurants,
  toggleSaveRestaurant,
  type RecommendedMenu,
  type RestaurantSummary,
} from '../api/restaurants';
import { PATHS } from '../lib/constants';
import { requireAuth } from '../utils/auth-guard';
import { renderBottomNav } from '../utils/bottom-nav';
import { el, qs, showToast } from '../utils/dom';
import { createCategoryFallback } from '../utils/image';
import { withReturnTo } from '../utils/navigation';
import { pickRegion } from '../utils/region-picker';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';

const MAX_TAGS = 3;

let region = '';
let categoryId: number | undefined;
let query = '';
let categories: FoodCategory[] = [];

// 늦게 도착한 이전 응답이 새 결과를 덮어쓰지 않도록 영역별 요청 순번을 둔다
let menuSeq = 0;
let restaurantSeq = 0;
const savingIds = new Set<number>();

/** 가장 최근 주변 맛집 요청의 결과. 추천이 0건일 때 "지역에 가게가 있는지" 판단하는 데 쓴다. */
interface RestaurantsSnapshot {
  settled: Promise<void>;
  /** 요청이 성공했을 때의 건수. 실패하면 null */
  count: number | null;
  /** 카테고리·검색어 필터가 걸린 요청인지 (필터 결과 0건은 지역에 가게가 없다는 뜻이 아니다) */
  filtered: boolean;
}
let restaurantsSnapshot: RestaurantsSnapshot | null = null;
// 내 알레르기 등록 여부는 이 화면에서 바뀌지 않으므로 처음 한 번만 가져온다 (실패하면 null 로 두고 다음에 다시 시도)
let hasAllergyCache: boolean | null = null;

const recommendArea = qs('#recommend-area');
const restaurantArea = qs('#restaurant-area');
const categoryArea = qs('#category-area');
const regionText = qs('#region-text');
const searchForm = qs<HTMLFormElement>('#search-form');
const searchInput = qs<HTMLInputElement>('#search-input');
const searchReset = qs<HTMLButtonElement>('#search-reset');
const nearbyTitle = qs('#nearby-title');

function restaurantHref(id: number): string {
  return `${PATHS.restaurant}?id=${encodeURIComponent(String(id))}`;
}

/** 서버 이미지 주소는 http(s) 만 허용한다. */
function safeImageUrl(url: string | null): string | null {
  if (!url) return null;
  try {
    const parsed = new URL(url, window.location.origin);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:' ? parsed.href : null;
  } catch {
    return null;
  }
}

/** 이미지가 없거나 불러오기에 실패하면 토큰 색 플레이스홀더로 바꾼다. */
function createImage(url: string | null, className: string, categoryName: string | null = null): HTMLElement {
  const placeholder = (): HTMLElement => createCategoryFallback(className, categoryName) ?? el('div', { class: className });
  const safe = safeImageUrl(url);
  if (!safe) return placeholder();
  const img = el('img', { class: className, src: safe, alt: '', loading: 'lazy' });
  img.addEventListener('error', () => img.replaceWith(placeholder()));
  return img;
}

function clampPercent(value: number): number {
  return Math.min(100, Math.max(0, value));
}

/** 막대 + 값 한 줄. value 는 0~100, label 은 표시 문구. */
function createMeter(kind: 'rating' | 'match', value: number, label: string): HTMLElement {
  const bar = el('div', { class: 'meter__bar' });
  bar.style.setProperty('--value', String(clampPercent(value)));
  return el('div', { class: kind === 'rating' ? 'meter meter--rating' : 'meter' }, bar, el('span', {}, label));
}

function ratingLabel(avg: number): string {
  return `${avg.toFixed(1)} / 5`;
}

// ---------- 오늘의 추천 메뉴 ----------

function createMenuCard(menu: RecommendedMenu): HTMLElement {
  const body = el(
    'div',
    { class: 'menu-card__body' },
    el('p', { class: 'menu-card__name' }, menu.menuName),
    el('p', { class: 'place' }, menu.region),
  );
  const meters = el('div', { class: 'menu-card__body' });
  if (menu.avgRating === null) {
    meters.append(el('p', { class: 'meter meter--none' }, '아직 평가가 없어요'));
  } else {
    meters.append(createMeter('rating', (menu.avgRating / 5) * 100, ratingLabel(menu.avgRating)));
  }
  if (menu.matchPercent !== null) {
    meters.append(createMeter('match', menu.matchPercent, `${Math.round(menu.matchPercent)} %`));
  }
  return el(
    'a',
    { class: 'menu-card', href: restaurantHref(menu.restaurantId), 'aria-label': `${menu.menuName} - ${menu.restaurantName}` },
    createImage(menu.imageUrl, 'menu-card__image', menu.categoryName),
    body,
    meters,
  );
}

/** 지역에 가게가 있는지: true/false, 확인하지 못하면 null (주변 맛집 요청 실패 등) */
async function regionHasRestaurants(): Promise<boolean | null> {
  const snapshot = restaurantsSnapshot;
  if (!snapshot) return null;
  await snapshot.settled;
  if (snapshot.count === null) return null;
  if (snapshot.count > 0) return true;
  if (!snapshot.filtered) return false;
  // 필터 때문에 0건일 수 있으므로 필터 없이 한 번 더 확인한다
  try {
    return (await getRestaurants({ region })).length > 0;
  } catch {
    return null;
  }
}

/** 알레르기를 1개 이상 등록했는지. 조회에 실패하면 null (기존 문구로 폴백하고 에러는 띄우지 않는다). */
async function hasAllergy(): Promise<boolean | null> {
  if (hasAllergyCache !== null) return hasAllergyCache;
  try {
    hasAllergyCache = (await getMyAllergenIds()).length > 0;
    return hasAllergyCache;
  } catch {
    return null;
  }
}

/** 추천이 0건일 때의 빈 상태. 알레르기 때문에 걸러진 경우와 단순히 데이터가 없는 경우를 구분한다. */
async function renderNoRecommendation(target: HTMLElement, seq: number): Promise<void> {
  const shops = await regionHasRestaurants();
  const allergy = shops === true ? await hasAllergy() : null;
  if (seq !== menuSeq) return;
  if (shops === false) {
    // 디자인 대기: Figma 에 없는 문구. 아래 주변 맛집 목록의 빈 상태 문구와 겹치지 않게 쓴다
    renderEmpty(target, '이 지역에는 추천할 메뉴가 없어요', '다른 지역을 골라보세요');
    return;
  }
  if (shops === true && allergy === true) {
    // 디자인 대기: Figma 에 없는 문구 (안전 규칙 때문에 추천이 비었다는 것을 알린다)
    renderEmpty(target, '내 알레르기를 반영하면 추천할 메뉴가 없어요', '알레르기 정보가 없는 메뉴는 안전을 위해 빼고 있어요');
    target.querySelector('.empty-state__title')?.classList.add('text-wrap-ko');
    target.querySelector('.empty-state__desc')?.classList.add('text-wrap-ko');
    const allergyLink = el('a', { class: 'home__empty-link', href: withReturnTo(PATHS.allergyEdit) }, '알레르기 확인하기');
    const regionLink = el('button', { class: 'home__empty-link', type: 'button' }, '위치 변경하기');
    regionLink.addEventListener('click', () => void changeRegion());
    target.querySelector('.empty-state')?.append(el('div', { class: 'home__empty-links' }, allergyLink, regionLink));
    return;
  }
  renderEmpty(target, '추천할 메뉴가 아직 없어요', '평가가 쌓이면 취향에 맞는 메뉴를 추천해 드려요');
}

async function loadMenus(): Promise<void> {
  if (!recommendArea) return;
  const seq = ++menuSeq;
  renderLoading(recommendArea);
  try {
    const menus = await getRecommendedMenus(region);
    if (seq !== menuSeq) return;
    if (menus.length === 0) {
      await renderNoRecommendation(recommendArea, seq);
      return;
    }
    recommendArea.replaceChildren(el('div', { class: 'menu-grid' }, ...menus.map(createMenuCard)));
  } catch (e) {
    if (seq !== menuSeq) return;
    renderError(recommendArea, e instanceof Error ? e.message : '추천 메뉴를 불러오지 못했어요', () => void loadMenus());
  }
}

// ---------- 주변 맛집 ----------

function setSaveButtonState(button: HTMLButtonElement, saved: boolean): void {
  button.classList.toggle('is-saved', saved);
  button.setAttribute('aria-pressed', String(saved));
  button.setAttribute('aria-label', saved ? '저장 해제' : '저장');
}

async function onToggleSave(restaurant: RestaurantSummary, button: HTMLButtonElement): Promise<void> {
  if (savingIds.has(restaurant.restaurantId)) return;
  savingIds.add(restaurant.restaurantId);
  button.disabled = true;
  const next = !restaurant.isSaved;
  // 낙관적 업데이트
  restaurant.isSaved = next;
  setSaveButtonState(button, next);
  try {
    await toggleSaveRestaurant(restaurant.restaurantId, next);
  } catch (e) {
    restaurant.isSaved = !next;
    setSaveButtonState(button, !next);
    showToast(e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요');
  } finally {
    savingIds.delete(restaurant.restaurantId);
    button.disabled = false;
  }
}

function createRestaurantCard(restaurant: RestaurantSummary): HTMLElement {
  const rating =
    restaurant.avgRating === null
      ? el('p', { class: 'store-card__rating store-card__rating--none' }, '아직 평가가 없어요')
      : el('p', { class: 'store-card__rating' }, ratingLabel(restaurant.avgRating));

  const tags = el('div', { class: 'store-card__tags' });
  restaurant.tasteTags.slice(0, MAX_TAGS).forEach((tag, index) => {
    tags.append(el('span', { class: index === 0 ? 'chip is-active' : 'chip' }, tag));
  });

  const info = el(
    'div',
    { class: 'store-card__info' },
    el(
      'div',
      { class: 'store-card__top' },
      el('p', { class: 'store-card__name' }, restaurant.name),
      el('p', { class: 'place' }, restaurant.region),
      rating,
    ),
    tags,
  );
  const link = el(
    'a',
    { class: 'store-card__link', href: restaurantHref(restaurant.restaurantId) },
    createImage(restaurant.imageUrl, 'store-card__image', restaurant.categoryName),
    info,
  );

  const save = el('button', { class: 'store-card__save', type: 'button' });
  setSaveButtonState(save, restaurant.isSaved);
  save.addEventListener('click', () => void onToggleSave(restaurant, save));

  return el('article', { class: 'store-card' }, link, save);
}

/** 가게 목록이 비었을 때: 검색 결과 없음 / 빈 카테고리 / 지역에 가게 없음을 구분해 앱 오류로 오해하지 않게 한다. */
function renderNoRestaurants(target: HTMLElement): void {
  if (query) {
    renderEmpty(target, '검색 결과가 없어요', `'${query}'에 맞는 맛집이나 메뉴가 없어요. 다른 검색어로 찾아보세요`);
    target.querySelector('.empty-state__desc')?.classList.add('text-wrap-ko');
    return;
  }
  if (categoryId !== undefined) {
    // 디자인 대기: Figma 에 없는 문구. 데이터가 없는 카테고리(현재는 양식 외)를 눌렀을 때 보인다
    renderEmpty(target, '이 카테고리의 맛집은 아직 준비 중이에요', '곧 더 많은 맛집을 보여드릴게요');
    target.querySelector('.empty-state__title')?.classList.add('text-wrap-ko');
    target.querySelector('.empty-state__desc')?.classList.add('text-wrap-ko');
    const all = el('button', { class: 'home__empty-link', type: 'button' }, '전체 보기');
    all.addEventListener('click', () => {
      categoryId = undefined;
      renderCategories();
      void loadRestaurants();
    });
    target.querySelector('.empty-state')?.append(el('div', { class: 'home__empty-links' }, all));
    return;
  }
  renderEmpty(target, '이 지역에는 아직 등록된 맛집이 없어요', '다른 지역을 선택해 보세요');
}

async function loadRestaurants(): Promise<void> {
  if (!restaurantArea) return;
  const seq = ++restaurantSeq;
  renderLoading(restaurantArea);
  let finish: () => void = () => undefined;
  const snapshot: RestaurantsSnapshot = {
    settled: new Promise<void>((resolve) => {
      finish = resolve;
    }),
    count: null,
    filtered: categoryId !== undefined || query !== '',
  };
  restaurantsSnapshot = snapshot;
  try {
    const list = await getRestaurants({ region, categoryId, query: query || undefined });
    snapshot.count = list.length;
    if (seq !== restaurantSeq) return;
    if (list.length === 0) {
      renderNoRestaurants(restaurantArea);
      return;
    }
    restaurantArea.replaceChildren(el('div', { class: 'store-list' }, ...list.map(createRestaurantCard)));
  } catch (e) {
    if (seq !== restaurantSeq) return;
    renderError(restaurantArea, e instanceof Error ? e.message : '맛집 목록을 불러오지 못했어요', () => void loadRestaurants());
  } finally {
    finish();
  }
}

// ---------- 카테고리 칩 ----------

function renderCategories(): void {
  if (!categoryArea) return;
  const items: { id: number | undefined; name: string }[] = [{ id: undefined, name: '전체' }, ...categories];
  categoryArea.replaceChildren(
    ...items.map((item) => {
      const active = item.id === categoryId;
      const chip = el(
        'button',
        { class: active ? 'chip chip--filter is-active' : 'chip chip--filter', type: 'button', 'aria-pressed': String(active) },
        item.name,
      );
      chip.addEventListener('click', () => {
        if (item.id === categoryId) return;
        categoryId = item.id;
        renderCategories();
        void loadRestaurants();
      });
      return chip;
    }),
  );
}

async function loadCategories(): Promise<void> {
  try {
    categories = await getFoodCategories();
  } catch {
    // 카테고리를 못 불러와도 "전체"로 목록은 볼 수 있다
    categories = [];
  }
  renderCategories();
}

// ---------- 검색 ----------

function applyQuery(next: string): void {
  query = next.trim();
  if (searchInput) searchInput.value = query;
  if (searchReset) searchReset.hidden = !query;
  qs('#app')?.classList.toggle('home--searching', query !== '');
  if (nearbyTitle) nearbyTitle.textContent = query ? '검색 결과' : '주변 맛집 보기';
  void loadRestaurants();
}

// ---------- 지역 ----------

function reloadAll(): void {
  if (regionText) regionText.textContent = region;
  // 추천 빈 상태가 주변 맛집 결과를 참고하므로 맛집 요청을 먼저 시작한다
  void loadRestaurants();
  void loadMenus();
}

async function changeRegion(): Promise<void> {
  const picked = await pickRegion({ current: region || null });
  if (!picked || picked === region) return;
  try {
    await updateMyRegion(picked);
  } catch (e) {
    showToast(e instanceof Error ? e.message : '지역을 바꾸지 못했어요');
    return;
  }
  region = picked;
  reloadAll();
}

/** region 이 비어 있는 비정상 상태: 지역을 고르고 저장할 때까지 선택을 요청한다. */
async function requireRegion(): Promise<void> {
  const target = recommendArea;
  for (;;) {
    const picked = await pickRegion({});
    if (picked) {
      try {
        await updateMyRegion(picked);
        region = picked;
        return;
      } catch (e) {
        showToast(e instanceof Error ? e.message : '지역을 저장하지 못했어요');
      }
    }
    // 시트를 닫았거나 저장에 실패하면 버튼으로 다시 고르게 한다
    await new Promise<void>((resolve) => {
      const retry = el('button', { class: 'btn-primary', type: 'button' }, '지역 선택하기');
      retry.addEventListener('click', () => resolve());
      target?.replaceChildren(el('div', { class: 'empty-state' }, el('p', { class: 'empty-state__title' }, '지역을 선택해 주세요'), retry));
    });
  }
}

// ---------- 시작 ----------

async function start(): Promise<void> {
  const app = qs('#app');
  if (!app || !recommendArea || !restaurantArea) return;
  app.append(renderBottomNav('home'));
  const matchBanner = qs<HTMLAnchorElement>('#match-banner');
  if (matchBanner) matchBanner.href = PATHS.match;
  const tasteEdit = qs<HTMLAnchorElement>('#taste-edit');
  if (tasteEdit) tasteEdit.href = withReturnTo(PATHS.tasteEdit);
  // 디자인 대기: Figma 에 없는 임시 링크. 누를 때의 지역을 넘겨 가게 추가 화면의 기본 지역으로 쓴다
  qs<HTMLAnchorElement>('#store-add')?.addEventListener('click', (event) => {
    event.preventDefault();
    window.location.href = region ? `${PATHS.storeAdd}?region=${encodeURIComponent(region)}` : PATHS.storeAdd;
  });

  if (!(await requireAuth())) return;

  renderLoading(recommendArea);
  renderLoading(restaurantArea);
  try {
    const profile = await getMyProfile();
    if (!profile || !profile.onboarding_done) {
      window.location.replace(PATHS.onboardingStart);
      return;
    }
    region = profile.region ?? '';
  } catch (e) {
    renderError(recommendArea, e instanceof Error ? e.message : '프로필을 불러오지 못했어요', () => window.location.reload());
    restaurantArea.replaceChildren();
    return;
  }

  qs('#region-change')?.addEventListener('click', () => void changeRegion());
  searchForm?.addEventListener('submit', (event) => {
    event.preventDefault();
    applyQuery(searchInput?.value ?? '');
  });
  searchReset?.addEventListener('click', () => applyQuery(''));
  // 입력을 모두 지우거나 검색창의 X 버튼을 누르면 제출 없이 바로 원래 홈 구성으로 돌아온다
  searchInput?.addEventListener('input', () => {
    if (searchInput.value.trim() === '' && query !== '') applyQuery('');
  });
  // 뒤로가기 등으로 브라우저가 입력값만 복원해도 화면(검색 전 상태)과 어긋나지 않게 비운다
  if (searchInput) searchInput.value = '';

  void loadCategories();
  if (!region) await requireRegion();
  reloadAll();
}

void start();
