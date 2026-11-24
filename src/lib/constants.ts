// 앱 전역 상수. 아이디 → 이메일 변환은 이 파일(toEmail) 한 곳에서만 한다.
export const FAKE_EMAIL_DOMAIN = 'tmate-app.com';

export const USERNAME_PATTERN = /^[a-z0-9_]{4,20}$/;
export const USERNAME_MIN_LENGTH = 4;
export const USERNAME_MAX_LENGTH = 20;
export const PASSWORD_MIN_LENGTH = 6;

/** 온보딩 규칙 */
export const MAX_TASTE_SELECTION = 3;

/** 페이지 이동 경로. 아직 없는 페이지는 경로만 정해 둔다. */
export const PATHS = {
  splash: '/index.html',
  login: '/src/pages/login.html',
  signup: '/src/pages/signup.html',
  onboardingStart: '/src/pages/onboarding-location.html',
  onboardingFlavor: '/src/pages/onboarding-flavor.html',
  onboardingRatio: '/src/pages/onboarding-ratio.html',
  onboardingAllergy: '/src/pages/onboarding-allergy.html',
  home: '/src/pages/home.html',
  save: '/src/pages/save.html',
  mypage: '/src/pages/mypage.html',
  restaurant: '/src/pages/restaurant.html', // 아직 없음 (?id=가게id)
  tasteEdit: '/src/pages/taste-edit.html',
  review: '/src/pages/review.html', // ?menuId=메뉴id&restaurantId=지점id(선택, 돌아가기용)
  allergyEdit: '/src/pages/allergy-edit.html',
  tasteDetail: '/src/pages/taste-detail.html',
  myReviews: '/src/pages/my-reviews.html',
  tasteMates: '/src/pages/taste-mates.html',
  profileEdit: '/src/pages/profile-edit.html',
  match: '/src/pages/match.html', // 친구랑 궁합 검사 (?room=방번호)
  matchRank: '/src/pages/match-rank.html', // 맛궁합 랭킹 (부스 큰 화면용)
} as const;

export function toEmail(username: string): string {
  return `${username}@${FAKE_EMAIL_DOMAIN}`;
}
