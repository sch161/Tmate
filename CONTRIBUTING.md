# 기여 가이드

## 파일 추가 규칙

- 새 화면: 프로젝트 루트나 `src/pages/` 에 HTML 을 추가한다. `vite.config.ts` 는 수정하지 않는다.
- 페이지 스크립트: `src/pages/{페이지명}.ts` 로 만들고 해당 HTML 에서 불러온다.
- Supabase 호출: `src/api/{기능명}.ts` 에 함수로 만든다. 화면 코드에서 `supabase` 를 직접 import 하지 않는다. 반환 타입을 명시한다.
- 공통 코드는 `src/utils/` 에 둔다. 공통 파일(`lib/supabase.ts`, `common.css` 등)을 바꿀 때는 팀에 먼저 알린다.
- 파일명은 소문자 + 하이픈, 변수·함수는 camelCase, 타입·인터페이스는 PascalCase, CSS 클래스는 kebab-case.
- `any` 사용을 지양한다. 불가피하면 이유를 주석으로 남긴다.
- `src/types/database.types.ts` 는 자동 생성 파일이므로 직접 수정하지 않는다. DB 구조·정책·RPC 를 바꾸면 `supabase/*.sql` 과 `docs/erd.md` 를 수정하고 `npm run gen:types` 로 타입을 갱신해 같은 브랜치에 포함하고, 작업 보고에 명시한다.

## 작업 규칙

브랜치 작업, 병합, push 등 작업 흐름은 [CLAUDE.md](CLAUDE.md) 의 Git 규칙을 따른다. (기능별 브랜치에서 작업하고, 로컬에서 `merge --no-ff` 로 합치며, push 는 요청할 때만 한다. PR·리뷰어 승인 절차는 쓰지 않는다.)

## 브랜치 이름

`{종류}/{작업내용}`, 영문 소문자와 하이픈만 사용.
예) `feature/login`, `feature/menu-review`, `fix/review-rating-bug`, `docs/readme`

## 커밋 메시지

`{타입}: {변경 내용}`, 한 커밋에는 한 가지 변경만.

타입: `feat` / `fix` / `docs` / `style` / `refactor` / `chore` / `test`

- 예) `feat: 메뉴 별점 입력 UI 추가`
- 나쁜 예) `수정`, `작업중`

## 주의

- `.env` 는 절대 커밋하지 않는다.
- 다른 사람이 만든 파일을 수정할 때는 먼저 알린다.
- DB 스키마(`schema.sql`) 변경은 백엔드 담당자와 먼저 상의한다.
