// 디자인 대기: 화면 나오면 교체
// 맛 코드 → 예시 음식 문구 매핑은 이 파일 한 곳에서만 관리한다. 키는 DB 의 taste_tags.code.
// "매콤함" 같은 단어만으로는 고르기 어려워서, 맛 선택 카드와 비율 슬라이더에 예시 음식을 함께 보여준다.
const TASTE_EXAMPLES: Record<string, string> = {
  spicy: '떡볶이 · 불닭 · 마라탕',
  sweet: '양념치킨 · 불고기 · 허니버터',
  salty: '감자튀김 · 간장치킨 · 장조림',
  sour: '냉면 · 피클 · 레몬에이드',
  nutty: '콩국수 · 들깨칼국수 · 치즈',
  mild: '수육 · 샤브샤브 · 닭가슴살',
  rich: '까르보나라 · 치즈돈가스 · 버터',
  bitter: '아메리카노 · 다크초콜릿 · 나물',
  umami: '된장찌개 · 라멘 · 버섯',
};

/** 매핑에 없는 코드면 undefined → 호출한 쪽은 예시 없이 이름만 보여준다 */
export function getTasteExample(code: string | undefined): string | undefined {
  if (!code) return undefined;
  return Object.prototype.hasOwnProperty.call(TASTE_EXAMPLES, code) ? TASTE_EXAMPLES[code] : undefined;
}
