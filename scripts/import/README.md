# 지점·브랜드 메뉴 SQL 생성 (로컬 파일만 읽음, DB·OpenAI 호출 없음)
1. 공공데이터 상가(상권)정보 서울 CSV 를 `data/raw/` 에 둔다 (파일명에 `_서울_` 포함, 커밋 금지)
2. 지점 SQL: `node scripts/import/build-branches.mjs` → `supabase/seed_branches.sql`, 진단 `scripts/import/out/branches-report.md`. 같은 (브랜드, 도로명주소)는 1행만 남기고(`dedupe-report.md` 참고), SQL 이 이번 목록에 없는 대상 브랜드 지점을 삭제한다(그 지점의 `saved_restaurants` 도 cascade 로 삭제됨)
3. 브랜드 조사: `node scripts/research/research.mjs --brand scripts/research/test-brands.json` → `scripts/research/out/brand-results.json`
4. 메뉴 SQL: `node scripts/import/build-brand-menus.mjs` (`--input` 으로 결과 파일 변경) → `supabase/seed_brand_menus.sql`
5. SQL Editor 실행 순서: `seed_branches.sql` → `seed_brand_menus.sql` (둘 다 멱등, 앞에 schema/policies/functions/seed_reference 적용)
6. 새 브랜드: `scripts/import/brands.json` 에 추가 → 3번 research(`test-brands.json` 도 추가) → 2·4번 재실행 → SQL 재실행
7. 지점 리포트의 상권업종소분류·상호명 목록으로 오탐을 점검하고 `exclude_patterns` 로 제외한다
8. 자체 테스트: `node scripts/import/selftest.mjs`
