import { getSession, getMyProfile } from '../api/auth';
import { PATHS } from '../lib/constants';
import { el, qs } from '../utils/dom';

const SPLASH_MS = 1200;

async function route(): Promise<string> {
  const session = await getSession();
  if (!session) return PATHS.signup;
  const profile = await getMyProfile();
  return profile?.onboarding_done ? PATHS.home : PATHS.onboardingStart;
}

// 개발 서버는 없는 페이지 요청에 index.html 을 대신 내준다.
// 그 상태에서 분기하면 아직 없는 경로로 계속 이동하는 루프가 생기므로, 안내만 보여주고 멈춘다.
function isSplashPath(): boolean {
  return window.location.pathname === '/' || window.location.pathname === PATHS.splash;
}

function showMissingPage(): void {
  const main = qs<HTMLElement>('main');
  if (!main) return;
  main.replaceChildren(
    el('div', { class: 'empty-state' }, el('p', { class: 'empty-state__title' }, '아직 만들어지지 않은 페이지예요')),
    el('p', { class: 'auth__switch' }, el('a', { href: PATHS.home }, '홈으로 돌아가기')),
  );
}

async function start(): Promise<void> {
  const wait = new Promise<void>((r) => window.setTimeout(r, SPLASH_MS));
  let target: string = PATHS.signup;
  try {
    target = await route();
  } catch (e) {
    // 확인에 실패하면 시작 화면으로 보내되, 잠깐 이유를 보여준다
    const msg = qs<HTMLElement>('#splash-error');
    if (msg) {
      msg.textContent = e instanceof Error ? e.message : '문제가 발생했어요';
      msg.hidden = false;
    }
  }
  await wait;
  window.location.replace(target);
}

if (isSplashPath()) void start();
else showMissingPage();
