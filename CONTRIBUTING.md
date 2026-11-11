# 기여 가이드

## 파일 추가 규칙

- 새 화면: 프로젝트 루트나 `src/pages/` 에 HTML 을 추가한다. `vite.config.ts` 는 수정하지 않는다.
- 페이지 스크립트: `src/pages/{페이지명}.ts` 로 만들고 해당 HTML 에서 불러온다.
- Supabase 호출: `src/api/{기능명}.ts` 에 함수로 만든다. 화면 코드에서 `supabase` 를 직접 import 하지 않는다. 반환 타입을 명시한다.
- 공통 코드는 `src/utils/` 에 둔다. 공통 파일(`lib/supabase.ts`, `common.css` 등)을 바꿀 때는 팀에 먼저 알린다.
- 파일명은 소문자 + 하이픈, 변수·함수는 camelCase, 타입·인터페이스는 PascalCase, CSS 클래스는 kebab-case.
- `any` 사용을 지양한다. 불가피하면 이유를 주석으로 남긴다.
- `src/types/database.types.ts` 는 자동 생성 파일이므로 직접 수정하지 않는다. DB 구조·정책·RPC 를 바꾸면 `supabase/*.sql` 과 `docs/erd.md` 를 수정하고 `npm run gen:types` 로 타입을 갱신해 같은 PR 에 포함하며, PR 에 명시한다.

## 협업 규칙 (반드시 지킬 것)

1. main 에서 직접 개발하지 않는다. 개인 브랜치에서 작업한다.
2. 기능별로 브랜치를 만든다. 로그인, 회원가입 등 작업 단위를 분리한다.
3. 작업 전 최신 코드를 확인한다. 작업 시작 전과 PR 올리기 전에 main 을 pull 한다.
4. PR 을 통해 병합한다. 팀원 리뷰(최소 1명 승인)를 거친 뒤 main 에 반영한다.
5. 커밋 메시지는 무엇을 변경했는지 알 수 있게 작성한다.

## 브랜치 이름

`{종류}/{작업내용}`, 영문 소문자와 하이픈만 사용.
예) `feature/login`, `feature/menu-review`, `fix/review-rating-bug`, `docs/readme`

## 커밋 메시지

`{타입}: {변경 내용}`, 한 커밋에는 한 가지 변경만.

타입: `feat` / `fix` / `docs` / `style` / `refactor` / `chore` / `test`

- 예) `feat: 메뉴 별점 입력 UI 추가`
- 나쁜 예) `수정`, `작업중`

## 작업 흐름

1. `git checkout main && git pull origin main`
2. `git checkout -b feature/작업내용`
3. 작업 → 작은 단위로 자주 커밋
4. `git pull origin main` 으로 최신 main 반영, 충돌 해결
5. `git push origin feature/작업내용` → GitHub 에서 PR 생성
6. 승인 후 병합, 병합된 브랜치는 삭제

## 주의

- `.env` 는 절대 커밋하지 않는다.
- 다른 사람이 만든 파일을 수정할 때는 먼저 알린다.
- DB 스키마(`schema.sql`) 변경은 백엔드 담당자와 먼저 상의한다.
