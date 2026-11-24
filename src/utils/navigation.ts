// 수정 화면(알레르기·입맛·프로필)에서 저장하거나 뒤로갈 때 원래 있던 화면으로 돌려보내는 유틸.
// 수정 화면으로 갈 때 withReturnTo() 로 현재 주소를 returnTo 쿼리에 실어 보내고,
// 수정 화면은 goAfterSave() / goBack() 으로 그 주소(없거나 안전하지 않으면 기본값)로 이동한다.
import { PATHS } from '../lib/constants';

const RETURN_TO_PARAM = 'returnTo';

/** 같은 사이트 안의 상대 경로(/로 시작, //·\ 제외)만 통과시킨다. 아니면 null (오픈 리다이렉트 방지) */
export function sanitizeReturnTo(value: string | null | undefined): string | null {
  if (!value || !value.startsWith('/') || value.startsWith('//') || value.includes('\\')) return null;
  // 제어문자(탭·줄바꿈 등)는 브라우저가 지워 버려 /\t/evil.com 이 //evil.com 이 될 수 있으므로 막는다
  for (const ch of value) {
    if (ch.charCodeAt(0) < 0x20 || ch.charCodeAt(0) === 0x7f) return null;
  }
  try {
    const url = new URL(value, window.location.origin);
    if (url.origin !== window.location.origin) return null;
    return `${url.pathname}${url.search}${url.hash}`;
  } catch {
    return null;
  }
}

/** 이 화면을 돌아올 주소로 실어 `path` 로 가는 링크를 만든다 */
export function withReturnTo(path: string): string {
  const current = `${window.location.pathname}${window.location.search}`;
  return `${path}?${RETURN_TO_PARAM}=${encodeURIComponent(current)}`;
}

/** 현재 주소의 returnTo (안전한 값만, 없으면 null) */
export function getReturnTo(): string | null {
  return sanitizeReturnTo(new URLSearchParams(window.location.search).get(RETURN_TO_PARAM));
}

/** returnTo 가 있으면 거기로, 없으면 fallback 으로 이동한다 (히스토리에 수정 화면을 남기지 않는다) */
export function goAfterSave(fallback: string = PATHS.mypage): void {
  window.location.replace(getReturnTo() ?? fallback);
}

/** 뒤로가기 버튼. 저장 후 이동과 같은 곳으로 간다 */
export function goBack(fallback: string = PATHS.mypage): void {
  goAfterSave(fallback);
}
