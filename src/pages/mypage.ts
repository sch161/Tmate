// 마이페이지 (Figma User 1:716)
// 디자인 대기: 입맛 정보가 없을 때의 대체 카드는 Figma 에 없는 임시 UI
import { signOut } from '../api/auth';
import { getMySummary, updateMyRegion, type MySummary } from '../api/me';
import avatarImage from '../assets/images/mypage-avatar.png';
import { PATHS } from '../lib/constants';
import { requireAuth } from '../utils/auth-guard';
import { renderBottomNav } from '../utils/bottom-nav';
import { el, qs, showToast } from '../utils/dom';
import { withReturnTo } from '../utils/navigation';
import { pickRegion } from '../utils/region-picker';
import { renderError, renderLoading } from '../utils/state-views';

const FALLBACK_ERROR = '문제가 발생했어요. 잠시 후 다시 시도해주세요';
const MAX_RATIOS = 2;

const area = qs('#mypage-area');
const logoutButton = qs<HTMLButtonElement>('#logout');

const icon = (name: string, small = false): HTMLElement => el('span', { class: small ? `icon icon--sm icon--${name}` : `icon icon--${name}`, 'aria-hidden': 'true' });

// ---------- 프로필 + My Taste Type ----------

function createRatioBox(name: string, ratio: number): HTMLElement {
  const fill = el('div', { class: 'ratio-box__fill' });
  fill.style.setProperty('--value', String(ratio));
  return el(
    'div',
    { class: 'ratio-box' },
    el('p', { class: 'ratio-box__name' }, name),
    el('p', { class: 'ratio-box__value' }, `${Math.round(ratio)}%`),
    el('div', { class: 'ratio-box__track' }, fill),
  );
}

function createTypeCard(summary: MySummary): HTMLElement {
  // 비율 데이터가 없으면 카드를 안내로 대체한다
  if (summary.tasteRatios.length === 0) {
    return el('div', { class: 'type-card__empty text-wrap-ko' }, '입맛 정보를 등록해 주세요');
  }
  const info = el('div', { class: 'type-card__info' }, el('p', { class: 'type-card__label' }, 'My Taste Type'));
  if (summary.tasteTypeName) info.append(el('p', { class: 'type-card__name' }, summary.tasteTypeName));
  if (summary.tasteTypeDesc) info.append(el('p', { class: 'type-card__desc text-wrap-ko' }, summary.tasteTypeDesc));
  const ratios = el('div', { class: 'type-card__ratios' }, ...summary.tasteRatios.slice(0, MAX_RATIOS).map((r) => createRatioBox(r.name, r.ratio)));
  const more = el('a', { class: 'type-card__more', href: PATHS.tasteDetail }, '내 입맛 자세히 보기 >');
  return el('div', { class: 'type-card' }, info, ratios, more);
}

function createProfileCard(summary: MySummary): HTMLElement {
  const who = el('div', { class: 'profile-card__who' }, el('p', { class: 'profile-card__nickname' }, summary.nickname || '이름 없음'));
  if (summary.tasteTypeName) who.append(el('p', { class: 'profile-card__taste' }, summary.tasteTypeName));
  const head = el('div', { class: 'profile-card__head' }, el('img', { class: 'profile-card__avatar', src: avatarImage, alt: '', width: '70', height: '70' }), who);
  return el('section', { class: 'profile-card', 'aria-label': '내 프로필' }, head, createTypeCard(summary));
}

// ---------- 활동 / 내 기록 / 설정 ----------

function createActivity(summary: MySummary): HTMLElement {
  // 각 칸은 해당 목록 화면으로 이동한다
  const card = (iconName: string, count: number, label: string, href: string): HTMLElement =>
    el('a', { class: 'activity__card', href }, icon(iconName), el('p', { class: 'activity__count' }, String(count)), el('p', { class: 'activity__label' }, label));
  return el(
    'section',
    { class: 'mypage__section', 'aria-labelledby': 'activity-title' },
    el('div', { class: 'mypage__section-head' }, el('h2', { class: 'mypage__title', id: 'activity-title' }, '나의 맛집 활동'), el('a', { class: 'mypage__all', href: PATHS.save }, '전체보기>')),
    el(
      'div',
      { class: 'activity' },
      card('bookmark', summary.savedRestaurantCount, '저장한 맛집', PATHS.save),
      card('food', summary.reviewCount, '평가한 메뉴', PATHS.myReviews),
      card('users', summary.mateCount, '취향 메이트', PATHS.tasteMates),
    ),
  );
}

function createRecordRow(iconName: string, title: string, sub: string, href: string): HTMLElement {
  return el(
    'a',
    { class: 'row row--card', href },
    icon(iconName),
    el('div', { class: 'row__text' }, el('p', { class: 'row__title' }, title), el('p', { class: 'row__sub text-wrap-ko' }, sub)),
    el('span', { class: 'row__chevron', 'aria-hidden': 'true' }),
  );
}

function createSettingRow(iconName: string, title: string, href: string): HTMLElement {
  return el('a', { class: 'row row--setting', href }, icon(iconName, true), el('div', { class: 'row__text' }, el('p', { class: 'row__title' }, title)), el('span', { class: 'row__chevron', 'aria-hidden': 'true' }));
}

/** 내 주변 맛집 위치 설정: 새 페이지 없이 지역 선택 시트를 열고, 고르면 바로 profiles.region 을 바꾼다. */
function createLocationRow(summary: MySummary): HTMLElement {
  // 디자인 대기: 현재 지역을 줄 오른쪽에 작게 보여주는 것은 Figma 에 없는 임시 UI
  const value = el('span', { class: 'row__value' }, summary.region ?? '지역 미설정');
  const row = el(
    'button',
    { class: 'row row--setting row--button', type: 'button' },
    icon('location', true),
    el('div', { class: 'row__text' }, el('p', { class: 'row__title' }, '내 주변 맛집 위치 설정')),
    value,
    el('span', { class: 'row__chevron', 'aria-hidden': 'true' }),
  );
  row.addEventListener('click', async () => {
    if (row.disabled) return;
    row.disabled = true;
    try {
      const picked = await pickRegion({ current: summary.region });
      if (!picked || picked === summary.region) return;
      const previous = summary.region;
      // 낙관적 업데이트: 먼저 화면을 바꾸고 실패하면 되돌린다
      summary.region = picked;
      value.textContent = picked;
      try {
        await updateMyRegion(picked);
        showToast('지역을 바꿨어요');
      } catch (e) {
        summary.region = previous;
        value.textContent = previous ?? '지역 미설정';
        showToast(e instanceof Error ? e.message : FALLBACK_ERROR);
      }
    } finally {
      row.disabled = false;
    }
  });
  return row;
}

function createRecords(): HTMLElement {
  return el(
    'section',
    { class: 'mypage__section', 'aria-labelledby': 'records-title' },
    el('h2', { class: 'mypage__title', id: 'records-title' }, '내 기록'),
    el(
      'div',
      { class: 'row-list' },
      createRecordRow('bookmark', '저장한 맛집 · 메뉴', '다시 가고 싶은 곳을 모아봐요', PATHS.save),
      createRecordRow('food', '내가 평가한 메뉴', '별점과 맛 태그 기록을 확인해요', PATHS.myReviews),
      createRecordRow('users', '나의 취향 메이트', '나와 입맛이 비슷한 사람들', PATHS.tasteMates),
    ),
  );
}

function createSettings(summary: MySummary): HTMLElement {
  // 위치 설정은 페이지 없이 지역 선택 시트로 처리한다
  // Figma 의 "알림 설정" 줄은 이번 범위에서 제외한다 (나중에 PATHS.notificationSettings 와 함께 추가)
  return el(
    'section',
    { class: 'mypage__section', 'aria-labelledby': 'settings-title' },
    el('h2', { class: 'mypage__title', id: 'settings-title' }, '계정 및 취향 설정'),
    el(
      'div',
      { class: 'row-list row-list--box' },
      createSettingRow('user', '프로필 수정', withReturnTo(PATHS.profileEdit)),
      createSettingRow('sliders', '입맛 유형·선호도 수정', withReturnTo(PATHS.tasteEdit)),
      createSettingRow('protect', '알레르기 및 제외 식재료', withReturnTo(PATHS.allergyEdit)),
      createLocationRow(summary),
    ),
  );
}

// ---------- 로드 / 로그아웃 ----------

async function load(): Promise<void> {
  if (!area) return;
  renderLoading(area);
  try {
    const summary = await getMySummary();
    if (!summary) {
      renderError(area, '내 정보를 찾지 못했어요', () => void load());
      return;
    }
    area.replaceChildren(createProfileCard(summary), createActivity(summary), createRecords(), createSettings(summary));
  } catch (e) {
    renderError(area, e instanceof Error ? e.message : '내 정보를 불러오지 못했어요', () => void load());
  }
}

async function onLogout(): Promise<void> {
  if (!logoutButton || logoutButton.disabled) return;
  if (!window.confirm('로그아웃할까요?')) return;
  logoutButton.disabled = true;
  try {
    await signOut();
    window.location.replace(PATHS.login);
  } catch (e) {
    showToast(e instanceof Error ? e.message : FALLBACK_ERROR);
    logoutButton.disabled = false;
  }
}

async function start(): Promise<void> {
  if (!(await requireAuth())) return;
  qs('#app')?.append(renderBottomNav('mypage'));
  logoutButton?.addEventListener('click', () => void onLogout());
  await load();
}

void start();
