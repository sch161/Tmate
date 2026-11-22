// scripts/import 공용 유틸. Node 내장 모듈만 쓴다.
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = resolve(HERE, '..', '..');
export const OUT_DIR = join(HERE, 'out');

/** SQL 문자열 리터럴. 작은따옴표를 이중으로 하고 NUL 을 제거한다. null/undefined/빈 문자열은 null. */
export function sqlString(value) {
  if (value === null || value === undefined) return 'null';
  const s = String(value).replace(/\u0000/g, '');
  if (s === '') return 'null';
  return `'${s.replace(/'/g, "''")}'`;
}

/** 빈 문자열도 그대로 넣어야 하는 곳(필수 문자열)용. */
export function sqlRequired(value) {
  return `'${String(value ?? '').replace(/\u0000/g, '').replace(/'/g, "''")}'`;
}

/** 스크립트가 직접 실행되었는지 (import 되면 false) */
export function isMain(metaUrl) {
  return Boolean(process.argv[1]) && resolve(fileURLToPath(metaUrl)) === resolve(process.argv[1]);
}
