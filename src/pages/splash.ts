import { getSession, getMyProfile } from '../api/auth';
import { PATHS } from '../lib/constants';
import { qs } from '../utils/dom';

const SPLASH_MS = 1200;

async function route(): Promise<string> {
  const session = await getSession();
  if (!session) return PATHS.login;
  const profile = await getMyProfile();
  return profile?.onboarding_done ? PATHS.home : PATHS.onboardingStart;
}

async function start(): Promise<void> {
  const wait = new Promise<void>((r) => window.setTimeout(r, SPLASH_MS));
  let target: string = PATHS.login;
  try {
    target = await route();
  } catch (e) {
    // 확인에 실패하면 로그인 화면으로 보내되, 잠깐 이유를 보여준다
    const msg = qs<HTMLElement>('#splash-error');
    if (msg) {
      msg.textContent = e instanceof Error ? e.message : '문제가 발생했어요';
      msg.hidden = false;
    }
  }
  await wait;
  window.location.replace(target);
}

void start();
