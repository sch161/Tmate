// scripts/research/out/brand-results.json(브랜드 조사 결과) → supabase/seed_brand_menus.sql(멱등)
// 실행: node scripts/import/build-brand-menus.mjs [--input scripts/research/out/brand-results.json] [--brands scripts/import/brands.json]
// Node 내장 모듈만 사용한다. 생성된 SQL 은 사람이 SQL Editor 에서 실행한다 (seed_branches.sql 다음).
import { readFileSync, writeFileSync, statSync, mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { REPO_ROOT, OUT_DIR, sqlString, sqlRequired, isMain } from './lib.mjs';

const STANDARD = JSON.parse(readFileSync(resolve(REPO_ROOT, 'scripts/research/standard-allergens.json'), 'utf8')).standard;
const ALLOWED_TASTE_TAGS = ['매콤함', '달콤함', '짭조름함', '새콤함', '고소함', '담백함', '느끼함', '쌉싸름함', '감칠맛'];
const FIXED_NOTICE = '지점에 따라 판매하지 않는 제품이 있을 수 있음';
const SET_NOTE = '공식 표는 세트 구성 기준이며 구성에 따라 알레르기가 다를 수 있습니다';
const LEVEL_MAP = { contains: 'danger', may_contain: 'caution' };
const STATUSES = ['verified', 'official_extract', 'estimated', 'unknown'];
const arr = (v) => (Array.isArray(v) ? v : []);
const str = (v) => (typeof v === 'string' ? v.trim() : '');

// ---------- 정규화·파싱 ----------

/** ®, ™, TM 기호를 지우고 공백을 정리한다. 세트 기준 브랜드는 끝에 " 세트"가 없으면 붙인다. */
export function normalizeMenuName(name, setBased) {
  let n = str(name).replace(/[®™℠]/g, '').replace(/\bTM\b/g, '').replace(/\s+/g, ' ').trim();
  if (n && setBased && !/\s?세트$/.test(n)) n = `${n} 세트`;
  return n;
}

/** 'YYYY년 M월 D일 기준' 패턴에서 날짜(YYYY-MM-DD)를 찾는다. 없으면 null (추측하지 않는다). */
export function parseDataDate(texts) {
  for (const t of texts) {
    const m = /(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일\s*기준/.exec(String(t ?? ''));
    if (!m) continue;
    const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
    if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) return `${m[1]}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  }
  return null;
}

function normalizeUrl(u) {
  try {
    const url = new URL(String(u).trim());
    return url.protocol === 'http:' || url.protocol === 'https:' ? url.href : null;
  } catch {
    return null;
  }
}

function hostOf(u) {
  try {
    return new URL(u).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
}

/** 메뉴 notes 에서 근거 없는 "단품 기준" 문장을 지운다 (공식 표는 세트/단품 여부를 확인할 수 없는 경우가 있다). */
export function sanitizeNote(note) {
  return str(note)
    .split(/(?<=[.。])\s+/)
    .filter((s) => s && !s.includes('단품 기준'))
    .join(' ')
    .trim();
}

// ---------- 메뉴 변환·검증 ----------

/** 조사 결과의 메뉴 하나를 검증·정규화한다. 반환: { menu } 또는 { skip } , 기록할 log 는 logs 에 추가 */
export function prepareMenu(raw, brand, logs, ctx = {}) {
  const name = normalizeMenuName(raw?.name, brand.allergen_table_is_set_based);
  if (!name) {
    logs.push(`[${brand.name}] 메뉴 이름이 비어 건너뜀`);
    return null;
  }
  let status = STATUSES.includes(raw.allergen_status) ? raw.allergen_status : 'unknown';
  if (status !== raw.allergen_status) logs.push(`[${brand.name}/${name}] allergen_status 값이 올바르지 않아 unknown 처리`);

  const sources = [...new Set(arr(raw.allergen_sources).map((s) => normalizeUrl(typeof s === 'string' ? s : s?.url)).filter(Boolean))];
  let allergens = [];
  const byName = new Map();
  for (const a of arr(raw.allergens)) {
    const standard = str(a?.standard_name);
    if (!STANDARD.includes(standard)) {
      logs.push(`[${brand.name}/${name}] 표준 19종에 없는 알레르기 건너뜀: ${standard || '(빈 값)'}`);
      continue;
    }
    const level = LEVEL_MAP[a?.level];
    if (!level) {
      logs.push(`[${brand.name}/${name}] 알 수 없는 level 이라 건너뜀: ${standard}(${String(a?.level)})`);
      continue;
    }
    const original = str(a.original_text) || standard;
    const prev = byName.get(standard);
    if (!prev) byName.set(standard, { standard_name: standard, level, original_text: original });
    else {
      if (!prev.original_text.split(' / ').includes(original)) prev.original_text += ` / ${original}`;
      if (level === 'danger') prev.level = 'danger';
    }
  }
  allergens = [...byName.values()];

  if ((status === 'verified' || status === 'official_extract') && sources.length === 0) {
    logs.push(`[${brand.name}/${name}] ${status} 인데 출처 URL 이 없어 unknown 으로 내림`);
    status = 'unknown';
  }
  if (status === 'unknown' && allergens.length > 0) {
    logs.push(`[${brand.name}/${name}] unknown 인데 알레르기 값이 있어 비움`);
    allergens = [];
  }

  const tags = [];
  for (const t of arr(raw.taste_tags)) {
    if (ALLOWED_TASTE_TAGS.includes(t)) {
      if (!tags.includes(t)) tags.push(t);
    } else logs.push(`[${brand.name}/${name}] 허용 목록 밖 맛 태그 건너뜀: ${String(t)}`);
  }

  let note = sanitizeNote(raw.notes);
  if (brand.allergen_table_is_set_based) note = SET_NOTE; // 세트 기준 표는 고정 문구만 쓴다 (모델의 '단품' 표현을 옮기지 않는다)
  const sourceUrl = sources[0] ?? null;
  const official = sourceUrl && arr(brand.official_domains).some((d) => hostOf(sourceUrl) === d || hostOf(sourceUrl).endsWith(`.${d}`));
  return {
    name,
    description: str(raw.description) || null,
    status,
    sourceUrl: status === 'unknown' ? null : sourceUrl,
    sources,
    checkedAt: status === 'unknown' ? null : ctx.checkedAt ?? null,
    note: note || null,
    menuSourceName: sourceUrl ? (official ? '공식 사이트' : hostOf(sourceUrl)) : null,
    menuSourceUrl: sourceUrl,
    allergens: status === 'unknown' ? [] : allergens,
    tags,
  };
}

// ---------- SQL ----------

const brandMatch = (b) => `b.name = ${sqlRequired(b.name)} and b.is_franchise`;

function menuSql(brand, m) {
  const L = [];
  L.push(`-- ${brand.name} / ${m.name}`);
  L.push('insert into menus (brand_id, name, description, allergen_status, allergen_source_url, allergen_checked_at, allergen_note, menu_source_url, menu_source_name)');
  L.push(
    `select b.id, ${sqlRequired(m.name)}, ${sqlString(m.description)}, ${sqlRequired(m.status)}::allergen_status, ${sqlString(m.sourceUrl)}, ` +
      `${m.checkedAt ? `${sqlRequired(m.checkedAt)}::timestamptz` : 'null::timestamptz'}, ${sqlString(m.note)}, ${sqlString(m.menuSourceUrl)}, ${sqlString(m.menuSourceName)}`,
  );
  L.push(`from brands b where ${brandMatch(brand)}`);
  L.push('on conflict (brand_id, name) do update set');
  L.push('  description = excluded.description, allergen_status = excluded.allergen_status, allergen_source_url = excluded.allergen_source_url,');
  L.push('  allergen_checked_at = excluded.allergen_checked_at, allergen_note = excluded.allergen_note,');
  L.push('  menu_source_url = excluded.menu_source_url, menu_source_name = excluded.menu_source_name;');
  const menuIds = `select m.id from menus m join brands b on b.id = m.brand_id where ${brandMatch(brand)} and m.name = ${sqlRequired(m.name)}`;
  L.push(`delete from menu_allergens where menu_id in (${menuIds});`);
  if (m.allergens.length > 0) {
    L.push('insert into menu_allergens (menu_id, allergen_id, level, original_text)');
    L.push('select m.id, a.id, v.level::allergen_level, v.original_text');
    L.push('from menus m join brands b on b.id = m.brand_id');
    L.push(`cross join (values ${m.allergens.map((a) => `(${sqlRequired(a.standard_name)}, ${sqlRequired(a.level)}, ${sqlRequired(a.original_text)})`).join(', ')}) as v(name, level, original_text)`);
    L.push('join allergens a on a.name = v.name');
    L.push(`where ${brandMatch(brand)} and m.name = ${sqlRequired(m.name)};`);
  }
  L.push(`delete from menu_taste_tags where menu_id in (${menuIds});`);
  if (m.tags.length > 0) {
    L.push('insert into menu_taste_tags (menu_id, taste_tag_id)');
    L.push('select m.id, t.id');
    L.push('from menus m join brands b on b.id = m.brand_id');
    L.push(`cross join (values ${m.tags.map((t) => `(${sqlRequired(t)})`).join(', ')}) as v(name)`);
    L.push('join taste_tags t on t.name = v.name');
    L.push(`where ${brandMatch(brand)} and m.name = ${sqlRequired(m.name)};`);
  }
  L.push('');
  return L;
}

/**
 * @param results brand-results.json 배열, @param brands brands.json 배열, @param opts { checkedAt }
 * @returns { sql, logs, names:{[brand]:string[]}, brandsDone:string[] }
 */
export function buildSql(results, brands, opts = {}) {
  const logs = [];
  const names = {};
  const out = [];
  out.push('-- =====================================================================');
  out.push('-- seed_brand_menus.sql — 브랜드 조사 결과(brands·menus·menu_allergens·menu_taste_tags). scripts/import/build-brand-menus.mjs 가 생성, 직접 수정하지 않는다.');
  out.push('-- 멱등: menus 는 (brand_id, name) upsert, menu_allergens·menu_taste_tags 는 메뉴별로 지우고 다시 넣는다.');
  out.push('-- 실행 순서: seed_branches.sql 먼저(브랜드가 없으면 아래에서 예외) → 이 파일');
  out.push('-- =====================================================================');
  out.push('begin;', '');
  const done = [];
  for (const brand of brands) {
    const entry = results.find((r) => r?.input?.brand === brand.result_key || r?.input?.name === brand.result_key);
    if (!entry || !entry.result) {
      logs.push(`[${brand.name}] 조사 결과가 없어 건너뜀 (result_key=${brand.result_key})`);
      continue;
    }
    const res = entry.result;
    const menus = arr(res.menus).map((m) => prepareMenu(m, brand, logs, opts)).filter(Boolean);
    // 같은 이름이 두 번 나오면 뒤의 것을 버린다 (unique(brand_id, name))
    const seen = new Set();
    const unique = menus.filter((m) => {
      if (seen.has(m.name)) {
        logs.push(`[${brand.name}/${m.name}] 중복 메뉴 이름이라 뒤의 것 건너뜀`);
        return false;
      }
      seen.add(m.name);
      return true;
    });
    names[brand.name] = unique.map((m) => m.name);

    const count = new Map();
    for (const m of unique) for (const u of m.sources) count.set(u, (count.get(u) ?? 0) + 1);
    const topUrl = [...count.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))[0]?.[0] ?? null;
    const date = parseDataDate([...arr(res.warnings), ...arr(res.menus).map((m) => m?.notes), res.shared_notice]);
    let notice = str(res.shared_notice);
    if (!notice.includes(FIXED_NOTICE)) notice = [notice, FIXED_NOTICE].filter(Boolean).join(' / ');
    if (!date) logs.push(`[${brand.name}] 'YYYY년 M월 D일 기준' 날짜를 찾지 못해 allergen_data_date 는 null`);

    out.push(`-- ===== ${brand.name} (메뉴 ${unique.length}개) =====`);
    out.push('do $$');
    out.push('begin');
    out.push(`  if not exists (select 1 from brands b where ${brandMatch(brand)}) then`);
    out.push(`    raise exception '브랜드 ${brand.name} 이(가) 없어요. seed_branches.sql 을 먼저 실행하세요.';`);
    out.push('  end if;');
    out.push('end;');
    out.push('$$;');
    out.push('update brands b set');
    out.push(`  allergen_source_url = ${sqlString(topUrl)}, allergen_data_date = ${date ? `${sqlRequired(date)}::date` : 'null::date'},`);
    out.push(`  shared_notice = ${sqlString(notice)}, research_status = 'done', researched_at = now(), research_error = null`);
    out.push(`where ${brandMatch(brand)};`);
    out.push('');
    for (const m of unique) out.push(...menuSql(brand, m));
    done.push(brand.name);
  }
  out.push('commit;');
  return { sql: `${out.join('\n')}\n`, logs, names, brandsDone: done };
}

// ---------- 실행 ----------

function main() {
  const args = process.argv.slice(2);
  const opt = (name, fallback) => (args.includes(name) ? args[args.indexOf(name) + 1] : fallback);
  const input = resolve(REPO_ROOT, opt('--input', 'scripts/research/out/brand-results.json'));
  const brands = JSON.parse(readFileSync(resolve(REPO_ROOT, opt('--brands', 'scripts/import/brands.json')), 'utf8'));
  const results = JSON.parse(readFileSync(input, 'utf8'));
  const checkedAt = statSync(input).mtime.toISOString();
  const { sql, logs, names, brandsDone } = buildSql(results, brands, { checkedAt });

  mkdirSync(OUT_DIR, { recursive: true });
  writeFileSync(join(REPO_ROOT, 'supabase', 'seed_brand_menus.sql'), sql);
  const report = ['# 브랜드 메뉴 import 기록', '', `- 입력: ${input} (수정일 ${checkedAt})`, `- 처리한 브랜드: ${brandsDone.join(', ') || '(없음)'}`, '', '## 최종 메뉴 이름']
    .concat(Object.entries(names).flatMap(([b, list]) => [`### ${b}`, ...list.map((n) => `- ${n}`)]))
    .concat(['', '## 건너뛰거나 바꾼 항목', ...(logs.length ? logs.map((l) => `- ${l}`) : ['- (없음)'])]);
  writeFileSync(join(OUT_DIR, 'brand-menus-report.md'), `${report.join('\n')}\n`);

  for (const [b, list] of Object.entries(names)) console.log(`${b}: ${list.join(', ')}`);
  console.log(`기록 ${logs.length}건:`);
  for (const l of logs) console.log(`  - ${l}`);
  console.log(`→ supabase/seed_brand_menus.sql (${sql.split('\n').length - 1}줄)`);
}

if (isMain(import.meta.url)) main();
