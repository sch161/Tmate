// AI 조사 PoC: 가게 이름+주소 → OpenAI Responses API(web_search) 로 메뉴·알레르기·맛 태그 조사 → 코드로 검증.
// 로컬 전용 스크립트. 앱(src/)·DB 와 무관하다. Node 내장 fetch 만 사용한다.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(HERE, 'out');
const API_BASE = 'https://api.openai.com/v1';

// 모델 이름은 환경변수로만 받는다. 기본값만 여기 한 곳에 둔다. 자동 모델 전환은 하지 않는다.
const DEFAULT_MODEL = 'gpt-6.1-sol';
const SOURCES_INCLUDE = 'web_search_call.action.sources';
export const ALLOWED_TASTE_TAGS = ['매콤함', '달콤함', '짭조름함', '새콤함', '고소함', '담백함', '느끼함', '쌉싸름함', '감칠맛'];
const ESTIMATE_PHRASE = '일반 조리법 기준 추정';
// verified: 공식 페이지 본문을 직접 읽음 / official_extract: 공식 도메인 검색 결과 발췌에서만 읽음(본문 재확인 못 함)
const STATUSES = ['verified', 'official_extract', 'estimated', 'unknown'];
const BRAND_MENU_LIMIT = 10;
const BRAND_FIXED_NOTICE = '지점에 따라 판매하지 않는 제품이 있을 수 있음';
const DEFAULT_BRAND_MAX_OUTPUT_TOKENS = 32000; // reasoning 가이드: 추론+출력에 최소 25,000 토큰 확보 권장
const LEVELS = ['contains', 'may_contain'];

const ALLERGENS = JSON.parse(readFileSync(join(HERE, 'standard-allergens.json'), 'utf8'));

// ---------- URL 정규화 ----------

const TRACKING_PARAMS = new Set(['gclid', 'fbclid', 'msclkid', 'mc_cid', 'mc_eid', 'igshid']);

/** 추적 파라미터(utm_* 등)·fragment 제거, 호스트 소문자화, 끝 슬래시 제거. http(s) 가 아니면 null. */
export function normalizeUrl(input) {
  if (typeof input !== 'string') return null;
  let url;
  try {
    url = new URL(input.trim());
  } catch {
    return null;
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
  url.hash = '';
  const kept = [...url.searchParams.entries()]
    .filter(([key]) => !key.toLowerCase().startsWith('utm_') && !TRACKING_PARAMS.has(key.toLowerCase()))
    .sort(([a], [b]) => a.localeCompare(b));
  url.search = '';
  for (const [key, value] of kept) url.searchParams.append(key, value);
  const path = url.pathname.replace(/\/+$/, '');
  return `${url.protocol}//${url.host}${path}${url.search}`;
}

function hostMatchesDomain(urlString, domain) {
  try {
    const host = new URL(urlString).hostname.toLowerCase();
    const d = domain.toLowerCase();
    return host === d || host.endsWith(`.${d}`);
  } catch {
    return false;
  }
}

// ---------- 알레르기 이름 ----------

/** 표준 이름 또는 별칭이면 표준 이름, 아니면 null(미등록). */
export function toStandardAllergen(name) {
  if (typeof name !== 'string') return null;
  const key = name.trim();
  if (ALLERGENS.standard.includes(key)) return key;
  return Object.hasOwn(ALLERGENS.aliases, key) ? ALLERGENS.aliases[key] : null;
}

// ---------- 후처리 검증 (모델 응답을 믿지 않고 코드로 강제) ----------

const str = (v) => (typeof v === 'string' ? v.trim() : '');
const arr = (v) => (Array.isArray(v) ? v : []);

/**
 * @param raw 모델이 돌려준 객체(파싱 후)
 * @param ctx { place:{name,address,is_franchise,brand,official_domains}, knownUrls:Set<정규화 URL> }
 * @returns { result, stats:{demoted, removedAllergens, removedTags, menus:{verified,estimated,unknown}} }
 */
export function validateResult(raw, ctx) {
  const input = ctx.place;
  const warnings = [];
  const stats = { demoted: 0, removedAllergens: 0, removedTags: 0 };
  const src = raw && typeof raw === 'object' ? raw : {};
  const officialDomains = arr(input.official_domains).map(String);

  const normList = (list) => [...new Set(arr(list).map((u) => normalizeUrl(typeof u === 'string' ? u : u?.url)).filter(Boolean))];

  const menus = arr(src.menus).filter((m) => m && typeof m === 'object' && str(m.name)).map((m) => {
    const name = str(m.name);
    let description = str(m.description);
    if (description.length > 20) {
      description = description.slice(0, 20);
      warnings.push(`[${name}] description 20자 초과 → 잘라냄`);
    }

    const tagSet = new Set();
    for (const tag of arr(m.taste_tags)) {
      if (ALLOWED_TASTE_TAGS.includes(tag)) tagSet.add(tag);
      else {
        stats.removedTags += 1;
        warnings.push(`[${name}] 허용 목록 밖 맛 태그 제거: ${String(tag)}`);
      }
    }
    const taste_tags = [...tagSet].slice(0, 3);

    // 알레르기: 표준 이름으로 합치고 원문은 보관, 미등록·잘못된 level 은 제거
    const byName = new Map();
    for (const a of arr(m.allergens)) {
      const standard = toStandardAllergen(a?.standard_name);
      if (!standard) {
        stats.removedAllergens += 1;
        warnings.push(`[${name}] 미등록 알레르기 이름 제거: ${String(a?.standard_name)}`);
        continue;
      }
      if (!LEVELS.includes(a?.level)) {
        stats.removedAllergens += 1;
        warnings.push(`[${name}] 알레르기 level 이 올바르지 않아 제거: ${standard}`);
        continue;
      }
      const original = str(a.original_text) || str(a.standard_name);
      const prev = byName.get(standard);
      if (!prev) byName.set(standard, { standard_name: standard, original_text: original, level: a.level });
      else {
        if (!prev.original_text.split(' / ').includes(original)) prev.original_text += ` / ${original}`;
        if (a.level === 'contains') prev.level = 'contains';
      }
    }
    let allergens = [...byName.values()];

    let allergen_status = STATUSES.includes(m.allergen_status) ? m.allergen_status : 'unknown';
    if (allergen_status !== m.allergen_status) warnings.push(`[${name}] allergen_status 값이 올바르지 않아 unknown 처리`);
    const allergen_sources = normList(m.allergen_sources).map((url) => ({ url }));
    let notes = str(m.notes);

    const demote = (reason) => {
      stats.demoted += 1;
      warnings.push(`[${name}] ${allergen_status} → unknown 강등: ${reason}`);
      if (allergens.length > 0) {
        notes += `${notes ? ' ' : ''}[강등 전 알레르기: ${allergens.map((a) => `${a.standard_name}(${a.original_text})`).join(', ')}]`;
      }
      allergens = [];
      allergen_status = 'unknown';
    };

    if (allergen_status === 'verified' || allergen_status === 'official_extract') {
      const urls = allergen_sources.map((s) => s.url);
      // official_extract 는 응답의 sources 목록에 있어야 한다 (sourceUrls 를 주지 않으면 sources+annotations)
      const pool = allergen_status === 'official_extract' && ctx.sourceUrls ? ctx.sourceUrls : ctx.knownUrls;
      if (urls.length === 0) demote('출처 없음');
      else if (urls.some((u) => !pool.has(u))) demote(`출처 URL 이 응답의 ${pool === ctx.knownUrls ? 'sources/annotations' : 'sources'} 에 없음`);
      else if (!urls.some((u) => officialDomains.some((d) => hostMatchesDomain(u, d)))) {
        demote(`공식 도메인 출처 없음(공식 출처가 확인되지 않으면 ${allergen_status} 불가)`);
      }
    } else if (allergen_status === 'estimated' && !notes.includes(ESTIMATE_PHRASE)) {
      demote(`notes 에 "${ESTIMATE_PHRASE}" 명시 없음`);
    } else if (allergen_status === 'unknown' && allergens.length > 0) {
      stats.demoted += 1;
      warnings.push(`[${name}] unknown 인데 알레르기 값이 있어 비움`);
      allergens = [];
    }

    return { name, description, taste_tags, allergens, allergen_status, allergen_sources, notes };
  });

  if (input.mode === 'brand' && menus.length > BRAND_MENU_LIMIT) {
    warnings.push(`대표 메뉴 ${BRAND_MENU_LIMIT}개 초과 → 앞 ${BRAND_MENU_LIMIT}개만 사용 (${menus.length}개 반환됨)`);
    menus.length = BRAND_MENU_LIMIT;
  }
  const modelWarnings = arr(src.warnings).map(String);
  // 브랜드 모드: 지점별 판매 여부는 판단하지 않으므로 고정 문구를 항상 덧붙인다
  const notice = [str(src.shared_notice), input.mode === 'brand' ? BRAND_FIXED_NOTICE : ''].filter(Boolean).join(' / ');
  const result = {
    place: {
      name: str(src.place?.name) || input.name,
      address: str(src.place?.address) || input.address || '',
      is_franchise: Boolean(input.is_franchise),
      brand: input.brand ?? null,
    },
    menus,
    shared_notice: notice || null,
    sources_used: normList(src.sources_used),
    not_found: arr(src.not_found).map(String),
    warnings: [...modelWarnings, ...warnings],
  };
  const menuCounts = { verified: 0, official_extract: 0, estimated: 0, unknown: 0 };
  for (const m of menus) menuCounts[m.allergen_status] += 1;
  return { result, stats: { ...stats, menus: menuCounts } };
}

/** 모델 텍스트에서 JSON 객체를 꺼낸다 (구조화 출력이 web_search 와 함께 쓸 수 있다는 문서 근거가 없어 텍스트로 받는다). */
export function parseModelJson(text) {
  const trimmed = String(text ?? '').trim();
  const candidates = [trimmed, trimmed.replace(/^```(?:json)?\s*|\s*```$/g, '')];
  const first = trimmed.indexOf('{');
  const last = trimmed.lastIndexOf('}');
  if (first >= 0 && last > first) candidates.push(trimmed.slice(first, last + 1));
  for (const c of candidates) {
    try {
      const parsed = JSON.parse(c);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) return parsed;
    } catch {
      // 다음 후보
    }
  }
  return null;
}

/** Responses API 응답에서 텍스트·검색 호출 수·조회 URL·인용 URL 을 모은다. */
export function extractResponse(resp) {
  let text = '';
  let searchCalls = 0;
  const sources = [];
  const citations = [];
  for (const item of arr(resp?.output)) {
    if (item?.type === 'web_search_call') {
      searchCalls += 1;
      for (const s of arr(item.action?.sources)) if (s?.url) sources.push(s.url);
    } else if (item?.type === 'message') {
      for (const c of arr(item.content)) {
        if (c?.type !== 'output_text') continue;
        text += c.text ?? '';
        for (const a of arr(c.annotations)) if (a?.type === 'url_citation' && a.url) citations.push(a.url);
      }
    }
  }
  const knownUrls = new Set([...sources, ...citations].map(normalizeUrl).filter(Boolean));
  const sourceUrls = new Set(sources.map(normalizeUrl).filter(Boolean));
  return { text, searchCalls, knownUrls, sourceUrls, sourceCount: sources.length, citationCount: citations.length };
}

// ---------- 모델 지시문 ----------

const BRAND_RULES = [
  '',
  '브랜드 조사 모드(지점이 아니라 브랜드 단위):',
  `- 입력은 브랜드와 공식 도메인이다. 그 브랜드 공통 정규 메뉴 중 대표 메뉴 ${BRAND_MENU_LIMIT}개(버거류 중심)의 알레르기를 조사한다. 메뉴는 ${BRAND_MENU_LIMIT}개를 넘기지 마라.`,
  '- 지점별 판매 여부는 판단하지 마라. "지점에 따라 판매하지 않는다"는 공지가 있어도 메뉴를 비우지 말고 공통 정규 메뉴 기준으로 채워라.',
  '- 알레르기 표가 페이지 로드 후 동적으로 채워져 본문이 비어 보이면, 검색 결과 발췌에 나온 공식 표 값이나 개별 메뉴 상세 페이지를 사용하라.',
  '- 표가 세트 단위면 메뉴 이름은 표의 행 이름 그대로 쓰고 notes 에 "세트 기준 표기"를 적어라.',
  '- 원문이 "조개, 굴"처럼 나뉘어 있어도 original_text 에는 공식 표기를 그대로 적고, 표준 이름은 항목마다 적어라(합치기는 코드가 한다).',
  '- shared_notice 에는 브랜드 공통 조리기구 공유·조리 기름 혼용 공지만 적어라.',
];

export function buildInstructions(mode = 'place') {
  return [
    '너는 한국 음식점의 메뉴·알레르기 정보를 웹에서 조사하는 조사원이다. 결과는 반드시 아래 JSON 객체 하나만 출력한다(코드블록·설명문 금지).',
    '',
    '규칙:',
    '- 기억에 의존하지 마라. 근거는 실제로 열어 본 페이지 본문, 또는 공식 도메인 검색 결과 발췌(이 경우 반드시 official_extract 로 표시)뿐이다. 발췌에서 읽은 공식 값을 버리지 마라.',
    '- 공식 사이트를 우선하라.',
    '- 접근이 막혀 있으면 그 사실을 warnings 에 보고하고 우회하지 마라.',
    '- 확신이 없으면 값을 채우지 말고 unknown 으로 둬라. 채운 값보다 정직한 빈칸이 낫다.',
    '- 가게가 모호하면(같은 이름·건물에 여러 후보) 추측하지 말고 후보를 not_found 또는 warnings 에 적어 반환하라.',
    '- 알레르기는 공식 페이지에서 확인된 메뉴만 채우고, 공식 표기를 그대로 original_text 에 옮겨라. 일반 레시피로 추측해서 채우지 마라.',
    '- 공식 정보가 메뉴 단위가 아니라 재료 단위(빵·소스별 등)면 메뉴 단위로 합치지 말고 notes 에 구조를 설명하라.',
    '- 조리기구 공유·조리 기름 혼용 같은 가게·브랜드 공지는 shared_notice 에 적어라.',
    '- 메뉴를 찾지 못했으면 지어내지 말고 menus 를 빈 배열로 둬라.',
    '- allergen_status: 공식 페이지 본문을 직접 열어 읽었으면 "verified", 공식 도메인 URL 의 검색 결과 발췌에서만 읽었고 본문 재확인은 못 했으면 "official_extract"(둘 다 allergen_sources 에 그 공식 페이지 URL 필수), 일반 조리법 기준 추정이면 "estimated"(notes 에 "일반 조리법 기준 추정" 명시), 모르면 "unknown"(allergens 는 빈 배열).',
    '- description 은 직접 작성한 20자 이내 문구. 공식 문구를 복사하지 마라.',
    `- taste_tags 는 다음 중 1~3개(추정값): ${ALLOWED_TASTE_TAGS.join(', ')}`,
    `- allergens.standard_name 은 식약처 19종 중 하나: ${ALLERGENS.standard.join(', ')}. level 은 함유가 명시되면 "contains", 혼입 가능성 표기(같은 설비·교차 오염 등)면 "may_contain".`,
    ...(mode === 'brand' ? BRAND_RULES : []),
    '',
    '출력 JSON 형식:',
    JSON.stringify(
      {
        place: { name: '', address: '', is_franchise: false, brand: null },
        menus: [
          {
            name: '',
            description: '',
            taste_tags: [],
            allergens: [{ standard_name: '', original_text: '', level: 'contains' }],
            allergen_status: 'unknown',
            allergen_sources: [{ url: '' }],
            notes: '',
          },
        ],
        shared_notice: null,
        sources_used: [''],
        not_found: [],
        warnings: [],
      },
      null,
      2,
    ),
  ].join('\n');
}

// ---------- OpenAI 호출 ----------

export class ApiError extends Error {
  constructor(status, body) {
    super(`HTTP ${status}`);
    this.status = status;
    this.body = body;
  }
}

/** 오류 본문에 키가 섞여 나오는 일을 막는다. */
function redact(text) {
  let out = String(text);
  const key = process.env.OPENAI_API_KEY;
  if (key) out = out.split(key).join('[REDACTED]');
  return out.replace(/sk-[A-Za-z0-9_\-*.]{6,}/g, '[REDACTED]');
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** 429/5xx 는 지수 백오프로 최대 2회 재시도. 그 외 오류(모델 없음·권한·미지원 등)는 재시도 없이 ApiError. */
async function apiRequest(method, path, body, timeoutMs) {
  for (let attempt = 0; ; attempt += 1) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    let res;
    let text;
    try {
      res = await fetch(`${API_BASE}${path}`, {
        method,
        headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });
      text = await res.text();
    } catch (e) {
      if (e?.name === 'AbortError') throw new Error(`요청 타임아웃(${timeoutMs}ms)`);
      throw new Error(`네트워크 오류: ${redact(e?.message ?? e)}`);
    } finally {
      clearTimeout(timer);
    }
    if (res.ok) return JSON.parse(text);
    if ((res.status === 429 || res.status >= 500) && attempt < 2) {
      await sleep(2000 * 2 ** attempt);
      continue;
    }
    throw new ApiError(res.status, redact(text));
  }
}

export function buildRequestBody(place, options) {
  const tool = {
    type: 'web_search', // web_search_preview 는 쓰지 않는다
    user_location: { type: 'approximate', country: 'KR' },
    search_context_size: 'low',
  };
  const domains = arr(place.official_domains);
  if (place.is_franchise && domains.length > 0) tool.filters = { allowed_domains: domains }; // 도메인만, http 접두사 없이
  const brandMode = place.mode === 'brand';
  const body = {
    model: options.model,
    instructions: buildInstructions(place.mode),
    input: brandMode
      ? `다음 브랜드의 대표 메뉴 알레르기를 조사하라.\n${JSON.stringify({ brand: place.brand, official_domains: domains })}`
      : `다음 가게를 조사하라.\n${JSON.stringify({ name: place.name, address: place.address, brand: place.brand ?? null, is_franchise: place.is_franchise, official_domains: domains })}`,
    tools: [tool],
    tool_choice: 'required',
    include: [SOURCES_INCLUDE],
    reasoning: { effort: options.effort },
  };
  if (options.maxToolCalls) body.max_tool_calls = options.maxToolCalls;
  if (options.maxOutputTokens) body.max_output_tokens = options.maxOutputTokens; // 추론 토큰 + 출력 토큰 상한 (최소 16)
  if (options.background) body.background = true;
  return body;
}

async function callResponses(place, options) {
  const body = buildRequestBody(place, options);
  let resp = await apiRequest('POST', '/responses', body, options.timeoutMs);
  if (!options.background) return resp;
  // background: 3초 간격 폴링, 최대 10분. queued/in_progress 동안만 계속한다.
  const deadline = Date.now() + 10 * 60 * 1000;
  const query = new URLSearchParams();
  query.append('include[]', SOURCES_INCLUDE);
  while (resp.status === 'queued' || resp.status === 'in_progress') {
    if (Date.now() > deadline) throw new Error('background 폴링 10분 초과');
    await sleep(3000);
    resp = await apiRequest('GET', `/responses/${encodeURIComponent(resp.id)}?${query}`, null, options.timeoutMs);
  }
  return resp;
}

// ---------- 가게 한 곳 처리 ----------

function normalizePlace(p, brandMode = false) {
  const domains = arr(p.official_domains).map(String);
  if (brandMode) return { name: p.brand, address: '', brand: p.brand, is_franchise: true, official_domains: domains, mode: 'brand' };
  return { name: p.name, address: p.address, brand: p.brand ?? null, is_franchise: Boolean(p.brand) || domains.length > 0, official_domains: domains };
}

async function researchPlace(rawPlace, options) {
  const place = normalizePlace(rawPlace, options.brandMode);
  const started = Date.now();
  const entry = { input: place, model: options.model, mode: options.background ? 'background' : 'sync', max_output_tokens: options.maxOutputTokens || null };
  try {
    const resp = await callResponses(place, options);
    const ex = extractResponse(resp);
    entry.response_id = resp.id ?? null;
    entry.status = resp.status ?? null;
    entry.usage = {
      input_tokens: resp.usage?.input_tokens ?? null,
      output_tokens: resp.usage?.output_tokens ?? null,
      reasoning_tokens: resp.usage?.output_tokens_details?.reasoning_tokens ?? null,
      cached_tokens: resp.usage?.input_tokens_details?.cached_tokens ?? null,
    };
    entry.web_search_calls = ex.searchCalls;
    entry.source_urls = ex.sourceCount;
    entry.citation_urls = ex.citationCount;
    entry.incomplete_reason = resp.incomplete_details?.reason ?? null;
    if (resp.status && resp.status !== 'completed') {
      // 잘림(incomplete, 예: max_output_tokens)도 여기서 기록해 보고서에 남긴다
      entry.error = `응답 상태: ${resp.status}${entry.incomplete_reason ? ` (incomplete_details.reason=${entry.incomplete_reason})` : ''}${resp.error ? ` (${resp.error.code ?? ''} ${resp.error.message ?? ''})` : ''}`;
    }
    const parsed = parseModelJson(ex.text);
    if (!parsed) entry.error = `${entry.error ? `${entry.error}; ` : ''}모델 응답에서 JSON 을 파싱하지 못했어요`;
    const { result, stats } = validateResult(parsed, { place, knownUrls: ex.knownUrls, sourceUrls: ex.sourceUrls });
    if (!parsed) result.warnings.push('모델 응답 JSON 파싱 실패 → 빈 결과');
    entry.result = result;
    entry.stats = stats;
  } catch (e) {
    if (e instanceof ApiError && [400, 401, 403, 404].includes(e.status)) {
      e.place = place.name;
      throw e; // 모델 없음·권한·미지원 등: 호출한 쪽에서 본문을 그대로 출력하고 종료
    }
    entry.error = e instanceof Error ? e.message : String(e);
    if (e instanceof ApiError) entry.error += `: ${e.body}`;
  }
  entry.elapsed_sec = Math.round((Date.now() - started) / 100) / 10;
  return entry;
}

// ---------- 보고서 ----------

function loadPricing(model) {
  try {
    const p = JSON.parse(readFileSync(join(HERE, 'pricing.json'), 'utf8'));
    const m = p.models?.[model] ?? {};
    return { input: m.input_per_1m_tokens ?? null, cached: m.cached_input_per_1m_tokens ?? null, output: m.output_per_1m_tokens ?? null, search: p.web_search_per_1k_calls ?? null };
  } catch {
    return { input: null, cached: null, output: null, search: null };
  }
}

export function estimateCost(entry, pricing) {
  if (pricing.input === null || pricing.output === null || !entry.usage || entry.usage.input_tokens === null) return null;
  const cachedTokens = entry.usage.cached_tokens ?? 0;
  const cachedRate = pricing.cached ?? pricing.input;
  const tokenCost =
    ((entry.usage.input_tokens - cachedTokens) / 1e6) * pricing.input + (cachedTokens / 1e6) * cachedRate + ((entry.usage.output_tokens ?? 0) / 1e6) * pricing.output;
  const searchCost = pricing.search === null ? 0 : ((entry.web_search_calls ?? 0) / 1000) * pricing.search;
  return tokenCost + searchCost;
}

export function buildReport(entries, options) {
  const pricing = loadPricing(options.model);
  const priced = pricing.input !== null && pricing.output !== null;
  const lines = [];
  lines.push('# AI 조사 PoC 보고서', '', `- 모델: ${options.model} (OPENAI_MODEL ${process.env.OPENAI_MODEL ? '지정' : '미지정 → 기본값'})`);
  lines.push(`- 모드: ${options.background ? 'background (3초 폴링, 최대 10분)' : '동기'} / reasoning effort: ${options.effort} / search_context_size: low`);
  lines.push(`- 단가: ${priced ? '설정됨 (pricing.json)' : '단가 미설정 — 토큰·호출 수만 표시'}${priced && pricing.search === null ? ' / 검색 호출 단가 미설정(검색 비용 제외)' : ''}`, '');
  if (options.brandMode) lines.push(`- 브랜드 모드: 대표 메뉴 ${BRAND_MENU_LIMIT}개 / max_output_tokens: ${options.maxOutputTokens || '미설정'} (추론+출력 상한)`);
  lines.push(options.brandMode ? '## 브랜드별 요약' : '## 가게별 요약', '');
  lines.push(`| ${options.brandMode ? '브랜드' : '가게'} | 응답 상태 | 메뉴 수 | verified | official_extract | estimated | unknown | 강등 | 제거(알레르기/태그) | 소요(초) | 검색 호출 | 입력 토큰 | 출력 토큰 | 추정 비용(USD) |`);
  lines.push('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  const costs = [];
  for (const e of entries) {
    const cost = estimateCost(e, pricing);
    if (cost !== null) costs.push(cost);
    const s = e.stats;
    lines.push(
      `| ${e.input.name} | ${e.status ?? '-'}${e.incomplete_reason ? `(잘림: ${e.incomplete_reason})` : ''} | ${e.result?.menus.length ?? '-'} | ${s?.menus.verified ?? '-'} | ${s?.menus.official_extract ?? '-'} | ${s?.menus.estimated ?? '-'} | ${s?.menus.unknown ?? '-'} | ${s?.demoted ?? '-'} | ${s ? `${s.removedAllergens}/${s.removedTags}` : '-'} | ${e.elapsed_sec} | ${e.web_search_calls ?? '-'} | ${e.usage?.input_tokens ?? '-'} | ${e.usage?.output_tokens ?? '-'} | ${cost === null ? (priced ? '-' : '단가 미설정') : cost.toFixed(4)} |`,
    );
  }
  lines.push('');
  if (costs.length > 0) lines.push(`- 가게당 추정 비용: 평균 ${(costs.reduce((a, b) => a + b, 0) / costs.length).toFixed(4)} USD / 최대 ${Math.max(...costs).toFixed(4)} USD`, '');
  const times = entries.map((e) => e.elapsed_sec);
  lines.push(`- 가게당 소요 시간: 평균 ${(times.reduce((a, b) => a + b, 0) / Math.max(times.length, 1)).toFixed(1)}초 / 최대 ${Math.max(0, ...times)}초`, '');
  lines.push('## 가게별 warnings / 오류', '');
  for (const e of entries) {
    lines.push(`### ${e.input.name}`);
    if (e.error) lines.push(`- 오류: ${e.error}`);
    if (e.result?.shared_notice) lines.push(`- shared_notice: ${e.result.shared_notice}`);
    if (e.result?.not_found.length) lines.push(`- not_found: ${e.result.not_found.join(' / ')}`);
    for (const w of e.result?.warnings ?? []) lines.push(`- ${w}`);
    if (!e.error && !e.result?.warnings.length) lines.push('- (없음)');
    lines.push('');
  }
  lines.push('## 공식 문서 확인 현황', '');
  lines.push(
    '- 확인됨: web_search 도구(`web_search_preview` 는 filters 미지원), tool_choice "required", user_location(approximate, country 2글자 코드), filters.allowed_domains(http 접두사 없이, 하위 도메인 포함), search_context_size(low/medium/high), include `web_search_call.action.sources`, url_citation annotation, background 요청·retrieve(GET /v1/responses/{id}), max_tool_calls',
    '- 확인됨: reasoning effort 값 목록(none/minimal/low/medium/high/xhigh/max). 모델별 지원 값 중 gpt-6.1-sol 은 none·minimal 을 거부하고 기본 medium 이라 low 사용',
    '- 확인됨: max_output_tokens(정수, 최소 16, 추론 토큰+출력 토큰 합산 상한), 상한 초과 시 status=incomplete + incomplete_details.reason=max_output_tokens, 추론 모델은 25,000 토큰 이상 확보 권장',
    '- 미확인: max_output_tokens 의 모델별 최대값, 응답 status 전체 enum(incomplete_details.reason 의 max_output_tokens 외 값은 요약 기준)',
    '- 미확인: 구조화 출력(json_schema)과 web_search 동시 사용 가능 여부 → 텍스트 JSON 을 받아 코드로 검증',
    '- 미확인: background 모드에서 web_search(내장 도구) 지원 여부, retrieve 의 `include[]` 쿼리 배열 표기 방식, 응답 status 전체 enum, 모델 없음·권한 오류의 HTTP 본문 형식, 검색 호출 단가(가격표 직접 확인 필요)',
    '- 미확인: 인용 URL 의 utm_source=openai 부착 규칙(문서에 없음. 사용자 관찰 기준으로 정규화에서 제거)',
  );
  return `${lines.join('\n')}\n`;
}

// ---------- 실행 ----------

const SAMPLE_PLACE = { name: '샘플 개인 식당', address: '서울 관악구 샘플로 1', brand: null, official_domains: [] };
const SAMPLE_FRANCHISE = { name: '샘플 버거', address: '서울 구로구 샘플로 2', brand: '샘플', official_domains: ['sample-burger.co.kr'] };

function dryRun() {
  const known = new Set(['https://www.sample-burger.co.kr/menu/1', 'https://blog.example.com/review'].map(normalizeUrl));
  const franchiseRaw = {
    place: { name: '샘플 버거' },
    menus: [
      { name: '불고기버거', description: '달콤한 불고기가 들어간 대표 버거입니다 정말로', taste_tags: ['달콤함', '매운맛'], allergen_status: 'verified', allergen_sources: [{ url: 'https://WWW.sample-burger.co.kr/menu/1/?utm_source=openai#top' }], allergens: [{ standard_name: '난류', original_text: '난류', level: 'contains' }, { standard_name: '달걀', original_text: '달걀', level: 'may_contain' }, { standard_name: '갑각류', original_text: '갑각류', level: 'contains' }], notes: '' },
      { name: '치즈버거', description: '치즈 버거', taste_tags: ['고소함'], allergen_status: 'verified', allergen_sources: [{ url: 'https://not-fetched.example.com/x' }], allergens: [{ standard_name: '우유', original_text: '우유', level: 'contains' }], notes: '' },
    ],
    sources_used: ['https://www.sample-burger.co.kr/menu/1?utm_medium=x'],
  };
  const individualRaw = {
    menus: [
      { name: '손칼국수', description: '담백한 칼국수', taste_tags: ['담백함'], allergen_status: 'verified', allergen_sources: [{ url: 'https://blog.example.com/review' }], allergens: [{ standard_name: '밀', original_text: '밀', level: 'contains' }], notes: '' },
      { name: '만두', description: '고기만두', taste_tags: ['감칠맛'], allergen_status: 'estimated', allergens: [{ standard_name: '밀', original_text: '밀가루', level: 'contains' }], allergen_sources: [], notes: '일반 조리법 기준 추정' },
      { name: '수육', description: '수육', taste_tags: [], allergen_status: 'estimated', allergens: [{ standard_name: '돼지고기', original_text: '돼지', level: 'contains' }], allergen_sources: [], notes: '' },
    ],
  };
  const a = validateResult(franchiseRaw, { place: normalizePlace(SAMPLE_FRANCHISE), knownUrls: new Set([...known, normalizeUrl('https://www.sample-burger.co.kr/menu/1')]) });
  const b = validateResult(individualRaw, { place: normalizePlace(SAMPLE_PLACE), knownUrls: known });
  const c = validateResult({ menus: [] }, { place: normalizePlace(SAMPLE_PLACE), knownUrls: new Set() });
  const brandRaw = {
    menus: [
      { name: '빅맥', description: '대표 더블 패티 버거', taste_tags: ['감칠맛'], allergen_status: 'official_extract', allergen_sources: [{ url: 'https://www.sample-burger.co.kr/menu/1' }], allergens: [{ standard_name: '조개', original_text: '조개', level: 'contains' }, { standard_name: '굴', original_text: '굴', level: 'contains' }], notes: '' },
      { name: '불고기버거 세트', description: '세트 표기', taste_tags: ['달콤함'], allergen_status: 'official_extract', allergen_sources: [{ url: 'https://blog.example.com/review' }], allergens: [{ standard_name: '밀', original_text: '밀', level: 'contains' }], notes: '세트 기준 표기' },
    ],
    shared_notice: '튀김류는 같은 조리기구 사용',
  };
  const d = validateResult(brandRaw, { place: normalizePlace(SAMPLE_FRANCHISE, true), knownUrls: known, sourceUrls: new Set([normalizeUrl('https://www.sample-burger.co.kr/menu/1')]) });
  console.log(JSON.stringify({ franchise: a, individual: b, empty: c, brand: d }, null, 2));
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--dry-run')) {
    dryRun();
    return;
  }
  const brandMode = args.includes('--brand');
  const file = args.find((a) => !a.startsWith('--'));
  if (!file) {
    console.error('사용법: node scripts/research/research.mjs [--brand] <places.json 또는 brands.json> [--background] | --dry-run');
    process.exit(1);
  }
  if (!process.env.OPENAI_API_KEY) {
    console.error('환경변수 OPENAI_API_KEY 가 없어요. 예: export OPENAI_API_KEY=... (파일에 저장하지 마세요)');
    process.exit(1);
  }
  const places = JSON.parse(readFileSync(file, 'utf8'));
  const options = {
    model: process.env.OPENAI_MODEL || DEFAULT_MODEL,
    effort: process.env.OPENAI_REASONING_EFFORT || 'low',
    background: args.includes('--background'),
    timeoutMs: Number(process.env.OPENAI_TIMEOUT_MS) || 300000,
    maxToolCalls: Number(process.env.OPENAI_MAX_TOOL_CALLS) || 0,
    brandMode,
    // 브랜드 모드는 메뉴가 늘어 출력이 길어지므로 기본 상한을 둔다. 일반 모드는 env 로 지정했을 때만 사용.
    maxOutputTokens: Number(process.env.OPENAI_MAX_OUTPUT_TOKENS) || (brandMode ? DEFAULT_BRAND_MAX_OUTPUT_TOKENS : 0),
  };
  mkdirSync(OUT_DIR, { recursive: true });
  const entries = [];
  // 브랜드 모드는 가게 모드 결과를 덮어쓰지 않도록 별도 파일에 쓴다
  const prefix = brandMode ? 'brand-' : '';
  const save = () => {
    writeFileSync(join(OUT_DIR, `${prefix}results.json`), `${JSON.stringify(entries, null, 2)}\n`);
    if (entries.length > 0) writeFileSync(join(OUT_DIR, `${prefix}report.md`), buildReport(entries, options));
  };
  for (const place of places) {
    console.log(`조사 중: ${place.brand ?? place.name} (${options.model}${options.background ? ', background' : ''})`);
    try {
      const entry = await researchPlace(place, options);
      entries.push(entry);
      console.log(`  → ${entry.error ? `오류: ${entry.error}` : `메뉴 ${entry.result.menus.length}개, ${entry.elapsed_sec}초`}`);
    } catch (e) {
      // 모델 없음·권한·미지원 오류: 본문을 그대로 출력하고 종료한다 (다른 모델로 바꾸지 않는다)
      console.error(`API 오류 (${e.place}): ${e.message}\n${e.body}`);
      save();
      process.exit(1);
    }
    save();
  }
  console.log(`완료: ${join(OUT_DIR, `${prefix}results.json`)}, ${join(OUT_DIR, `${prefix}report.md`)}`);
}

if (process.argv[1] && resolve(fileURLToPath(import.meta.url)) === resolve(process.argv[1])) {
  main().catch((e) => {
    console.error(redact(e instanceof Error ? e.message : e));
    process.exit(1);
  });
}
