# T:MATE (Taste + Mate)

입맛이 비슷한 사용자의 메뉴 평가를 기반으로 메뉴를 추천하는 웹 서비스입니다.

## 기술 스택

- 프론트: Vite + TypeScript (vanilla-ts, 프레임워크 없음)
- 백엔드: Supabase (Auth, Postgres, RLS) — 별도 서버 없음
- 유사도 계산: Postgres 함수(RPC), `supabase.rpc()` 로 호출
- 차트: Chart.js

## 시작 방법

```bash
git clone <저장소 주소>
cd tmate
npm install
cp .env.example .env   # 열어서 키 입력 (키는 팀 채팅으로 전달받음)
npm run dev
```

## 스크립트

| 명령 | 설명 |
|------|------|
| `npm run dev` | 개발 서버 실행 |
| `npm run build` | 타입 체크 + 빌드 |
| `npm run preview` | 빌드 결과 미리보기 |
| `npm run gen:types` | Supabase DB 타입 생성 |

### gen:types 설정

`package.json` 의 `gen:types` 스크립트에 있는 `<PROJECT_ID>` 를 실제 Supabase 프로젝트 ID 로 교체하세요. (Supabase CLI 로그인 필요)

### TypeScript 설정

`tsconfig.json` 은 `strict: true` 입니다. 필요하면 팀과 상의해 조정하세요.

## 폴더 구조

```
src/lib/       Supabase 클라이언트 (supabase.ts 하나만)
src/api/       Supabase 호출 함수 (기능별)
src/pages/     페이지별 진입 스크립트
src/utils/     공통 유틸
src/types/     database.types.ts (자동 생성, 수정 금지)
src/css/       reset / variables / common
supabase/      schema / policies / functions / seed SQL
docs/          erd.md
```

## 새 페이지/기능 추가 방법 (파일 추가 규칙)

- 새 화면: 프로젝트 루트나 `src/pages/` 에 HTML 을 추가한다. `vite.config.ts` 는 수정하지 않는다.
- 페이지 스크립트: `src/pages/{페이지명}.ts` 로 만들고 해당 HTML 에서 불러온다.
- Supabase 호출: `src/api/{기능명}.ts` 에 함수로 만든다. 화면 코드에서 `supabase` 를 직접 import 하지 않는다. 반환 타입을 명시한다.
- 공통 코드는 `src/utils/` 에 둔다. 공통 파일(`lib/supabase.ts`, `common.css` 등)을 바꿀 때는 팀에 먼저 알린다.
- 파일명은 소문자 + 하이픈, 변수·함수는 camelCase, 타입·인터페이스는 PascalCase, CSS 클래스는 kebab-case.
- `any` 사용을 지양한다. 불가피하면 이유를 주석으로 남긴다.
- `src/types/database.types.ts` 는 자동 생성 파일이므로 직접 수정하지 않는다. DB 구조·정책·RPC 를 바꾸면 `supabase/*.sql` 과 `docs/erd.md` 를 수정하고 `npm run gen:types` 로 타입을 갱신해 같은 PR 에 포함하며, PR 에 명시한다.

자세한 협업 규칙은 [CONTRIBUTING.md](CONTRIBUTING.md) 를 참고하세요.
