# AI 조사 PoC (로컬 스크립트, 앱·DB와 무관)
1. Node 18+ 필요, 새 패키지 설치 없음(Claude Messages API 를 내장 fetch 로 호출). 키는 환경변수로만: `export ANTHROPIC_API_KEY=...` (파일에 쓰지 않는다)
2. 모델은 `ANTHROPIC_MODEL` 로 지정 (기본 claude-opus-5-5). 생각 깊이는 `ANTHROPIC_EFFORT` (low/medium/high/xhigh/max, 기본 medium)
3. 단가는 `pricing.json` 에 있다. 검색 호출 단가는 비어 있으니 공식 가격표를 보고 채운다 (비어 있으면 추정 비용에서 검색 비용이 빠진다)
4. 기본 실행: `node scripts/research/research.mjs scripts/research/test-places.json`
5. `web_fetch` 를 쓸 수 없는 환경(네트워크가 제한된 클라우드 샌드박스 등, 요청이 400 으로 거부됨)에서는 `--no-fetch` 를 붙인다. 이때 `verified` 는 나오지 않고 공식 값은 `official_extract` 가 된다
6. 후처리 로직만 확인(키·네트워크 불필요): `--dry-run`
7. 자체 테스트: `node scripts/research/selftest.mjs`
8. 결과: `scripts/research/out/results.json`, `out/report.md` (out/ 은 git 제외)
9. 브랜드 모드(공통 대표 메뉴 10개): `node scripts/research/research.mjs --brand scripts/research/test-brands.json` → `out/brand-*.{json,md}`
10. 옵션 `ANTHROPIC_TIMEOUT_MS`(기본 600000), `ANTHROPIC_MAX_TOOL_CALLS`(도구별 호출 상한, 기본 10), `ANTHROPIC_MAX_TOKENS`(생각+출력 상한, 기본 16000), `ANTHROPIC_NO_FALLBACK=1`(거절 시 대체 모델 재실행 끄기)
11. 상태 규칙: `verified` 는 `web_fetch` 로 공식 페이지 본문을 연 기록이 있을 때만 인정한다. 기록이 없으면 코드가 `official_extract` 로 낮춘다
12. 알려진 한계: 알레르기 표가 페이지 로드 후 동적으로 채워지는 사이트(예: 맥도날드)는 검색 결과에 값이 없어 전부 `unknown` 이 될 수 있다 (2026-11 실측, `--no-fetch`)
