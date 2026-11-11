import { defineConfig } from 'vite';
import { readdirSync } from 'node:fs';
import { resolve, join, relative, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
const IGNORE_DIRS = new Set(['node_modules', 'dist', '.git']);

// 프로젝트 안의 모든 .html 파일을 재귀 탐색한다. (HTML 추가 시 이 파일 수정 불필요)
function findHtmlFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      return IGNORE_DIRS.has(entry.name) || entry.name.startsWith('.') ? [] : findHtmlFiles(full);
    }
    return extname(entry.name) === '.html' ? [full] : [];
  });
}

const input = Object.fromEntries(
  findHtmlFiles(root).map((file) => [
    relative(root, file).split(sep).join('/').slice(0, -'.html'.length),
    resolve(file),
  ]),
);

export default defineConfig({
  build: {
    rollupOptions: { input },
  },
});
