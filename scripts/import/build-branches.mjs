// 공공데이터 상가(상권)정보 CSV(서울) → 지정 브랜드 지점을 뽑아 supabase/seed_branches.sql(멱등)과 진단 리포트를 만든다.
// 실행: node scripts/import/build-branches.mjs [--raw data/raw] [--brands scripts/import/brands.json]
// Node 내장 모듈만 사용한다. 300MB 급 파일이므로 스트리밍으로 읽고, 매칭된 행만 메모리에 둔다.
import { createReadStream, readdirSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { REPO_ROOT, OUT_DIR, sqlString, sqlRequired, isMain } from './lib.mjs';

export const EXPECTED_HEADER = [
  '상가업소번호', '상호명', '지점명', '상권업종대분류코드', '상권업종대분류명', '상권업종중분류코드', '상권업종중분류명',
  '상권업종소분류코드', '상권업종소분류명', '표준산업분류코드', '표준산업분류명', '시도코드', '시도명', '시군구코드', '시군구명',
  '행정동코드', '행정동명', '법정동코드', '법정동명', '지번코드', '대지구분코드', '대지구분명', '지번본번지', '지번부번지',
  '지번주소', '도로명코드', '도로명', '건물본번지', '건물부번지', '건물관리번호', '건물명', '도로명주소', '구우편번호',
  '신우편번호', '동정보', '층정보', '호정보', '경도', '위도',
];
const COL = Object.fromEntries(EXPECTED_HEADER.map((name, i) => [name, i]));
const SIDO = '서울특별시';
const BATCH = 500;

// ---------- CSV 파서 (큰따옴표 이스케이프, 따옴표 안의 쉼표·줄바꿈, BOM, CRLF, 청크 경계 처리) ----------

/** feed(chunk) 로 문자열 조각을 넣고 end() 로 마무리한다. 각 행은 trim 된 필드 배열로 onRow 에 전달된다. */
export function createCsvParser(onRow) {
  let field = '';
  let row = [];
  let inQuotes = false;
  let quotePending = false; // 따옴표 안에서 '"' 를 보고 다음 글자를 기다리는 중 ("" 이스케이프인지 닫는 따옴표인지)
  let first = true;

  const endRow = () => {
    row.push(field.trim());
    field = '';
    if (!(row.length === 1 && row[0] === '')) onRow(row); // 빈 줄은 건너뛴다
    row = [];
  };

  return {
    feed(chunk) {
      if (first) {
        first = false;
        if (chunk.charCodeAt(0) === 0xfeff) chunk = chunk.slice(1);
      }
      for (let i = 0; i < chunk.length; i++) {
        const c = chunk.charCodeAt(i);
        if (quotePending) {
          quotePending = false;
          if (c === 34) {
            field += '"';
            continue;
          }
          inQuotes = false; // 방금 본 따옴표는 닫는 따옴표였다. 현재 글자는 아래에서 일반 처리한다
        }
        if (inQuotes) {
          if (c === 34) quotePending = true;
          else field += chunk[i];
          continue;
        }
        if (c === 34) inQuotes = true;
        else if (c === 44) {
          row.push(field.trim());
          field = '';
        } else if (c === 10) endRow();
        else if (c !== 13) field += chunk[i];
      }
    },
    end() {
      quotePending = false;
      inQuotes = false;
      if (field !== '' || row.length > 0) endRow();
    },
  };
}

// ---------- 필터·변환 ----------

const noSpace = (s) => String(s ?? '').replace(/\s+/g, '');

/** 상호명(공백 제거)이 걸리는 브랜드 이름 목록 */
export function matchBrands(shopName, brands) {
  const n = noSpace(shopName);
  return brands
    .filter((b) => b.name_patterns.some((p) => n.includes(noSpace(p))) && !arr(b.exclude_patterns).some((p) => n.includes(noSpace(p))))
    .map((b) => b.name);
}
const arr = (v) => (Array.isArray(v) ? v : []);

export function buildRecord(row, brandName) {
  const shop = row[COL['상호명']];
  const branch = row[COL['지점명']];
  const name = branch && !shop.includes(branch) ? `${shop} ${branch}` : shop;
  const gu = row[COL['시군구명']];
  return {
    brand: brandName,
    external_id: row[COL['상가업소번호']],
    name,
    address: row[COL['도로명주소']] || row[COL['지번주소']],
    region: `서울시 ${gu}`,
    sido: SIDO,
    sigungu: gu,
    small_category: row[COL['상권업종소분류명']] || '(없음)',
    shop_name: shop,
  };
}

/**
 * 한 행을 처리한다. 반환: { skip: '사유' } | { record } | null(대상 아님, 기록하지 않는 행)
 * 서울이 아니거나 음식이 아니거나 브랜드에 안 걸리는 행은 기록 없이 null.
 */
export function processRow(row, brands) {
  if (row[COL['시도명']] !== SIDO || row[COL['상권업종대분류명']] !== '음식') return null;
  const matched = matchBrands(row[COL['상호명']], brands);
  if (matched.length === 0) return null;
  if (matched.length > 1) return { skip: `둘 이상의 브랜드에 매칭(${matched.join('/')})`, name: row[COL['상호명']] };
  const rec = buildRecord(row, matched[0]);
  if (!rec.external_id) return { skip: '상가업소번호 없음', name: rec.shop_name };
  if (!row[COL['시군구명']]) return { skip: '시군구명 없음', name: rec.shop_name };
  if (!rec.address) return { skip: '주소 없음(도로명·지번 모두 비어 있음)', name: rec.shop_name };
  return { record: rec };
}

// ---------- SQL ----------

export function buildSql(brands, records, meta = {}) {
  const lines = [];
  lines.push('-- =====================================================================');
  lines.push('-- seed_branches.sql — 공공데이터 상가(상권)정보에서 뽑은 브랜드 지점 (scripts/import/build-branches.mjs 가 생성, 직접 수정하지 않는다)');
  lines.push(`-- 원본: ${meta.files?.join(', ') ?? '(CSV)'} / 브랜드: ${brands.map((b) => b.name).join(', ')} / 지점 ${records.length}개`);
  lines.push('-- 멱등: 여러 번 실행해도 안전하다 (brands 는 이름, restaurants 는 external_id 로 upsert).');
  lines.push('-- 실행 순서: (schema/policies/functions/seed_reference 이후) 이 파일 → seed_brand_menus.sql');
  lines.push('-- =====================================================================');
  lines.push('begin;');
  lines.push('');
  for (const b of brands) {
    lines.push(`-- 브랜드: ${b.name}`);
    lines.push('insert into brands (name, is_franchise, category_id, official_domains)');
    lines.push(
      `values (${sqlRequired(b.name)}, true, (select id from food_categories where name = ${sqlRequired(b.category)}), ` +
        `array[${arr(b.official_domains).map(sqlRequired).join(', ')}]::text[])`,
    );
    lines.push('on conflict (name) where is_franchise do update');
    lines.push('  set is_franchise = true, category_id = excluded.category_id, official_domains = excluded.official_domains;');
    lines.push('');
  }
  const sorted = [...records].sort((a, b) => a.brand.localeCompare(b.brand, 'ko') || a.external_id.localeCompare(b.external_id));
  for (let i = 0; i < sorted.length; i += BATCH) {
    const chunk = sorted.slice(i, i + BATCH);
    lines.push(`-- 지점 ${i + 1}~${i + chunk.length}`);
    lines.push('insert into restaurants (brand_id, external_id, name, address, region, sido, sigungu, phone)');
    lines.push('select b.id, v.external_id, v.name, v.address, v.region, v.sido, v.sigungu, null');
    lines.push('from (values');
    lines.push(
      chunk
        .map((r) => `  (${[r.brand, r.external_id, r.name, r.address, r.region, r.sido, r.sigungu].map(sqlRequired).join(', ')})`)
        .join(',\n'),
    );
    lines.push(') as v(brand, external_id, name, address, region, sido, sigungu)');
    lines.push('join brands b on b.name = v.brand and b.is_franchise');
    lines.push('on conflict (external_id) do update');
    lines.push('  set brand_id = excluded.brand_id, name = excluded.name, address = excluded.address,');
    lines.push('      region = excluded.region, sido = excluded.sido, sigungu = excluded.sigungu;');
    lines.push('');
  }
  lines.push('commit;');
  return `${lines.join('\n')}\n`;
}

// ---------- 리포트 ----------

const top = (map, n) => [...map.entries()].sort((a, b) => b[1] - a[1] || String(a[0]).localeCompare(String(b[0]), 'ko')).slice(0, n);
const inc = (map, key) => map.set(key, (map.get(key) ?? 0) + 1);

export function buildReport(brands, records, skipped, stats) {
  const L = [];
  L.push('# 지점 import 진단 리포트', '');
  L.push(`- 읽은 파일: ${stats.files.join(', ')}`);
  L.push(`- 읽은 행 수(헤더 제외): ${stats.rows} / 필드 수가 달라 무시한 행: ${stats.badRows}`);
  L.push(`- 필터 조건: 시도명=서울특별시, 상권업종대분류명=음식, 상호명(공백 제거) 포함 패턴`, '');
  for (const b of brands) {
    const mine = records.filter((r) => r.brand === b.name);
    const gu = new Map();
    const cat = new Map();
    const names = new Map();
    for (const r of mine) {
      inc(gu, r.sigungu);
      inc(cat, r.small_category);
      inc(names, r.shop_name);
    }
    L.push(`## ${b.name} — 지점 ${mine.length}개`, '');
    L.push(`패턴: ${b.name_patterns.join(', ')} / 제외: ${arr(b.exclude_patterns).join(', ') || '(없음)'}`, '');
    L.push('### 구별 지점 수 상위 10');
    for (const [k, v] of top(gu, 10)) L.push(`- ${k}: ${v}`);
    L.push('', '### 상권업종소분류명 분포 (오탐 점검: 버거·패스트푸드 외 분류가 많으면 의심)');
    for (const [k, v] of top(cat, 30)) L.push(`- ${k}: ${v}`);
    L.push('', `### 매칭된 상호명 (중복 제거, 최대 50개 / 전체 ${names.size}종, 빈도순)`);
    for (const [k, v] of top(names, 50)) L.push(`- ${k} (${v})`);
    L.push('');
  }
  L.push('## 건너뛴 행', '');
  const reasons = new Map();
  for (const s of skipped) inc(reasons, s.skip);
  if (skipped.length === 0) L.push('- (없음)');
  for (const [k, v] of top(reasons, 20)) {
    L.push(`- ${k}: ${v}건`);
    for (const s of skipped.filter((x) => x.skip === k).slice(0, 10)) L.push(`  - ${s.name ?? ''} ${s.id ?? ''}`.trimEnd());
  }
  if (stats.badSamples.length) {
    L.push('', '### 필드 수가 달라 무시한 행 (샘플)');
    for (const s of stats.badSamples) L.push(`- ${s}`);
  }
  return `${L.join('\n')}\n`;
}

// ---------- 실행 ----------

/** CSV 파일 하나를 스트리밍으로 읽어 processRow 결과를 모은다 */
export async function scanCsv(path, brands, acc) {
  let headerChecked = false;
  const parser = createCsvParser((row) => {
    if (!headerChecked) {
      headerChecked = true;
      if (row.length !== EXPECTED_HEADER.length || row.some((v, i) => v !== EXPECTED_HEADER[i])) {
        const err = new Error(`헤더가 예상과 달라요: ${path}\n  기대: ${EXPECTED_HEADER.join(',')}\n  실제: ${row.join(',')}`);
        err.code = 'BAD_HEADER';
        throw err;
      }
      return;
    }
    acc.rows += 1;
    if (row.length !== EXPECTED_HEADER.length) {
      acc.badRows += 1;
      if (acc.badSamples.length < 5) acc.badSamples.push(`${row.length}개 필드: ${row.slice(0, 3).join(' | ')}`);
      return;
    }
    const result = processRow(row, brands);
    if (!result) return;
    if (result.skip) {
      acc.skipped.push({ skip: result.skip, name: result.name, id: row[COL['상가업소번호']] });
      return;
    }
    const rec = result.record;
    if (acc.seen.has(rec.external_id)) {
      acc.skipped.push({ skip: '상가업소번호 중복(첫 행만 사용)', name: rec.shop_name, id: rec.external_id });
      return;
    }
    acc.seen.add(rec.external_id);
    acc.records.push(rec);
  });
  const stream = createReadStream(path, { encoding: 'utf8', highWaterMark: 1 << 20 });
  for await (const chunk of stream) parser.feed(chunk);
  parser.end();
  if (!headerChecked) {
    const err = new Error(`빈 파일이에요: ${path}`);
    err.code = 'BAD_HEADER';
    throw err;
  }
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (name, fallback) => (args.includes(name) ? args[args.indexOf(name) + 1] : fallback);
  const rawDir = resolve(REPO_ROOT, opt('--raw', 'data/raw'));
  const brands = JSON.parse(readFileSync(resolve(REPO_ROOT, opt('--brands', 'scripts/import/brands.json')), 'utf8'));
  const files = readdirSync(rawDir).filter((f) => f.toLowerCase().endsWith('.csv') && f.includes('_서울_'));
  if (files.length === 0) {
    console.error(`${rawDir} 에 파일명에 '_서울_' 이 들어간 CSV 가 없어요.`);
    process.exit(1);
  }
  const acc = { rows: 0, badRows: 0, badSamples: [], skipped: [], records: [], seen: new Set() };
  const started = Date.now();
  for (const f of files) {
    console.log(`읽는 중: ${f}`);
    await scanCsv(join(rawDir, f), brands, acc);
  }
  console.log(`읽은 행 ${acc.rows}개, ${((Date.now() - started) / 1000).toFixed(1)}초`);

  mkdirSync(OUT_DIR, { recursive: true });
  writeFileSync(join(REPO_ROOT, 'supabase', 'seed_branches.sql'), buildSql(brands, acc.records, { files }));
  writeFileSync(join(OUT_DIR, 'branches-report.md'), buildReport(brands, acc.records, acc.skipped, { files, rows: acc.rows, badRows: acc.badRows, badSamples: acc.badSamples }));
  for (const b of brands) console.log(`${b.name}: ${acc.records.filter((r) => r.brand === b.name).length}개`);
  console.log(`건너뛴 행 ${acc.skipped.length}개 → supabase/seed_branches.sql, scripts/import/out/branches-report.md`);
}

if (isMain(import.meta.url)) {
  main().catch((e) => {
    console.error(e.code === 'BAD_HEADER' ? `중단: ${e.message}` : e);
    process.exit(1);
  });
}
