// 공공데이터 CSV 의 경도·위도를 seed_branches.sql 에 있는 지점(상가업소번호)에 붙여 supabase/seed_branch_coords.sql 을 만든다.
// 지점을 지우거나 새로 넣지 않고 lat·lng 만 채운다(여러 번 실행해도 같은 결과).
// 실행: node scripts/import/build-branch-coords.mjs   (migrations/019_restaurant_coords.sql 을 먼저 적용)
import { createReadStream, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createCsvParser } from './build-branches.mjs';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const RAW_DIR = join(REPO_ROOT, 'data', 'raw');

/** 서울 근처가 아닌 좌표(0, 빈 값, 잘못 들어간 값)는 버린다 */
function validCoord(lat, lng) {
  return Number.isFinite(lat) && Number.isFinite(lng) && lat > 37.3 && lat < 37.8 && lng > 126.6 && lng < 127.3;
}

async function main() {
  const seed = readFileSync(join(REPO_ROOT, 'supabase', 'seed_branches.sql'), 'utf8');
  const wanted = new Set([...seed.matchAll(/^\s*\('(?:[^']|'')*', '([A-Z0-9]+)', /gm)].map((m) => m[1]));
  const files = readdirSync(RAW_DIR).filter((f) => f.endsWith('.csv')).sort();
  if (files.length === 0) throw new Error('data/raw 에 CSV 가 없어요');

  const coords = new Map();
  for (const file of files) {
    let col = null;
    const parser = createCsvParser((row) => {
      if (!col) {
        col = { id: row.indexOf('상가업소번호'), lng: row.indexOf('경도'), lat: row.indexOf('위도') };
        if (col.id < 0 || col.lng < 0 || col.lat < 0) throw new Error(`${file}: 상가업소번호·경도·위도 열이 없어요`);
        return;
      }
      const id = row[col.id];
      if (!wanted.has(id) || coords.has(id)) return;
      const lat = Number(row[col.lat]);
      const lng = Number(row[col.lng]);
      if (validCoord(lat, lng)) coords.set(id, { lat, lng });
    });
    for await (const chunk of createReadStream(join(RAW_DIR, file), { encoding: 'utf8' })) parser.feed(chunk);
    parser.end();
  }

  const rows = [...coords].sort((a, b) => (a[0] < b[0] ? -1 : 1));
  const lines = [
    '-- =====================================================================',
    '-- seed_branch_coords.sql — 지점 좌표(위도·경도). scripts/import/build-branch-coords.mjs 가 생성, 직접 수정하지 않는다',
    `-- 원본: ${files.join(', ')} 의 경도·위도 열 (WGS84)`,
    '-- 지점을 지우거나 새로 넣지 않고 external_id 가 같은 지점의 lat·lng 만 채운다. 여러 번 실행해도 안전하다.',
    '-- 실행 순서: migrations/019_restaurant_coords.sql → 이 파일',
    '-- =====================================================================',
    'begin;',
    '',
  ];
  const CHUNK = 1000;
  for (let i = 0; i < rows.length; i += CHUNK) {
    lines.push('update restaurants r set lat = v.lat, lng = v.lng');
    lines.push('from (values');
    lines.push(rows.slice(i, i + CHUNK).map(([id, c]) => `  ('${id}', ${c.lat.toFixed(6)}, ${c.lng.toFixed(6)})`).join(',\n'));
    lines.push(') as v(external_id, lat, lng)');
    lines.push('where r.external_id = v.external_id;', '');
  }
  lines.push('commit;', '');
  writeFileSync(join(REPO_ROOT, 'supabase', 'seed_branch_coords.sql'), lines.join('\n'));
  console.log(`지점 ${wanted.size}개 중 좌표 ${rows.length}개 → supabase/seed_branch_coords.sql`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
