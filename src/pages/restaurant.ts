// 가게(지점) 상세: 메뉴별 평가 탭(Figma Details_s 1:329) + 알레르기 정보 탭(Details_m 1:453)
// 메뉴·알레르기·평점은 소속 브랜드 기준이라 같은 브랜드의 지점은 같은 값을 보여준다.
import { getMyProfile } from '../api/auth';
import { getMyAllergenCount } from '../api/me';
import {
  getAllergyMenus,
  getRestaurantDetail,
  getRestaurantMenus,
  getSavedMenuIds,
  toggleSaveMenu,
  type AllergenItem,
  type AllergyMenu,
  type RestaurantDetail,
  type RestaurantMenu,
} from '../api/restaurants';
import mascotImage from '../assets/images/allergy-mascot.png';
import { PATHS } from '../lib/constants';
import { getAllergenStatusInfo } from '../utils/allergen-status';
import { requireAuth } from '../utils/auth-guard';
import { el, qs, showToast } from '../utils/dom';
import { createImage } from '../utils/image';
import { splitSharedNotice } from '../utils/notice';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';
import { safeHttpUrl } from '../utils/url';

type TabKey = 'menus' | 'allergy';

/** 알레르기 탭 데이터. count 는 내가 등록한 알레르기 수(0 이면 등록 안 함) */
interface AllergyTabData {
  nickname: string;
  count: number;
  conflicts: AllergyMenu[];
  unknowns: AllergyMenu[];
}

const detailArea = qs('#detail-area');
const backButton = qs<HTMLButtonElement>('#back');

let restaurantId = 0;
let currentDetail: RestaurantDetail | null = null;
let activeTab: TabKey = 'menus';
let panel: HTMLElement | null = null;
let panelSeq = 0;
// 탭 데이터는 한 번 불러오면 재사용한다
let menusCache: RestaurantMenu[] | null = null;
let allergyCache: AllergyTabData | null = null;
// 메뉴 저장 상태(메뉴 id → 저장 여부). 두 탭이 같은 값을 보도록 페이지 전체에서 공유한다
const savedMenus = new Map<number, boolean>();
const savingMenus = new Set<number>();

const NOTICE_VISIBLE = 5;

const STATUS_NOTICES = {
  reference: '알레르기 정보는 참고용이에요. 먹기 전에 가게에 꼭 확인하세요',
  branch: '지점에 따라 판매하지 않는 제품이 있을 수 있어요',
} as const;

function parseId(): number | null {
  const raw = new URLSearchParams(window.location.search).get('id');
  return raw !== null && /^[1-9]\d{0,15}$/.test(raw) ? Number(raw) : null;
}

function goBack(): void {
  if (window.history.length > 1) window.history.back();
  else window.location.href = PATHS.home;
}

function homeLink(): HTMLElement {
  return el('a', { class: 'restaurant__home-link', href: PATHS.home }, '홈으로');
}

function ratingText(avg: number): string {
  return `${avg.toFixed(1)} / 5`;
}

function clampPercent(value: number): number {
  return Math.min(100, Math.max(0, value));
}

/** 막대 + 값. value 는 0~100 */
function createMeter(kind: 'rating' | 'match', value: number, label: string): HTMLElement {
  const bar = el('div', { class: 'meter__bar' });
  bar.style.setProperty('--value', String(clampPercent(value)));
  return el('div', { class: kind === 'rating' ? 'meter meter--rating' : 'meter' }, bar, el('span', {}, label));
}

// ---------- 저장 버튼 (낙관적 업데이트) ----------

function setSaveState(button: HTMLButtonElement, saved: boolean): void {
  button.classList.toggle('is-saved', saved);
  button.setAttribute('aria-pressed', String(saved));
  button.setAttribute('aria-label', saved ? '메뉴 저장 해제' : '메뉴 저장');
}

function createSaveButton(menuId: number): HTMLButtonElement {
  const button = el('button', { class: 'save-button', type: 'button' });
  setSaveState(button, savedMenus.get(menuId) ?? false);
  button.addEventListener('click', () => void onToggleSave(menuId, button));
  return button;
}

async function onToggleSave(menuId: number, button: HTMLButtonElement): Promise<void> {
  if (savingMenus.has(menuId)) return;
  savingMenus.add(menuId);
  button.disabled = true;
  const next = !(savedMenus.get(menuId) ?? false);
  savedMenus.set(menuId, next);
  setSaveState(button, next);
  try {
    await toggleSaveMenu(menuId, next);
  } catch (e) {
    savedMenus.set(menuId, !next);
    setSaveState(button, !next);
    showToast(e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요');
  } finally {
    savingMenus.delete(menuId);
    button.disabled = false;
  }
}

// ---------- 상단 가게 정보 ----------

function renderDetail(detail: RestaurantDetail): void {
  if (!detailArea) return;
  document.title = `${detail.name} - T:MATE`;

  const lines: HTMLElement[] = [
    el('h1', { class: 'restaurant__name' }, detail.name),
    el('p', { class: 'restaurant__line restaurant__line--place text-wrap-ko' }, detail.address),
  ];
  if (detail.phone) {
    // 전화번호가 없으면 줄 자체를 만들지 않는다. tel: 링크에는 숫자·+·- 만 허용한다
    const dial = detail.phone.replace(/[^0-9+\-]/g, '');
    const phone = dial ? el('a', { href: `tel:${dial}` }, detail.phone) : el('span', {}, detail.phone);
    lines.push(el('p', { class: 'restaurant__line restaurant__line--phone text-wrap-ko' }, phone));
  }

  const rating =
    detail.avgRating === null
      ? el('p', { class: 'restaurant__no-rating' }, '아직 평가가 없어요')
      : createMeter('rating', (detail.avgRating / 5) * 100, ratingText(detail.avgRating));
  rating.classList.add('restaurant__rating');
  const matchText = detail.matchPercent === null ? null : `취향 일치도 ${Math.round(detail.matchPercent)}%`;

  const intro = el('div', { class: 'restaurant__intro' });
  if (detail.reason) intro.append(el('p', { class: 'restaurant__reason text-wrap-ko' }, detail.reason));
  intro.append(el('div', { class: 'restaurant__score' }, rating, ...(matchText ? [el('p', { class: 'restaurant__match' }, matchText)] : [])));

  const tabs = el('div', { class: 'tabs', role: 'tablist' });
  const tabDefs: { key: TabKey; label: string }[] = [
    { key: 'menus', label: '메뉴별 평가' },
    { key: 'allergy', label: '알레르기 정보' },
  ];
  const tabButtons = new Map<TabKey, HTMLButtonElement>();
  for (const def of tabDefs) {
    const button = el('button', { class: 'tab', type: 'button', role: 'tab', id: `tab-${def.key}` }, def.label);
    button.addEventListener('click', () => selectTab(def.key, tabButtons));
    tabButtons.set(def.key, button);
    tabs.append(button);
  }
  panel = el('div', { class: 'restaurant__panel', role: 'tabpanel' });

  detailArea.replaceChildren(
    createImage(detail.imageUrl, 'restaurant__hero'),
    el('section', { class: 'restaurant__info' }, el('div', { class: 'restaurant__lines' }, ...lines), intro),
    tabs,
    panel,
  );
  selectTab('menus', tabButtons);
}

function selectTab(tab: TabKey, buttons: Map<TabKey, HTMLButtonElement>): void {
  activeTab = tab;
  for (const [key, button] of buttons) {
    const active = key === tab;
    button.classList.toggle('is-active', active);
    button.setAttribute('aria-selected', String(active));
  }
  panel?.setAttribute('aria-labelledby', `tab-${tab}`);
  void (tab === 'menus' ? loadMenusTab() : loadAllergyTab());
}

// ---------- 탭 1: 메뉴별 평가 ----------

function createMenuCard(menu: RestaurantMenu): HTMLElement {
  const info = el('div', { class: 'menu-card__info' }, el('p', { class: 'menu-card__name' }, menu.name));
  if (menu.matchPercent !== null) info.append(createMeter('match', menu.matchPercent, `${Math.round(menu.matchPercent)}%`));
  if (menu.tasteTags.length > 0) {
    const tags = el('div', { class: 'menu-card__tags' });
    menu.tasteTags.forEach((tag, index) => tags.append(el('span', { class: index === 0 ? 'chip is-active' : 'chip' }, tag)));
    info.append(tags);
  }
  if (menu.description) info.append(el('p', { class: 'menu-card__desc text-wrap-ko' }, menu.description));

  const foot = el('div', { class: 'menu-card__foot' });
  // 평가하기 링크: 평가 작성 화면(review.html)으로 이동한다
  foot.append(el('a', { class: 'menu-card__review', href: `${PATHS.review}?menuId=${encodeURIComponent(String(menu.menuId))}&restaurantId=${encodeURIComponent(String(restaurantId))}` }, '평가하기'));
  if (menu.myRating !== null) foot.append(el('span', { class: 'menu-card__my-rating' }, `내 별점 ${menu.myRating}점`));
  info.append(foot);

  return el('article', { class: 'menu-card' }, createImage(menu.imageUrl, 'menu-card__image'), info, createSaveButton(menu.menuId));
}

function renderMenus(menus: RestaurantMenu[]): void {
  if (!panel) return;
  if (menus.length === 0) {
    renderEmpty(panel, '등록된 메뉴가 아직 없어요', '메뉴 정보가 준비되면 보여드릴게요');
    return;
  }
  // 디자인 대기: 안내 문구와 출처 줄은 Figma 에 없는 임시 UI
  const content = el('div', { class: 'restaurant__list' }, el('p', { class: 'restaurant__hint text-wrap-ko' }, '맛 태그는 추정값이에요'));
  for (const menu of menus) content.append(createMenuCard(menu));

  const sources = new Map<string, string | null>();
  for (const menu of menus) {
    if (menu.menuSourceName && !sources.has(menu.menuSourceName)) sources.set(menu.menuSourceName, safeHttpUrl(menu.menuSourceUrl));
  }
  if (sources.size > 0) {
    const line = el('p', { class: 'restaurant__source text-wrap-ko' }, '메뉴 정보 출처: ');
    let first = true;
    for (const [name, url] of sources) {
      if (!first) line.append(', ');
      first = false;
      line.append(url ? el('a', { href: url, target: '_blank', rel: 'noopener noreferrer' }, name) : name);
    }
    content.append(line);
  }
  panel.replaceChildren(content);
}

async function loadMenusTab(): Promise<void> {
  if (!panel) return;
  const seq = ++panelSeq;
  if (menusCache) {
    renderMenus(menusCache);
    return;
  }
  renderLoading(panel);
  try {
    const menus = await getRestaurantMenus(restaurantId);
    menusCache = menus;
    for (const menu of menus) savedMenus.set(menu.menuId, menu.isSaved);
    if (seq === panelSeq && activeTab === 'menus') renderMenus(menus);
  } catch (e) {
    if (seq === panelSeq && panel) renderError(panel, e instanceof Error ? e.message : '메뉴를 불러오지 못했어요', () => void loadMenusTab());
  }
}

// ---------- 탭 2: 알레르기 정보 ----------

const LEVEL_LABEL: Record<AllergenItem['level'], string> = { danger: '위험', caution: '주의' };

function createStatusLabel(status: RestaurantMenu['allergenStatus']): HTMLElement {
  const info = getAllergenStatusInfo(status);
  return el('p', { class: info.unverified ? 'status-label status-label--unverified text-wrap-ko' : 'status-label text-wrap-ko' }, info.label);
}

/** 브랜드 안내 영역: 알레르기가 없든 있든, 결과가 없든 있든 항상 보인다 (디자인 대기: 임시 UI) */
function createNotice(detail: RestaurantDetail): HTMLElement {
  const notice = el('section', { class: 'allergy-notice text-wrap-ko', 'aria-label': '알레르기 정보 안내' });
  const list = el('ul', { class: 'allergy-notice__list' });
  list.append(el('li', {}, STATUS_NOTICES.reference), el('li', {}, STATUS_NOTICES.branch));
  // 공지 조각이 많으면 처음 NOTICE_VISIBLE 개만 보이고 "더보기"로 펼친다
  const parts = splitSharedNotice(detail.sharedNotice);
  const extra: HTMLElement[] = [];
  parts.forEach((part, index) => {
    const item = el('li', {}, part);
    if (index >= NOTICE_VISIBLE) {
      item.hidden = true;
      extra.push(item);
    }
    list.append(item);
  });
  list.append(el('li', {}, detail.allergenDataDate ? `공식 표 기준일: ${detail.allergenDataDate}` : '확인 시점 정보 없음'));
  notice.append(list);
  if (extra.length > 0) {
    const more = el('button', { class: 'allergy-notice__more', type: 'button', 'aria-expanded': 'false' }, `더보기 (${extra.length})`);
    more.addEventListener('click', () => {
      for (const item of extra) item.hidden = false;
      more.remove();
    });
    notice.append(more);
  }
  const sourceUrl = safeHttpUrl(detail.allergenSourceUrl);
  if (sourceUrl) {
    notice.append(el('a', { class: 'allergy-notice__source', href: sourceUrl, target: '_blank', rel: 'noopener noreferrer' }, '공식 출처 보기'));
  }
  return notice;
}

function createAllergyCard(menu: AllergyMenu): HTMLElement {
  const info = el('div', { class: 'menu-card__info' }, el('p', { class: 'menu-card__name' }, menu.name));
  if (menu.kind === 'conflict') {
    const chips = el('div', { class: 'menu-card__tags' });
    for (const item of menu.allergens) {
      chips.append(el('span', { class: item.level === 'danger' ? 'chip is-active' : 'chip' }, `${LEVEL_LABEL[item.level]} ${item.name}`));
    }
    info.append(chips);
    const originals = menu.allergens.filter((item) => item.originalText && item.originalText !== item.name);
    if (originals.length > 0) {
      info.append(el('p', { class: 'menu-card__desc text-wrap-ko' }, `공식 표기: ${originals.map((item) => item.originalText).join(', ')}`));
    }
  } else {
    // 디자인 대기: "정보 없음" 칩은 위험 칩과 구분되는 중립 색
    info.append(el('span', { class: 'chip chip--neutral' }, '정보 없음'), el('p', { class: 'menu-card__desc text-wrap-ko' }, '알레르기 정보가 없어요. 가게에 확인하세요'));
  }
  info.append(createStatusLabel(menu.allergenStatus));
  return el('article', { class: 'menu-card menu-card--allergy' }, createImage(menu.imageUrl, 'menu-card__image'), info, createSaveButton(menu.menuId));
}

function createGroup(title: string, hint: string | null, menus: AllergyMenu[]): HTMLElement {
  const group = el('section', { class: 'allergy-group' }, el('h2', { class: 'allergy-group__title' }, title));
  if (hint) group.append(el('p', { class: 'restaurant__hint text-wrap-ko' }, hint));
  group.append(el('div', { class: 'restaurant__list' }, ...menus.map(createAllergyCard)));
  return group;
}

/** 알레르기를 등록하지 않은 경우: 등록 안내 + 브랜드 메뉴의 상태 라벨 */
function createNoAllergyView(menus: RestaurantMenu[]): HTMLElement {
  const view = el('div', { class: 'allergy-group' });
  view.append(
    el(
      'div',
      { class: 'allergy-register text-wrap-ko' },
      el('p', {}, '알레르기를 등록하면 피해야 할 메뉴를 알려드려요'),
      // 알레르기 등록 링크: 알레르기 수정 화면(allergy-edit.html)으로 이동한다
      el('a', { href: PATHS.allergyEdit }, '알레르기 등록하기'),
    ),
  );
  if (menus.length > 0) {
    const list = el('ul', { class: 'allergy-status-list text-wrap-ko' });
    for (const menu of menus) list.append(el('li', {}, el('span', { class: 'allergy-status-list__name' }, menu.name), createStatusLabel(menu.allergenStatus)));
    view.append(el('h2', { class: 'allergy-group__title' }, '메뉴별 알레르기 정보 상태'), list);
  }
  return view;
}

function renderAllergy(detail: RestaurantDetail, data: AllergyTabData, menus: RestaurantMenu[] | null): void {
  if (!panel) return;
  // 디자인 대기: 말풍선 문구와 마스코트는 Figma Details_m 그대로
  const mascot = el('div', { class: 'allergy-head__mascot', 'aria-hidden': 'true' }, el('img', { src: mascotImage, alt: '' }));
  const head = el('div', { class: 'allergy-head' }, el('p', { class: 'allergy-head__bubble text-wrap-ko' }, `${data.nickname}님이 피해야 할 음식을 알려드려요`), mascot);
  const body = el('div', { class: 'restaurant__allergy' }, head, createNotice(detail));

  if (data.count === 0) {
    body.append(createNoAllergyView(menus ?? []));
  } else if (data.conflicts.length === 0 && data.unknowns.length === 0) {
    body.append(el('div', { class: 'empty-state' }, el('p', { class: 'empty-state__title' }, '내 알레르기와 겹치는 메뉴가 없어요')));
  } else {
    if (data.conflicts.length > 0) body.append(createGroup('내 알레르기와 겹치는 메뉴', null, data.conflicts));
    if (data.unknowns.length > 0) {
      body.append(createGroup('알레르기 정보가 없는 메뉴', '"정보 없음"은 "알레르기 없음"이 아니에요. 먹기 전에 가게에 확인하세요', data.unknowns));
    }
  }
  panel.replaceChildren(body);
}

async function loadAllergyData(): Promise<AllergyTabData> {
  const [profile, count] = await Promise.all([getMyProfile(), getMyAllergenCount()]);
  const nickname = profile?.nickname ?? '회원';
  if (count === 0) return { nickname, count, conflicts: [], unknowns: [] };
  const menus = await getAllergyMenus(restaurantId);
  // 저장 버튼 초기 상태: get_allergy_menus 는 저장 여부를 주지 않으므로 따로 조회한다 (이미 아는 메뉴는 건드리지 않는다)
  const unknownIds = menus.map((menu) => menu.menuId).filter((id) => !savedMenus.has(id));
  if (unknownIds.length > 0) {
    const savedIds = await getSavedMenuIds(unknownIds);
    for (const id of unknownIds) savedMenus.set(id, savedIds.has(id));
  }
  return { nickname, count, conflicts: menus.filter((m) => m.kind === 'conflict'), unknowns: menus.filter((m) => m.kind === 'unknown') };
}

async function loadAllergyTab(): Promise<void> {
  if (!panel || !currentDetail) return;
  const seq = ++panelSeq;
  const detail = currentDetail;
  if (allergyCache && (allergyCache.count > 0 || menusCache)) {
    renderAllergy(detail, allergyCache, menusCache);
    return;
  }
  renderLoading(panel);
  try {
    const data = allergyCache ?? (await loadAllergyData());
    allergyCache = data;
    let menus = menusCache;
    if (data.count === 0 && !menus) {
      menus = await getRestaurantMenus(restaurantId);
      menusCache = menus;
      for (const menu of menus) savedMenus.set(menu.menuId, menu.isSaved);
    }
    if (seq === panelSeq && activeTab === 'allergy') renderAllergy(detail, data, menus);
  } catch (e) {
    if (seq === panelSeq && panel) renderError(panel, e instanceof Error ? e.message : '알레르기 정보를 불러오지 못했어요', () => void loadAllergyTab());
  }
}

// ---------- 시작 ----------

function renderDetailProblem(message: string, retry: (() => void) | null): void {
  if (!detailArea) return;
  if (retry) renderError(detailArea, message, retry);
  else renderEmpty(detailArea, message, '홈에서 다른 맛집을 찾아보세요');
  detailArea.append(homeLink());
}

async function loadDetail(): Promise<void> {
  if (!detailArea) return;
  renderLoading(detailArea);
  try {
    const detail = await getRestaurantDetail(restaurantId);
    if (!detail) {
      renderDetailProblem('찾을 수 없는 가게예요', null);
      return;
    }
    currentDetail = detail;
    renderDetail(detail);
  } catch (e) {
    renderDetailProblem(e instanceof Error ? e.message : '가게 정보를 불러오지 못했어요', () => void loadDetail());
  }
}

async function start(): Promise<void> {
  backButton?.addEventListener('click', goBack);
  if (!(await requireAuth())) return;
  const id = parseId();
  if (id === null) {
    renderDetailProblem('찾을 수 없는 가게예요', null);
    return;
  }
  restaurantId = id;
  await loadDetail();
}

// 평가 화면에서 뒤로 가기로 돌아오면(bfcache) 평점·내 별점이 낡아 있으므로 새로 불러온다
window.addEventListener('pageshow', (event) => {
  if (event.persisted) window.location.reload();
});

void start();
