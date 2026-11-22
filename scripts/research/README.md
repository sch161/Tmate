# AI 조사 PoC (로컬 스크립트, 앱·DB와 무관)
1. Node 18+ 필요, 새 패키지 설치 없음. 키는 환경변수로만: `export OPENAI_API_KEY=...` (파일에 쓰지 않는다)
2. 모델은 `OPENAI_MODEL` 로 지정 (기본 gpt-6.1-sol). reasoning effort 는 `OPENAI_REASONING_EFFORT` (기본 low)
3. 단가를 `pricing.json` 에 직접 채운다 (비어 있으면 보고서에 "단가 미설정")
4. 기본 실행: `node scripts/research/research.mjs scripts/research/test-places.json`
5. 백그라운드: 위 명령에 `--background` 추가 (3초 폴링, 최대 10분)
6. 후처리 로직만 확인(키·네트워크 불필요): `--dry-run`
7. 자체 테스트: `node scripts/research/selftest.mjs`
8. 결과: `scripts/research/out/results.json`, `out/report.md` (out/ 은 git 제외)
9. 옵션 `OPENAI_TIMEOUT_MS`(기본 300000), `OPENAI_MAX_TOOL_CALLS`(비용 상한, 미설정 시 미사용)
