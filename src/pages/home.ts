import { getMyProfile } from '../api/auth';
import { getFoodCategories, type FoodCategory } from '../api/lookups';
import { updateMyRegion } from '../api/me';
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
function createImage(url: string | null, className: string): HTMLElement {
  const placeholder = (): HTMLElement => el('div', { class: className });
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
    createImage(menu.imageUrl, 'menu-card__image'),
    body,
    meters,
  );
}

async function loadMenus(): Promise<void> {
  if (!recommendArea) return;
  const seq = ++menuSeq;
  renderLoading(recommendArea);
  try {
    const menus = await getRecommendedMenus(region);
    if (seq !== menuSeq) return;
    if (menus.length === 0) {
      renderEmpty(recommendArea, '추천할 메뉴가 아직 없어요', '평가가 쌓이면 취향에 맞는 메뉴를 추천해 드려요');
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
    createImage(restaurant.imageUrl, 'store-card__image'),
    info,
  );

  const save = el('button', { class: 'store-card__save', type: 'button' });
  setSaveButtonState(save, restaurant.isSaved);
  save.addEventListener('click', () => void onToggleSave(restaurant, save));

  return el('article', { class: 'store-card' }, link, save);
}

async function loadRestaurants(): Promise<void> {
  if (!restaurantArea) return;
  const seq = ++restaurantSeq;
  renderLoading(restaurantArea);
  try {
    const list = await getRestaurants({ region, categoryId, query: query || undefined });
    if (seq !== restaurantSeq) return;
    if (list.length === 0) {
      renderEmpty(
        restaurantArea,
        query ? `'${query}'에 맞는 맛집이 없어요` : '이 지역에는 아직 등록된 맛집이 없어요',
        query ? '다른 검색어로 찾아보세요' : '다른 지역을 선택해 보세요',
      );
      return;
    }
    restaurantArea.replaceChildren(el('div', { class: 'store-list' }, ...list.map(createRestaurantCard)));
  } catch (e) {
    if (seq !== restaurantSeq) return;
    renderError(restaurantArea, e instanceof Error ? e.message : '맛집 목록을 불러오지 못했어요', () => void loadRestaurants());
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
  if (nearbyTitle) nearbyTitle.textContent = query ? '검색 결과' : '주변 맛집 보기';
  void loadRestaurants();
}

// ---------- 지역 ----------

function reloadAll(): void {
  if (regionText) regionText.textContent = region;
  void loadMenus();
  void loadRestaurants();
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
  const tasteEdit = qs<HTMLAnchorElement>('#taste-edit');
  if (tasteEdit) tasteEdit.href = PATHS.tasteEdit;

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

  void loadCategories();
  if (!region) await requireRegion();
  reloadAll();
}

void start();
