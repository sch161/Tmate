// 가게 추가: 목록에 없는 가게와 메뉴를 사용자가 직접 넣는다. 알레르기·맛은 서버(Edge Function)에서 AI 가 메뉴 이름으로 추정한다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 가게 추가 화면이 없다)
import { getMyProfile } from '../api/auth';
import { getFoodCategories, type FoodCategory } from '../api/lookups';
import { addStore, MENU_NAME_MAX_LENGTH, STORE_MENU_MAX, STORE_NAME_MAX_LENGTH } from '../api/stores';
import { PATHS } from '../lib/constants';
import { requireAuth } from '../utils/auth-guard';
import { el, qs, showToast } from '../utils/dom';
import { goBack } from '../utils/navigation';
import { pickRegion } from '../utils/region-picker';
import { renderError, renderLoading } from '../utils/state-views';

const LEAVE_DELAY_MS = 900;
const ADDRESS_MAX_LENGTH = 100;

const body = qs<HTMLElement>('#body');
const backButton = qs<HTMLButtonElement>('#back');

function renderForm(categories: FoodCategory[], initialRegion: string): void {
  if (!body) return;
  let region = initialRegion;
  let categoryId: number | null = null;
  let busy = false;

  const name = el('input', { class: 'input', id: 'store-name', type: 'text', maxlength: String(STORE_NAME_MAX_LENGTH), autocomplete: 'off', placeholder: '예: 구로 할매칼국수' });
  const address = el('input', { class: 'input', id: 'store-address', type: 'text', maxlength: String(ADDRESS_MAX_LENGTH), autocomplete: 'off', placeholder: '예: 구로동 123 (안 적어도 돼요)' });
  const regionText = el('span', { class: 'store-add__region-text' }, region || '지역을 골라주세요');
  const regionButton = el('button', { class: 'store-add__region', id: 'store-region', type: 'button' }, regionText, el('span', { class: 'store-add__region-change' }, '바꾸기'));
  const categoryGroup = el('div', { class: 'chip-group', role: 'group', 'aria-label': '음식 종류' });
  const menuList = el('div', { class: 'store-add__menus' });
  const addMenuButton = el('button', { class: 'store-add__add-menu', type: 'button' }, '+ 메뉴 추가');
  const error = el('p', { class: 'error-message', role: 'alert' });
  error.hidden = true;
  const submitButton = el('button', { class: 'btn-primary', id: 'submit', type: 'button', disabled: true }, '가게 추가하기');
  const progress = el('p', { class: 'store-add__progress text-wrap-ko', role: 'status' });
  progress.hidden = true;

  const menuNames = (): string[] => [...menuList.querySelectorAll<HTMLInputElement>('.store-add__menu-name')].map((input) => input.value.trim());
  const filledMenus = (): { name: string; description: string }[] =>
    [...menuList.querySelectorAll<HTMLElement>('.store-add__menu')]
      .map((row) => ({
        name: row.querySelector<HTMLInputElement>('.store-add__menu-name')?.value.trim() ?? '',
        description: row.querySelector<HTMLInputElement>('.store-add__menu-desc')?.value.trim() ?? '',
      }))
      .filter((menu) => menu.name !== '');

  /** 입력이 모자라면 그 이유, 다 찼으면 null */
  const missing = (): string | null => {
    if (name.value.trim().length < 2) return '가게 이름을 2자 이상 입력해주세요';
    if (!region) return '지역을 골라주세요';
    if (categoryId === null) return '음식 종류를 골라주세요';
    const names = menuNames().filter((value) => value !== '');
    if (names.length === 0) return '메뉴를 1개 이상 입력해주세요';
    if (new Set(names.map((value) => value.replace(/\s+/g, '').toLowerCase())).size !== names.length) return '같은 메뉴가 두 번 들어 있어요';
    return null;
  };

  const sync = (): void => {
    const rows = menuList.querySelectorAll('.store-add__menu').length;
    addMenuButton.hidden = rows >= STORE_MENU_MAX;
    menuList.querySelectorAll<HTMLButtonElement>('.store-add__menu-remove').forEach((button) => {
      button.hidden = rows <= 1;
    });
    submitButton.disabled = busy || missing() !== null;
  };
  const clearError = (): void => {
    error.hidden = true;
    error.textContent = '';
    sync();
  };

  const addMenuRow = (): void => {
    const menuName = el('input', { class: 'input store-add__menu-name', type: 'text', maxlength: String(MENU_NAME_MAX_LENGTH), autocomplete: 'off', placeholder: '메뉴 이름 (예: 바지락칼국수)', 'aria-label': '메뉴 이름' });
    const menuDesc = el('input', { class: 'input store-add__menu-desc', type: 'text', maxlength: '100', autocomplete: 'off', placeholder: '재료나 설명 (안 적어도 돼요)', 'aria-label': '메뉴 설명' });
    const remove = el('button', { class: 'store-add__menu-remove', type: 'button', 'aria-label': '이 메뉴 빼기' }, '빼기');
    const row = el('div', { class: 'store-add__menu' }, el('div', { class: 'store-add__menu-fields' }, menuName, menuDesc), remove);
    remove.addEventListener('click', () => {
      row.remove();
      clearError();
    });
    menuName.addEventListener('input', clearError);
    menuList.append(row);
    sync();
  };

  const renderCategories = (): void => {
    categoryGroup.replaceChildren(
      ...categories.map((category) => {
        const active = category.id === categoryId;
        const chip = el('button', { class: active ? 'chip chip--filter is-active' : 'chip chip--filter', type: 'button', 'aria-pressed': String(active) }, category.name);
        chip.addEventListener('click', () => {
          categoryId = category.id;
          renderCategories();
          clearError();
        });
        return chip;
      }),
    );
  };

  const setBusy = (value: boolean): void => {
    busy = value;
    submitButton.textContent = value ? '추가하는 중...' : '가게 추가하기';
    progress.hidden = !value;
    progress.textContent = value ? 'AI가 메뉴의 알레르기와 맛을 살펴보고 있어요. 10초쯤 걸려요' : '';
    for (const control of body.querySelectorAll<HTMLInputElement | HTMLButtonElement>('input, button')) {
      if (control !== submitButton) control.disabled = value;
    }
    sync();
  };

  const submit = async (): Promise<void> => {
    if (busy) return;
    const problem = missing();
    if (problem || categoryId === null) {
      error.textContent = problem ?? '';
      error.hidden = false;
      return;
    }
    clearError();
    setBusy(true);
    try {
      const added = await addStore({ name: name.value.trim(), region, address: address.value.trim(), categoryId, menus: filledMenus() });
      showToast(added.unknownMenus.length > 0 ? '가게를 추가했어요. 일부 메뉴는 알레르기 정보가 없어요' : '가게를 추가했어요');
      window.setTimeout(() => window.location.replace(`${PATHS.restaurant}?id=${added.restaurantId}`), LEAVE_DELAY_MS);
    } catch (e) {
      setBusy(false);
      error.textContent = e instanceof Error ? e.message : '가게를 추가하지 못했어요. 잠시 후 다시 시도해주세요';
      error.hidden = false;
    }
  };

  name.addEventListener('input', clearError);
  regionButton.addEventListener('click', () => {
    void pickRegion({ current: region || null }).then((picked) => {
      if (!picked) return;
      region = picked;
      regionText.textContent = picked;
      clearError();
    });
  });
  addMenuButton.addEventListener('click', () => {
    addMenuRow();
    menuList.querySelector<HTMLInputElement>('.store-add__menu:last-child .store-add__menu-name')?.focus();
  });
  submitButton.addEventListener('click', () => void submit());

  const field = (label: string, control: HTMLElement, forId?: string): HTMLElement =>
    el('div', { class: 'store-add__field' }, forId ? el('label', { class: 'store-add__label', for: forId }, label) : el('p', { class: 'store-add__label' }, label), control);

  body.replaceChildren(
    el(
      'div',
      { class: 'store-add__form' },
      el('p', { class: 'store-add__notice text-wrap-ko' }, '알레르기 정보는 AI가 메뉴 이름으로 추정해요. 정확하지 않을 수 있어서 "추정"으로 표시되고, 알레르기를 등록한 분께는 추천되지 않아요.'),
      field('가게 이름', name, 'store-name'),
      field('지역', regionButton),
      field('주소', address, 'store-address'),
      field('음식 종류', categoryGroup),
      el('div', { class: 'store-add__field' }, el('p', { class: 'store-add__label' }, `메뉴 (최대 ${STORE_MENU_MAX}개)`), menuList, addMenuButton),
      error,
      progress,
      submitButton,
    ),
  );
  renderCategories();
  addMenuRow();
}

async function load(): Promise<void> {
  if (!body) return;
  renderLoading(body);
  try {
    const [categories, profile] = await Promise.all([getFoodCategories(), getMyProfile()]);
    // 홈에서 보던 지역(?region=)을 우선 쓰고, 없으면 내 지역을 쓴다. 저장할 때 서버가 지역을 다시 확인한다
    const fromQuery = new URLSearchParams(window.location.search).get('region')?.trim() ?? '';
    renderForm(categories, fromQuery || profile?.region || '');
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '화면을 불러오지 못했어요', () => void load());
  }
}

async function start(): Promise<void> {
  backButton?.addEventListener('click', () => goBack(PATHS.home));
  if (!(await requireAuth())) return;
  await load();
}

void start();
