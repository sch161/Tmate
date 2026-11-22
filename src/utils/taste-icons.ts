// 디자인 대기: 맛 코드 → 아이콘 매핑은 이 파일 한 곳에서만 관리한다.
// 키는 DB 의 taste_tags.code. 디자인이 나오면 에셋을 추가하고 여기에 채운다. (지금은 비어 있음)
const TASTE_ICONS: Record<string, string> = {};

export function getTasteIcon(code: string): string | undefined {
  return TASTE_ICONS[code];
}
