// 네트워크·API 키 없이 돌리는 자체 테스트: URL 정규화, 강등 규칙, 알레르기 별칭 매핑.
import assert from 'node:assert/strict';
import { normalizeUrl, toStandardAllergen, validateResult, parseModelJson, extractResponse, buildRequestBody } from './research.mjs';

let passed = 0;
function test(name, fn) {
  try {
    fn();
    passed += 1;
    console.log(`ok   ${name}`);
  } catch (e) {
    console.error(`FAIL ${name}\n${e.message}`);
    process.exitCode = 1;
  }
}

const OFFICIAL = 'https://www.mcdonalds.co.kr/kor/menu/information/allergens';

test('URL: utm_source=openai 유무가 같은 값', () => {
  assert.equal(normalizeUrl(`${OFFICIAL}?utm_source=openai`), normalizeUrl(OFFICIAL));
});
test('URL: fragment·utm_*·끝 슬래시·호스트 대소문자', () => {
  assert.equal(normalizeUrl('HTTPS://WWW.Example.COM/a/b/?utm_medium=x&id=3#frag'), 'https://www.example.com/a/b?id=3');
  assert.equal(normalizeUrl('https://example.com/'), 'https://example.com');
  assert.equal(normalizeUrl('https://example.com'), 'https://example.com');
});
test('URL: 쿼리 순서 무관, 잘못된 URL·비 http 는 null', () => {
  assert.equal(normalizeUrl('https://e.com/p?b=2&a=1'), normalizeUrl('https://e.com/p?a=1&b=2'));
  assert.equal(normalizeUrl('javascript:alert(1)'), null);
  assert.equal(normalizeUrl('not a url'), null);
});

test('알레르기 별칭: 난류·달걀·계란 → 알류, 콩 → 대두, 조개류 계열, 새우류', () => {
  for (const n of ['난류', '달걀', '계란']) assert.equal(toStandardAllergen(n), '알류');
  assert.equal(toStandardAllergen('콩'), '대두');
  for (const n of ['굴', '전복', '홍합', '가리비', '조개']) assert.equal(toStandardAllergen(n), '조개류');
  assert.equal(toStandardAllergen('새우류'), '새우');
  assert.equal(toStandardAllergen(' 우유 '), '우유');
});
test('알레르기: 매핑에 없으면 null(미등록)', () => {
  assert.equal(toStandardAllergen('갑각류'), null);
  assert.equal(toStandardAllergen('참깨'), null);
  assert.equal(toStandardAllergen(undefined), null);
});

const franchise = { name: 'F', address: 'a', brand: 'B', is_franchise: true, official_domains: ['mcdonalds.co.kr'] };
const indie = { name: 'I', address: 'a', brand: null, is_franchise: false, official_domains: [] };
const known = new Set([normalizeUrl(OFFICIAL), normalizeUrl('https://blog.example.com/x')]);
const menu = (over) => ({
  name: 'M',
  description: 'd',
  taste_tags: ['매콤함'],
  allergens: [{ standard_name: '난류', original_text: '난류', level: 'contains' }],
  allergen_status: 'verified',
  allergen_sources: [{ url: OFFICIAL }],
  notes: '',
  ...over,
});
const run = (place, m) => validateResult({ menus: [m] }, { place, knownUrls: known });

test('검증: 공식 출처가 있는 프랜차이즈 verified 는 유지 (utm 붙은 URL 도 일치)', () => {
  const { result, stats } = run(franchise, menu({ allergen_sources: [{ url: `${OFFICIAL}?utm_source=openai` }] }));
  assert.equal(result.menus[0].allergen_status, 'verified');
  assert.equal(result.menus[0].allergen_sources[0].url, normalizeUrl(OFFICIAL));
  assert.equal(stats.demoted, 0);
});
test('강등: verified 인데 출처가 비면 unknown + warnings', () => {
  const { result, stats } = run(franchise, menu({ allergen_sources: [] }));
  assert.equal(result.menus[0].allergen_status, 'unknown');
  assert.deepEqual(result.menus[0].allergens, []);
  assert.equal(stats.demoted, 1);
  assert.ok(result.warnings.some((w) => w.includes('강등')));
});
test('강등: 출처 URL 이 sources/annotations 목록에 없으면 unknown', () => {
  const { result } = run(franchise, menu({ allergen_sources: [{ url: 'https://www.mcdonalds.co.kr/other' }] }));
  assert.equal(result.menus[0].allergen_status, 'unknown');
});
test('강등: 개인 식당(공식 도메인 없음)은 verified 불가 → unknown', () => {
  const { result } = run(indie, menu({ allergen_sources: [{ url: 'https://blog.example.com/x' }] }));
  assert.equal(result.menus[0].allergen_status, 'unknown');
  assert.ok(result.menus[0].notes.includes('강등 전 알레르기'));
});
test('강등: 프랜차이즈여도 공식 도메인이 아닌 출처는 verified 불가', () => {
  const { result } = run(franchise, menu({ allergen_sources: [{ url: 'https://blog.example.com/x' }] }));
  assert.equal(result.menus[0].allergen_status, 'unknown');
});
test('estimated: notes 에 "일반 조리법 기준 추정" 있으면 허용, 없으면 unknown', () => {
  const ok = run(indie, menu({ allergen_status: 'estimated', allergen_sources: [], notes: '일반 조리법 기준 추정' }));
  assert.equal(ok.result.menus[0].allergen_status, 'estimated');
  const bad = run(indie, menu({ allergen_status: 'estimated', allergen_sources: [], notes: '' }));
  assert.equal(bad.result.menus[0].allergen_status, 'unknown');
});
test('unknown 인데 알레르기 값이 있으면 비운다', () => {
  const { result } = run(indie, menu({ allergen_status: 'unknown', allergen_sources: [] }));
  assert.deepEqual(result.menus[0].allergens, []);
});
test('알레르기: 미등록 제거 + 같은 표준 이름은 합치고 원문 보관', () => {
  const m = menu({
    allergens: [
      { standard_name: '난류', original_text: '난류', level: 'may_contain' },
      { standard_name: '달걀', original_text: '달걀', level: 'contains' },
      { standard_name: '갑각류', original_text: '갑각류', level: 'contains' },
    ],
  });
  const { result, stats } = run(franchise, m);
  const a = result.menus[0].allergens;
  assert.equal(a.length, 1);
  assert.equal(a[0].standard_name, '알류');
  assert.equal(a[0].level, 'contains');
  assert.ok(a[0].original_text.includes('난류') && a[0].original_text.includes('달걀'));
  assert.equal(stats.removedAllergens, 1);
});
test('맛 태그: 허용 목록 밖 제거 + 최대 3개', () => {
  const { result, stats } = run(franchise, menu({ taste_tags: ['매콤함', '맵다', '달콤함', '짭조름함', '새콤함'] }));
  assert.deepEqual(result.menus[0].taste_tags, ['매콤함', '달콤함', '짭조름함']);
  assert.equal(stats.removedTags, 1);
});
test('메뉴를 못 찾았으면 빈 배열 유지, 이름 없는 메뉴는 버림', () => {
  assert.deepEqual(validateResult({ menus: [] }, { place: indie, knownUrls: new Set() }).result.menus, []);
  assert.deepEqual(validateResult({ menus: [{ description: 'x' }] }, { place: indie, knownUrls: new Set() }).result.menus, []);
  assert.deepEqual(validateResult(null, { place: indie, knownUrls: new Set() }).result.menus, []);
});
test('결과 JSON 의 URL 은 정규화된 값', () => {
  const { result } = validateResult({ menus: [], sources_used: [`${OFFICIAL}/?utm_source=openai`, OFFICIAL] }, { place: franchise, knownUrls: known });
  assert.deepEqual(result.sources_used, [normalizeUrl(OFFICIAL)]);
});

test('파싱: 코드블록·앞뒤 설명이 섞여도 JSON 추출', () => {
  assert.deepEqual(parseModelJson('```json\n{"a":1}\n```'), { a: 1 });
  assert.deepEqual(parseModelJson('결과입니다 {"a":1} 끝'), { a: 1 });
  assert.equal(parseModelJson('JSON 아님'), null);
});
test('응답 추출: 검색 호출 수·sources·annotations 병합', () => {
  const resp = {
    output: [
      { type: 'web_search_call', action: { sources: [{ url: `${OFFICIAL}?utm_source=openai` }] } },
      { type: 'web_search_call', action: {} },
      { type: 'message', content: [{ type: 'output_text', text: '{}', annotations: [{ type: 'url_citation', url: 'https://blog.example.com/x/' }] }] },
    ],
  };
  const ex = extractResponse(resp);
  assert.equal(ex.searchCalls, 2);
  assert.ok(ex.knownUrls.has(normalizeUrl(OFFICIAL)) && ex.knownUrls.has(normalizeUrl('https://blog.example.com/x')));
});
test('요청 본문: web_search 강제, KR, include, 도메인 제한은 프랜차이즈만', () => {
  const opt = { model: 'm', effort: 'low', background: false, maxToolCalls: 0 };
  const f = buildRequestBody(franchise, opt);
  assert.equal(f.tools[0].type, 'web_search');
  assert.equal(f.tool_choice, 'required');
  assert.deepEqual(f.tools[0].user_location, { type: 'approximate', country: 'KR' });
  assert.deepEqual(f.tools[0].filters, { allowed_domains: ['mcdonalds.co.kr'] });
  assert.deepEqual(f.include, ['web_search_call.action.sources']);
  assert.equal(f.background, undefined);
  assert.equal(buildRequestBody(indie, opt).tools[0].filters, undefined);
  assert.equal(buildRequestBody(indie, { ...opt, background: true }).background, true);
});

console.log(`\n${passed} 통과${process.exitCode ? ', 실패 있음' : ''}`);
