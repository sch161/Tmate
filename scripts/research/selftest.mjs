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
// Messages API 응답 블록 모양 (실제 호출에서 본 구조)
const searchUse = (id) => ({ type: 'server_tool_use', id, name: 'web_search', input: { query: 'q' } });
const searchResult = (id, urls) => ({ type: 'web_search_tool_result', tool_use_id: id, content: urls.map((url) => ({ type: 'web_search_result', title: 't', url })) });

test('응답 추출: 검색 호출 수·검색 결과 URL·인용 URL 병합, 코드 실행 블록은 무시', () => {
  const resp = {
    content: [
      { type: 'server_tool_use', id: 'c1', name: 'code_execution', input: { code: '' } },
      searchUse('s1'),
      searchResult('s1', [`${OFFICIAL}?utm_source=openai`]),
      { type: 'code_execution_tool_result', tool_use_id: 'c1', content: { type: 'code_execution_result', stdout: '', stderr: '', return_code: 0 } },
      searchUse('s2'),
      { type: 'web_search_tool_result', tool_use_id: 's2', content: { type: 'web_search_tool_result_error', error_code: 'max_uses_exceeded' } },
      { type: 'text', text: '{}', citations: [{ type: 'web_search_result_location', url: 'https://blog.example.com/x/' }] },
    ],
  };
  const ex = extractResponse(resp);
  assert.equal(ex.searchCalls, 2);
  assert.equal(ex.fetchCalls, 0);
  assert.ok(ex.knownUrls.has(normalizeUrl(OFFICIAL)) && ex.knownUrls.has(normalizeUrl('https://blog.example.com/x')));
  assert.deepEqual(ex.toolErrors, ['web_search: max_uses_exceeded']);
});
test('응답 추출: 최종 텍스트는 마지막 도구 호출 뒤의 것만', () => {
  const ex = extractResponse({ content: [{ type: 'text', text: '검색해 볼게요 {중간}' }, searchUse('s1'), searchResult('s1', [OFFICIAL]), { type: 'text', text: '{"a":' }, { type: 'text', text: '1}' }] });
  assert.equal(ex.text, '{"a":1}');
});
test('응답 추출: web_fetch 로 연 URL 은 fetchedUrls·sourceUrls 에 담긴다', () => {
  const ex = extractResponse({ content: [
    { type: 'server_tool_use', id: 'f1', name: 'web_fetch', input: { url: OFFICIAL } },
    { type: 'web_fetch_tool_result', tool_use_id: 'f1', content: { type: 'web_fetch_result', url: OFFICIAL, content: {} } },
    { type: 'web_fetch_tool_result', tool_use_id: 'f2', content: { type: 'web_fetch_tool_result_error', error_code: 'url_not_accessible' } },
  ] });
  assert.equal(ex.fetchCalls, 1);
  assert.ok(ex.fetchedUrls.has(normalizeUrl(OFFICIAL)) && ex.sourceUrls.has(normalizeUrl(OFFICIAL)));
  assert.deepEqual(ex.toolErrors, ['web_fetch: url_not_accessible']);
});
test('요청 본문: 도구 강제 없음, KR, effort, 도메인 제한은 프랜차이즈만, web_fetch 는 옵션', () => {
  const opt = { model: 'm', effort: 'low', maxToolCalls: 0, webFetch: true, fallbacks: true };
  const f = buildRequestBody(franchise, opt);
  assert.equal(f.tools[0].type, 'web_search_20260209');
  assert.equal(f.tools[1].type, 'web_fetch_20260209');
  assert.equal(f.tool_choice, undefined);
  assert.equal(f.thinking, undefined);
  assert.deepEqual(f.tools[0].user_location, { type: 'approximate', country: 'KR', timezone: 'Asia/Seoul' });
  assert.deepEqual(f.tools[0].allowed_domains, ['mcdonalds.co.kr']);
  assert.deepEqual(f.tools[1].allowed_domains, ['mcdonalds.co.kr']);
  assert.deepEqual(f.output_config, { effort: 'low' });
  assert.equal(f.fallbacks, 'default');
  assert.equal(f.max_tokens, 16000);
  assert.equal(f.messages.length, 1);
  assert.ok(f.system.includes('web_fetch 도구로 본문을 직접 열어'));
  const i = buildRequestBody(indie, { ...opt, webFetch: false, fallbacks: false, maxToolCalls: 3 });
  assert.equal(i.tools.length, 1);
  assert.equal(i.tools[0].allowed_domains, undefined);
  assert.equal(i.tools[0].max_uses, 3);
  assert.equal(i.fallbacks, undefined);
  assert.ok(i.system.includes('web_fetch 도구를 쓸 수 없다'));
});
test('verified: 본문을 연 기록이 없으면 official_extract 로 낮추고 값은 유지', () => {
  const ctx = { place: franchise, knownUrls: known, sourceUrls: new Set([normalizeUrl(OFFICIAL)]) };
  const down = validateResult({ menus: [menu()] }, { ...ctx, fetchedUrls: new Set() });
  assert.equal(down.result.menus[0].allergen_status, 'official_extract');
  assert.equal(down.result.menus[0].allergens.length, 1);
  assert.equal(down.stats.downgraded, 1);
  assert.equal(down.stats.demoted, 0);
  const kept = validateResult({ menus: [menu()] }, { ...ctx, fetchedUrls: new Set([normalizeUrl(OFFICIAL)]) });
  assert.equal(kept.result.menus[0].allergen_status, 'verified');
  assert.equal(kept.stats.downgraded, 0);
});

// ---- official_extract / 브랜드 모드 ----
const brandPlace = { name: 'B', address: '', brand: 'B', is_franchise: true, official_domains: ['mcdonalds.co.kr'], mode: 'brand' };
const sourcesOnly = new Set([normalizeUrl(OFFICIAL)]);
const runB = (m, ctx = {}) => validateResult({ menus: [m] }, { place: brandPlace, knownUrls: known, sourceUrls: sourcesOnly, ...ctx });

test('official_extract: 공식 도메인 URL 이 sources 에 있으면 유지 (utm 붙어도 일치)', () => {
  const { result, stats } = runB(menu({ allergen_status: 'official_extract', allergen_sources: [{ url: `${OFFICIAL}?utm_source=openai` }] }));
  assert.equal(result.menus[0].allergen_status, 'official_extract');
  assert.equal(result.menus[0].allergens.length, 1);
  assert.equal(stats.demoted, 0);
  assert.equal(stats.menus.official_extract, 1);
});
test('official_extract 강등: 공식 도메인이 아니면 unknown', () => {
  const { result } = runB(menu({ allergen_status: 'official_extract', allergen_sources: [{ url: 'https://blog.example.com/x' }] }), { sourceUrls: new Set([normalizeUrl('https://blog.example.com/x')]) });
  assert.equal(result.menus[0].allergen_status, 'unknown');
  assert.deepEqual(result.menus[0].allergens, []);
});
test('official_extract 강등: 공식 도메인이어도 sources 에 없으면(annotations 에만 있으면) unknown', () => {
  const { result } = runB(menu({ allergen_status: 'official_extract' }), { sourceUrls: new Set() });
  assert.equal(result.menus[0].allergen_status, 'unknown');
});
test('official_extract 강등: 출처가 비어 있으면 unknown + warnings', () => {
  const { result, stats } = runB(menu({ allergen_status: 'official_extract', allergen_sources: [] }));
  assert.equal(result.menus[0].allergen_status, 'unknown');
  assert.equal(stats.demoted, 1);
  assert.ok(result.warnings.some((w) => w.includes('official_extract') && w.includes('강등')));
});
test('브랜드 모드: 알레르기 합치기("조개, 굴" → 조개류)·원문 보존·고정 공지·세트 notes 유지', () => {
  const m = menu({
    name: '더블 데리버거 세트',
    allergen_status: 'official_extract',
    notes: '세트 기준 표기',
    allergens: [
      { standard_name: '조개', original_text: '조개', level: 'contains' },
      { standard_name: '굴', original_text: '굴', level: 'contains' },
    ],
  });
  const { result } = validateResult({ menus: [m], shared_notice: '튀김류 조리기구 공유' }, { place: brandPlace, knownUrls: known, sourceUrls: sourcesOnly });
  const a = result.menus[0].allergens;
  assert.equal(a.length, 1);
  assert.equal(a[0].standard_name, '조개류');
  assert.equal(a[0].original_text, '조개 / 굴');
  assert.equal(result.menus[0].name, '더블 데리버거 세트');
  assert.ok(result.menus[0].notes.includes('세트 기준 표기'));
  assert.equal(result.shared_notice, '튀김류 조리기구 공유 / 지점에 따라 판매하지 않는 제품이 있을 수 있음');
  assert.equal(validateResult({ menus: [] }, { place: brandPlace, knownUrls: known }).result.shared_notice, '지점에 따라 판매하지 않는 제품이 있을 수 있음');
});
test('브랜드 모드: 메뉴는 10개로 제한', () => {
  const many = Array.from({ length: 12 }, (_, i) => menu({ name: `M${i}` }));
  const { result } = validateResult({ menus: many }, { place: brandPlace, knownUrls: known });
  assert.equal(result.menus.length, 10);
  assert.ok(result.warnings.some((w) => w.includes('10개 초과')));
});
test('브랜드 요청 본문: 도메인 제한·max_tokens·브랜드 입력, 가게 모드는 브랜드 지시문 없음', () => {
  const b = buildRequestBody(brandPlace, { model: 'm', effort: 'low', maxToolCalls: 0, maxOutputTokens: 32000 });
  assert.equal(b.max_tokens, 32000);
  assert.deepEqual(b.tools[0].allowed_domains, ['mcdonalds.co.kr']);
  assert.ok(b.messages[0].content.includes('"brand":"B"') && b.system.includes('브랜드 조사 모드') && b.system.includes('official_extract'));
  assert.equal(buildRequestBody(franchise, { model: 'm', effort: 'low', maxToolCalls: 0, maxOutputTokens: 0 }).max_tokens, 16000);
  assert.ok(!buildRequestBody(franchise, { model: 'm', effort: 'low' }).system.includes('브랜드 조사 모드'));
});
test('응답 추출: sourceUrls 는 검색 결과·연 페이지만 담는다 (인용에만 있는 URL 은 제외)', () => {
  const ex = extractResponse({ content: [
    searchUse('s1'),
    searchResult('s1', [OFFICIAL]),
    { type: 'text', text: '{}', citations: [{ type: 'web_search_result_location', url: 'https://blog.example.com/x' }] },
  ] });
  assert.ok(ex.sourceUrls.has(normalizeUrl(OFFICIAL)) && !ex.sourceUrls.has(normalizeUrl('https://blog.example.com/x')));
});

console.log(`\n${passed} 통과${process.exitCode ? ', 실패 있음' : ''}`);
