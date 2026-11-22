// 저장 목록: 저장한 가게(지점) + 저장한 메뉴(브랜드 메뉴). Figma Save 1:546
// 디자인 대기: 알레르기 상태 라벨·경고 칩, 검색 문구, 빈/에러 상태는 Figma 에 없는 임시 UI
import { getMyProfile } from '../api/auth';
import { toggleSaveMenu, toggleSaveRestaurant } from '../api/restaurants';
import { findBranchInRegion, getSavedMenus, getSavedRestaurants, type SavedMenu, type SavedRestaurant } from '../api/saved';
import { PATHS } from '../lib/constants';
import { getAllergenStatusInfo } from '../utils/allergen-status';
import { requireAuth } from '../utils/auth-guard';
import { renderBottomNav } from '../utils/bottom-nav';
import { el, qs, showToast } from '../utils/dom';
import { createImage } from '../utils/image';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';

const PREVIEW_COUNT = 3;
const MAX_TAGS = 3;
const FALLBACK_ERROR = '문제가 발생했어요. 잠시 후 다시 시도해주세요';
const NO_BRANCH_MESSAGE = '이 지역에는 이 브랜드의 지점이 없어요. 위치를 바꿔 보세요';

/** 한 섹션(가게/메뉴)의 상태. items 는 저장 최신순 전체 목록이다. */
interface Section<T> {
  items: T[];
  loaded: boolean;
  expanded: boolean;
}

const restaurants: Section<SavedRestaurant> = { items: [], loaded: false, expanded: false };
const menus: Section<SavedMenu> = { items: [], loaded: false, expanded: false };
let query = '';
let myRegion: string | null = null;
let navigating = false;
const saving = new Set<string>();

const restaurantArea = qs('#restaurant-area');
const menuArea = qs('#menu-area');
const restaurantCount = qs('#restaurant-count');
const menuCount = qs('#menu-count');
const restaurantToggle = qs<HTMLButtonElement>('#restaurant-toggle');
const menuToggle = qs<HTMLButtonElement>('#menu-toggle');
const searchInput = qs<HTMLInputElement>('#search-input');
const searchForm = qs<HTMLFormElement>('#search-form');

function matches(query: string, ...texts: string[]): boolean {
  const q = query.trim().toLowerCase();
  return q === '' || texts.some((text) => text.toLowerCase().includes(q));
}

function ratingLine(avg: number | null): HTMLElement {
  return avg === null
    ? el('p', { class: 'saved-card__sub saved-card__rating saved-card__rating--none' }, '아직 평가가 없어요')
    : el('p', { class: 'saved-card__sub saved-card__rating' }, `${avg.toFixed(1)} / 5`);
}

function tagChips(tags: string[]): HTMLElement {
  const box = el('div', { class: 'saved-card__tags' });
  tags.slice(0, MAX_TAGS).forEach((tag, index) => box.append(el('span', { class: index === 0 ? 'chip is-active' : 'chip' }, tag)));
  return box;
}

function createRemoveButton(label: string, onClick: (button: HTMLButtonElement) => void): HTMLButtonElement {
  const button = el('button', { class: 'saved-card__save', type: 'button', 'aria-label': `${label} 저장 해제`, 'aria-pressed': 'true' });
  button.addEventListener('click', () => onClick(button));
  return button;
}

// ---------- 저장 해제 (낙관적 업데이트) ----------

async function removeItem<T>(
  key: string,
  section: Section<T>,
  item: T,
  unsave: () => Promise<void>,
  render: () => void,
): Promise<void> {
  if (saving.has(key)) return;
  saving.add(key);
  const index = section.items.indexOf(item);
  if (index < 0) {
    saving.delete(key);
    return;
  }
  section.items.splice(index, 1);
  render();
  try {
    await unsave();
  } catch (e) {
    // 실패하면 원래 자리로 되돌린다
    section.items.splice(Math.min(index, section.items.length), 0, item);
    render();
    showToast(e instanceof Error ? e.message : FALLBACK_ERROR);
  } finally {
    saving.delete(key);
  }
}

// ---------- 가게 ----------

function createRestaurantCard(item: SavedRestaurant): HTMLElement {
  const info = el(
    'div',
    { class: 'saved-card__info' },
    el(
      'div',
      { class: 'saved-card__top' },
      el('p', { class: 'saved-card__name' }, item.name),
      el('p', { class: 'saved-card__sub saved-card__place' }, item.region),
      ratingLine(item.avgRating),
    ),
    tagChips(item.tasteTags),
  );
  const link = el(
    'a',
    { class: 'saved-card__main', href: `${PATHS.restaurant}?id=${encodeURIComponent(String(item.restaurantId))}` },
    createImage(item.imageUrl, 'saved-card__image'),
    info,
  );
  const remove = createRemoveButton(item.name, () => void removeItem(`r${item.restaurantId}`, restaurants, item, () => toggleSaveRestaurant(item.restaurantId, false), renderRestaurants));
  return el('article', { class: 'saved-card' }, link, remove);
}

// ---------- 메뉴 ----------

/** 메뉴는 브랜드 소속이라, 내 지역에서 그 브랜드의 지점 중 id 가 가장 작은 곳으로 이동한다. */
async function openMenu(item: SavedMenu): Promise<void> {
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

function createMenuCard(item: SavedMenu): HTMLElement {
  const status = getAllergenStatusInfo(item.allergenStatus);
  const top = el('div', { class: 'saved-card__top' }, el('p', { class: 'saved-card__name' }, item.name));
  if (item.brandName) top.append(el('p', { class: 'saved-card__sub' }, item.brandName));
  top.append(ratingLine(item.avgRating));

  const info = el('div', { class: 'saved-card__info' }, top);
  if (item.tasteTags.length > 0) info.append(tagChips(item.tasteTags));
  if (item.description) info.append(el('p', { class: 'saved-card__desc' }, item.description));
  // 알레르기 안전: 겹치면 경고 칩, 상태 라벨은 항상(unknown/estimated 는 "정보 없음" 계열 그대로)
  const safety = el('div', { class: 'saved-card__tags' });
  if (item.conflictsWithMyAllergens) safety.append(el('span', { class: 'chip chip--warn' }, '내 알레르기와 겹쳐요'));
  safety.append(el('span', { class: status.unverified ? 'saved-card__status saved-card__status--unverified' : 'saved-card__status' }, status.label));
  info.append(safety);

  const main = el('button', { class: 'saved-card__main', type: 'button' }, createImage(item.imageUrl, 'saved-card__image'), info);
  main.addEventListener('click', () => void openMenu(item));
  const remove = createRemoveButton(item.name, () => void removeItem(`m${item.menuId}`, menus, item, () => toggleSaveMenu(item.menuId, false), renderMenus));
  return el('article', { class: 'saved-card' }, main, remove);
}

// ---------- 섹션 렌더링 ----------

function renderSection<T>(
  section: Section<T>,
  area: HTMLElement | null,
  count: HTMLElement | null,
  toggle: HTMLButtonElement | null,
  unit: string,
  emptyTitle: string,
  visible: (item: T) => boolean,
  createCard: (item: T) => HTMLElement,
): void {
  if (!area || !section.loaded) return;
  if (count) count.textContent = `${section.items.length}${unit}`;
  const filtered = section.items.filter(visible);
  const showAll = section.expanded || filtered.length <= PREVIEW_COUNT;
  if (toggle) {
    toggle.hidden = filtered.length <= PREVIEW_COUNT;
    toggle.textContent = section.expanded ? '접기' : '전체보기>';
    toggle.setAttribute('aria-expanded', String(section.expanded));
  }
  if (section.items.length === 0) {
    renderEmpty(area, emptyTitle, '마음에 드는 곳을 저장해 보세요');
    return;
  }
  if (filtered.length === 0) {
    renderEmpty(area, '검색 결과가 없어요', '다른 검색어로 찾아보세요');
    return;
  }
  area.replaceChildren(...(showAll ? filtered : filtered.slice(0, PREVIEW_COUNT)).map(createCard));
}

function renderRestaurants(): void {
  renderSection(restaurants, restaurantArea, restaurantCount, restaurantToggle, '곳', '저장한 가게가 없어요', (r) => matches(query, r.name, r.brandName), createRestaurantCard);
}

function renderMenus(): void {
  renderSection(menus, menuArea, menuCount, menuToggle, '개', '저장한 메뉴가 없어요', (m) => matches(query, m.name, m.brandName), createMenuCard);
}

async function loadRestaurants(): Promise<void> {
  if (!restaurantArea) return;
  renderLoading(restaurantArea);
  try {
    restaurants.items = await getSavedRestaurants();
    restaurants.loaded = true;
    renderRestaurants();
  } catch (e) {
    renderError(restaurantArea, e instanceof Error ? e.message : '저장한 가게를 불러오지 못했어요', () => void loadRestaurants());
  }
}

async function loadMenus(): Promise<void> {
  if (!menuArea) return;
  renderLoading(menuArea);
  try {
    menus.items = await getSavedMenus();
    menus.loaded = true;
    renderMenus();
  } catch (e) {
    renderError(menuArea, e instanceof Error ? e.message : '저장한 메뉴를 불러오지 못했어요', () => void loadMenus());
  }
}

async function loadProfile(): Promise<void> {
  const userText = qs('#user-text');
  try {
    const profile = await getMyProfile();
    myRegion = profile?.region ?? null;
    if (userText && profile) userText.textContent = `${profile.nickname}님`;
  } catch {
    // 닉네임·지역을 못 읽어도 목록은 보여준다 (메뉴 이동 시 지점이 없다는 안내가 나온다)
  }
}

async function start(): Promise<void> {
  if (!(await requireAuth())) return;
  qs('#app')?.append(renderBottomNav('save'));
  searchForm?.addEventListener('submit', (event) => event.preventDefault());
  searchInput?.addEventListener('input', () => {
    query = searchInput.value;
    renderRestaurants();
    renderMenus();
  });
  restaurantToggle?.addEventListener('click', () => {
    restaurants.expanded = !restaurants.expanded;
    renderRestaurants();
  });
  menuToggle?.addEventListener('click', () => {
    menus.expanded = !menus.expanded;
    renderMenus();
  });
  await Promise.all([loadProfile(), loadRestaurants(), loadMenus()]);
}

void start();

// 다른 화면에서 저장을 바꾸고 뒤로 가기로 돌아오면(bfcache) 목록이 낡아 있으므로 새로 불러온다
window.addEventListener('pageshow', (event) => {
  if (event.persisted) window.location.reload();
});
