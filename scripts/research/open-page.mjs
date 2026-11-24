// 공식 알레르기 페이지를 브라우저로 열어 화면에 보이는 본문을 텍스트로 저장한다 (research.mjs 의 page_file 로 쓴다).
// 페이지 로드 후 표가 채워지는 사이트도 읽을 수 있다. API 키는 필요 없다.
// Playwright 가 이미 설치된 환경(Claude Code 클라우드 세션 등)에서만 동작한다. 프로젝트 의존성에는 추가하지 않았다.
// Playwright 가 없으면 브라우저에서 페이지를 열어 전체 선택·복사한 내용을 txt 로 저장해도 된다.
// 사용: node scripts/research/open-page.mjs <url> <저장할 txt 경로>
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { createRequire } from 'node:module';

const [url, outFile] = process.argv.slice(2);
if (!url || !outFile) {
  console.error('사용법: node scripts/research/open-page.mjs <url> <저장할 txt 경로>');
  process.exit(1);
}

let chromium;
try {
  ({ chromium } = createRequire(import.meta.url)('playwright'));
} catch {
  console.error('Playwright 를 찾지 못했어요. 브라우저에서 페이지를 열어 본문을 복사해 txt 로 저장한 뒤 page_file 로 지정하세요.');
  process.exit(1);
}

const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
const browser = await chromium.launch(proxy ? { proxy: { server: proxy } } : {});
try {
  const context = await browser.newContext({ locale: 'ko-KR', viewport: { width: 1280, height: 2000 } });
  const page = await context.newPage();
  const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  // 표를 나중에 채우는 사이트를 위해 네트워크가 조용해질 때까지 기다린다 (끝내 조용해지지 않아도 계속 진행)
  await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(3000);
  const text = await page.locator('body').innerText();
  mkdirSync(dirname(outFile), { recursive: true });
  writeFileSync(outFile, text);
  console.log(`HTTP ${response?.status() ?? '-'} / 최종 주소 ${page.url()} / 본문 ${text.length}자 / 표 ${await page.locator('table').count()}개 → ${outFile}`);
  if (text.length < 500) console.error('본문이 너무 짧아요. 접근이 막혔거나 내용이 이미지·PDF 일 수 있어요. 저장된 파일을 직접 확인하세요.');
} finally {
  await browser.close();
}
