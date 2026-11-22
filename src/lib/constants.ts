// 앱 전역 상수. 아이디 → 이메일 변환은 이 파일(toEmail) 한 곳에서만 한다.
export const FAKE_EMAIL_DOMAIN = 'tmate-app.com';

export const USERNAME_PATTERN = /^[a-z0-9_]{4,20}$/;
export const USERNAME_MIN_LENGTH = 4;
export const USERNAME_MAX_LENGTH = 20;
export const PASSWORD_MIN_LENGTH = 6;

/** 페이지 이동 경로. 아직 없는 페이지는 경로만 정해 둔다. */
export const PATHS = {
  splash: '/index.html',
  login: '/src/pages/login.html',
  signup: '/src/pages/signup.html',
  onboardingStart: '/src/pages/onboarding-location.html', // 아직 없음
  home: '/src/pages/home.html', // 아직 없음
} as const;

export function toEmail(username: string): string {
  return `${username}@${FAKE_EMAIL_DOMAIN}`;
}
