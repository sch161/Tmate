/** 고정 안내와 같은 뜻이라 공지 목록에서 뺄 조각의 키워드 */
const DUPLICATE_KEYWORD = '지점에 따라 판매하지 않는 제품';

/**
 * brands.shared_notice("※ 공지1 / ※ 공지2")를 공지 한 줄씩 나눈다.
 * 앞의 "※ "와 앞뒤 공백을 지우고, 빈 조각과 고정 안내와 중복되는 조각은 버린다.
 */
export function splitSharedNotice(value: string | null | undefined): string[] {
  if (!value) return [];
  return value
    .split(' / ')
    .map((part) => part.trim().replace(/^※\s*/, '').trim())
    .filter((part) => part !== '' && !part.includes(DUPLICATE_KEYWORD));
}
