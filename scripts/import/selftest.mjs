// 네트워크·DB·실제 CSV 없이 도는 자체 테스트: CSV 파서, 지점 필터, region 형식, 세트 이름, 표준 알레르기, 이스케이프, 날짜 파싱
// 실행: node scripts/import/selftest.mjs
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { EXPECTED_HEADER, createCsvParser, scanCsv, buildSql as buildBranchSql, processRow } from './build-branches.mjs';
import { buildSql as buildMenuSql, normalizeMenuName, parseDataDate, prepareMenu, sanitizeNote } from './build-brand-menus.mjs';
import { sqlString } from './lib.mjs';

let passed = 0;
async function test(name, fn) {
  try {
    await fn();
    passed += 1;
    console.log(`ok   ${name}`);
  } catch (e) {
    console.error(`FAIL ${name}\n${e.stack}`);
    process.exitCode = 1;
  }
}

// ---- 가짜 CSV (실제 형식: 문자열은 큰따옴표, 숫자는 따옴표 없음, 값 끝 공백, BOM) ----
const q = (v) => `"${String(v).replace(/"/g, '""')}"`;
function line(o) {
  const base = {
    상가업소번호: 'A1', 상호명: '맥도날드', 지점명: '', 상권업종대분류코드: 'I2', 상권업종대분류명: '음식', 상권업종중분류코드: 'I201', 상권업종중분류명: '양식 ',
    상권업종소분류코드: 'I20104', 상권업종소분류명: '경양식 ', 표준산업분류코드: 'I56111', 표준산업분류명: '한식', 시도코드: '11', 시도명: '서울특별시',
    시군구코드: '11530', 시군구명: '구로구', 행정동코드: '1', 행정동명: '구로동', 법정동코드: '1', 법정동명: '구로동', 지번코드: '1', 대지구분코드: '1', 대지구분명: '대지',
    지번본번지: 12, 지번부번지: '', 지번주소: '서울특별시 구로구 구로동 12', 도로명코드: '1', 도로명: '디지털로', 건물본번지: 3, 건물부번지: '', 건물관리번호: '1', 건물명: '',
    도로명주소: '서울특별시 구로구 디지털로 3', 구우편번호: '1', 신우편번호: '1', 동정보: '', 층정보: '1', 호정보: '', 경도: 126.1, 위도: 37.1,
    ...o,
  };
  return EXPECTED_HEADER.map((h) => (typeof base[h] === 'number' ? String(base[h]) : q(base[h]))).join(',');
}
const header = EXPECTED_HEADER.map(q).join(',');
const brands = [
  { name: '맥도날드', category: '양식', name_patterns: ['맥도날드'], exclude_patterns: ['맥도날드빌딩'], official_domains: ['mcdonalds.co.kr'], allergen_table_is_set_based: false, result_key: '맥도날드' },
  { name: '롯데리아', category: '양식', name_patterns: ['롯데리아'], exclude_patterns: [], official_domains: ['lotteeatz.com'], allergen_table_is_set_based: true, result_key: '롯데리아' },
];
const rows = [
  line({ 상가업소번호: 'A1', 상호명: '한국맥도날드', 지점명: '구로디지털점', 시군구명: '구로구' }), // 통과, 지점명 덧붙임
  line({ 상가업소번호: 'A2', 상호명: '롯데 리아', 시군구명: '관악구', 도로명주소: '', 지번주소: '서울특별시 관악구 봉천동 1' }), // 통과(공백 제거 매칭 안 됨 → 제외) — '롯데 리아' 는 패턴 '롯데리아' 와 공백 제거 후 일치
  line({ 상가업소번호: 'A3', 상호명: '롯데리아 "신림"점, 본점', 시군구명: '관악구' }), // 따옴표·쉼표 포함, 통과
  line({ 상가업소번호: 'A4', 상호명: '맥도날드빌딩' }), // exclude
  line({ 상가업소번호: 'A5', 상호명: '맥도날드', 시도명: '경기도' }), // 서울 아님
  line({ 상가업소번호: 'A6', 상호명: '맥도날드', 상권업종대분류명: '소매' }), // 음식 아님
  line({ 상가업소번호: 'A1', 상호명: '맥도날드', 시군구명: '강남구' }), // 중복 번호
  line({ 상가업소번호: 'A7', 상호명: '맥도날드롯데리아복합점' }), // 두 브랜드
  line({ 상가업소번호: 'A8', 상호명: '교촌치킨' }), // 대상 아님
  line({ 상가업소번호: 'A9', 상호명: '맥도날드 줄바꿈\n점', 시군구명: '송파구' }), // 따옴표 안 줄바꿈
];

async function scanFixture(content) {
  const dir = mkdtempSync(join(tmpdir(), 'import-selftest-'));
  try {
    const file = join(dir, 'fixture_서울_1.csv');
    writeFileSync(file, content, 'utf8');
    const acc = { rows: 0, badRows: 0, badSamples: [], skipped: [], records: [], seen: new Set() };
    await scanCsv(file, brands, acc);
    return acc;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

await test('CSV 파서: 이스케이프된 따옴표, 따옴표 안 쉼표·줄바꿈, 값 끝 공백 trim, BOM, CRLF, 청크 경계', () => {
  const got = [];
  const p = createCsvParser((r) => got.push(r));
  const text = '﻿"a ","b""c","d,e","f\ng"\r\n"x",12,,"y "\r\n';
  // 1글자씩 쪼개 넣어도 같아야 한다 (청크 경계에서 "" 처리)
  for (const ch of text) p.feed(ch);
  p.end();
  assert.deepEqual(got, [['a', 'b"c', 'd,e', 'f\ng'], ['x', '12', '', 'y']]);
});

await test('지점: 서울·음식·패턴·제외·중복·다중 브랜드 필터와 기록', async () => {
  const acc = await scanFixture(`﻿${header}\n${rows.join('\n')}\n`);
  assert.deepEqual(acc.records.map((r) => r.external_id).sort(), ['A1', 'A2', 'A3', 'A9']);
  const reasons = acc.skipped.map((s) => s.skip);
  assert.ok(reasons.some((r) => r.startsWith('둘 이상의 브랜드')));
  assert.ok(reasons.some((r) => r.includes('중복')));
  assert.equal(acc.skipped.length, 2); // 제외/서울 아님/음식 아님/대상 아님 행은 기록하지 않는다
  assert.equal(acc.badRows, 0);
});

await test('지점: region 형식·이름 조합·주소 대체·phone 없음', async () => {
  const acc = await scanFixture(`${header}\n${rows.join('\n')}\n`);
  const byId = Object.fromEntries(acc.records.map((r) => [r.external_id, r]));
  assert.equal(byId.A1.region, '서울시 구로구');
  assert.equal(byId.A1.sido, '서울특별시');
  assert.equal(byId.A1.sigungu, '구로구');
  assert.equal(byId.A1.name, '한국맥도날드 구로디지털점'); // 지점명이 상호명에 없으면 덧붙임
  assert.equal(byId.A2.address, '서울특별시 관악구 봉천동 1'); // 도로명주소가 비면 지번주소
  assert.equal(byId.A2.brand, '롯데리아'); // 공백 제거 후 매칭
  assert.equal(byId.A3.name, '롯데리아 "신림"점, 본점');
  assert.equal(byId.A9.region, '서울시 송파구');
  const sql = buildBranchSql(brands, acc.records, { files: ['fixture'] });
  assert.ok(sql.includes("'서울시 관악구'") && sql.includes('on conflict (external_id) do update') && sql.includes('on conflict (name) where is_franchise do update'));
  assert.ok(sql.includes(`'롯데리아 "신림"점, 본점'`));
  assert.ok(!sql.includes('phone = '), 'phone 은 덮어쓰지 않는다');
});

await test('지점: 지점명이 상호명에 이미 있으면 덧붙이지 않는다', () => {
  const got = [];
  const p = createCsvParser((x) => got.push(x));
  p.feed(`${line({ 상호명: '롯데리아 구파발역점', 지점명: '구파발역점' })}\n`);
  p.end();
  assert.equal(processRow(got[0], brands).record.name, '롯데리아 구파발역점');
});

await test('헤더가 다르면 멈춘다', async () => {
  await assert.rejects(() => scanFixture(`${header.replace('상호명', '가게이름')}\n${rows[0]}\n`), /헤더가 예상과 달라요/);
});

await test('SQL 이스케이프: 작은따옴표·NUL, 빈 값은 null', () => {
  assert.equal(sqlString("it's"), "'it''s'");
  assert.equal(sqlString('a\u0000b'), "'ab'");
  assert.equal(sqlString(''), 'null');
  assert.equal(sqlString(null), 'null');
  assert.equal(sqlString("x'); drop table menus; --"), "'x''); drop table menus; --'");
});

await test('메뉴 이름 정규화: ®·™·TM 제거, 공백 정리, 세트 접미사', () => {
  assert.equal(normalizeMenuName('빅맥®', false), '빅맥');
  assert.equal(normalizeMenuName('  1955®  버거 ', false), '1955 버거');
  assert.equal(normalizeMenuName('쿼터파운더™ 치즈', false), '쿼터파운더 치즈');
  assert.equal(normalizeMenuName('치즈 TM 버거', false), '치즈 버거');
  assert.equal(normalizeMenuName('데리버거', true), '데리버거 세트');
  assert.equal(normalizeMenuName('데리버거 세트', true), '데리버거 세트');
  assert.equal(normalizeMenuName('®', true), '');
});

await test('날짜 파싱: "YYYY년 M월 D일 기준", 없으면 null', () => {
  assert.equal(parseDataDate(['x', '공식 영양성분표(배달용)의 2026년 11월 20일 기준 본문을 직접 확인했습니다.']), '2026-11-20');
  assert.equal(parseDataDate(['2026년 1월 5일 기준']), '2026-01-05');
  assert.equal(parseDataDate(['기준일 없음', undefined, '2026년 13월 40일 기준']), null);
  assert.equal(parseDataDate([]), null);
});

const rawMenu = (o) => ({
  name: '빅맥®', description: '대표 버거', taste_tags: ['짭조름함', '맛없음'], allergen_status: 'official_extract',
  allergen_sources: [{ url: 'https://www.mcdonalds.co.kr/kor/menu/information/allergens?utm_source=x' }],
  allergens: [{ standard_name: '알류', original_text: '난류', level: 'contains' }, { standard_name: '조개류', original_text: '조개', level: 'contains' }, { standard_name: '조개류', original_text: '굴', level: 'may_contain' }, { standard_name: '갑각류', original_text: '갑각류', level: 'contains' }],
  notes: '공식 검색 발췌의 버거 단품 기준. 맛 태그는 추정.', ...o,
});

await test('메뉴 검증: 표준 19종 밖 건너뜀·같은 표준 이름 합침·맛 태그 허용 목록·단품 표현 제거', () => {
  const logs = [];
  const m = prepareMenu(rawMenu({}), brands[0], logs, { checkedAt: '2026-11-22T00:00:00.000Z' });
  assert.deepEqual(m.allergens.map((a) => [a.standard_name, a.level, a.original_text]), [['알류', 'danger', '난류'], ['조개류', 'danger', '조개 / 굴']]);
  assert.deepEqual(m.tags, ['짭조름함']);
  assert.equal(m.name, '빅맥');
  assert.equal(m.menuSourceName, '공식 사이트');
  assert.ok(!m.note.includes('단품'));
  assert.equal(m.note, '맛 태그는 추정.');
  assert.ok(logs.some((l) => l.includes('갑각류')) && logs.some((l) => l.includes('맛없음')));
  assert.equal(sanitizeNote('단품 기준. 맛 태그는 추정.'), '맛 태그는 추정.');
});

await test('메뉴 검증: 출처 없는 verified/official_extract → unknown(알레르기 비움), 이름 없는 메뉴 건너뜀', () => {
  const logs = [];
  const m = prepareMenu(rawMenu({ allergen_sources: [] }), brands[0], logs);
  assert.equal(m.status, 'unknown');
  assert.deepEqual(m.allergens, []);
  assert.equal(m.sourceUrl, null);
  assert.ok(logs.some((l) => l.includes('unknown 으로 내림')));
  assert.equal(prepareMenu(rawMenu({ name: ' ® ' }), brands[0], logs), null);
});

await test('세트 기준 브랜드: 이름 끝 " 세트"·고정 note, "단품 기준" 표현 없음', () => {
  const logs = [];
  const m = prepareMenu(rawMenu({ name: '데리버거', notes: '단품 기준. 맛 태그는 추정.' }), brands[1], logs);
  assert.equal(m.name, '데리버거 세트');
  assert.equal(m.note, '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다');
  assert.ok(!m.note.includes('단품'));
});

await test('메뉴 SQL: 멱등 구조·replace·고정 공지·날짜·이스케이프', () => {
  const results = [{
    input: { brand: '롯데리아' },
    result: {
      shared_notice: "조리기구 공유 'x'",
      warnings: ['공식 영양성분표의 2026년 11월 20일 기준 본문을 직접 확인했습니다.'],
      menus: [rawMenu({ name: "리아'불고기", allergen_sources: [{ url: 'https://www.lotteeatz.com/a' }], notes: '' }), rawMenu({ name: '데리버거', allergen_sources: [{ url: 'https://www.lotteeatz.com/a' }] })],
    },
  }];
  const { sql, names } = buildMenuSql(results, brands, { checkedAt: '2026-11-22T00:00:00.000Z' });
  assert.deepEqual(names['롯데리아'], ["리아'불고기 세트", '데리버거 세트']);
  assert.ok(sql.includes("allergen_data_date = '2026-11-20'::date"));
  assert.ok(sql.includes("shared_notice = '조리기구 공유 ''x'' / 지점에 따라 판매하지 않는 제품이 있을 수 있음'"));
  assert.ok(sql.includes("'리아''불고기 세트'"));
  assert.ok(sql.includes('on conflict (brand_id, name) do update'));
  assert.ok(sql.includes('delete from menu_allergens where menu_id in') && sql.includes('delete from menu_taste_tags where menu_id in'));
  assert.ok(sql.includes("research_status = 'done'"));
  assert.ok(sql.includes("('알류', 'danger', '난류')"));
  assert.ok(!sql.includes('갑각류'));
  assert.ok(sql.includes('seed_branches.sql 을 먼저 실행하세요'));
  // 결과가 없는 브랜드(맥도날드)는 SQL 에 나오지 않는다
  assert.ok(!sql.includes("b.name = '맥도날드'"));
});

console.log(`\n${passed} 통과${process.exitCode ? ', 실패 있음' : ''}`);
