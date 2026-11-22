# T:MATE

입맛이 비슷한 사람의 메뉴 평가를 바탕으로 메뉴와 가게를 추천하는 모바일 우선 웹 서비스. 혼자 개발하는 포트폴리오 프로젝트다.

## 기술 스택 (이 외의 라이브러리는 추가하지 않는다)

- 프론트: Vite + TypeScript (vanilla-ts), 멀티 페이지(HTML 여러 개). React 등 프레임워크 사용 금지
- 백엔드: Supabase (Auth, Postgres, RLS, RPC). 별도 서버 없음
- 유사도·추천 계산: Postgres 함수(RPC). LLM API 사용 금지
- 환경변수: VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY (.env, 커밋 금지). service_role 키는 어디에도 쓰지 않는다

## 폴더 구조

- index.html, src/pages/_.html + src/pages/_.ts : 페이지와 페이지 스크립트 (vite.config.ts 가 .html 을 자동 등록한다)
- src/lib/supabase.ts : Supabase 클라이언트 (프로젝트에서 이 파일 하나만)
- src/api/\*.ts : Supabase 호출 함수. 화면 코드에서 supabase 를 직접 import 하지 않는다. 반환 타입 명시
- src/utils/\*.ts : 공통 유틸 (DOM 헬퍼, 하단 네비, 인증 가드 등)
- src/types/database.types.ts : 자동 생성 파일. 직접 수정 금지 (npm run gen:types)
- src/css/ : reset.css, variables.css(디자인 토큰), common.css
- supabase/ : schema.sql, policies.sql, functions.sql, seed.sql
- docs/erd.md : ERD (DB 구조를 바꾸면 schema.sql, erd.md, 타입 파일을 같이 갱신)

## 도메인 규칙

- 로그인은 아이디 방식이다. 아이디는 영문 소문자·숫자·밑줄 4~20자이고, Supabase Auth 에는 `${아이디}@tmate-app.com` 이메일로 가입/로그인한다 (변환은 src/lib/constants.ts 한 곳에서만). 이메일 인증은 꺼져 있다. 가입 시 트리거가 profiles 를 자동 생성하고 nickname 기본값은 아이디다
- 지역은 구 단위 문자열이다 (예: '서울시 구로구'). profiles.region 과 restaurants.region 을 문자열로 비교해 "주변 맛집"을 필터한다. 좌표·거리 계산은 하지 않는다
- 온보딩 순서: 위치(Location) → 맛 선택(Flavor Info, 최대 3개) → 비율 조절(Allergy Info_g, 합계 100) → 알레르기 선택(Allergy Info, 선택 사항) → 홈
- 평가 단위는 메뉴다 (별점 1~5 + 맛 태그 여러 개). 가게 평점은 소속 메뉴 평점의 평균이다
- 취향 일치도(%)는 메뉴·가게 카드에 표시한다. 정수 %, 평점은 소수 1자리 + " / 5" (예: 4.7 / 5)
- 알레르기: 추천에서는 사용자가 피해야 할 재료가 포함된 메뉴를 제외하고, 가게 상세의 알레르기 탭에서는 경고(위험/주의)로 보여준다
- 하단 네비게이션은 홈 / 저장 / 마이페이지 3개다

## 디자인 규칙

- Figma 파일 키: InclP71egM1wVUNz6L4cJ2 (Figma MCP 의 get_design_context 로 화면을 읽고, 출력은 참고용으로만 쓰고 이 프로젝트 구조에 맞게 다시 작성한다)
- 화면 폭은 402px 기준 모바일이다. 데스크톱에서는 가운데 정렬한 최대 폭 402px 프레임으로 보여준다
- 색상·폰트·간격은 반드시 variables.css 의 CSS 변수를 쓴다. 하드코딩 금지
- 화면 노드 id: Splash 1:199 / User-Login 1:851 / User-Signup 1:884 / Location 1:312 / Flavor Info 1:201 / Allergy Info_g(비율 조절) 1:222 / Allergy Info 1:268 / Home 1:2 / Details_s(가게 상세·메뉴별 평가) 1:329 / Details_m(알레르기 정보 탭) 1:453 / Save 1:546 / User(마이페이지) 1:716
- Figma 에 아직 없는 화면은 토큰 기반의 단순한 임시 UI 로 만들고 파일 상단에 `// 디자인 대기: 화면 나오면 교체` 주석을 남긴다

## 코드 규칙

- strict TypeScript, any 지양(불가피하면 이유 주석). 파일명은 소문자+하이픈, 변수·함수 camelCase, 타입 PascalCase, CSS 클래스 kebab-case
- 사용자에게 보이는 문구와 에러 메시지는 한국어
- 비동기 호출은 로딩·빈 상태·에러 상태를 항상 처리한다
- 필요한 것보다 크게 만들지 않는다. 시킨 범위 밖의 파일은 수정하지 않는다

## DB 규칙

- Claude Code 는 Supabase 에 직접 SQL 을 실행하지 않는다. SQL 파일만 작성하고, 끝나면 "SQL Editor 에서 실행할 파일과 순서"를 보고한다
- RPC 는 auth.uid() 로 사용자를 식별하고, 다른 사용자의 데이터를 반환할 때는 닉네임·유사도 같은 최소 정보만 반환한다. SECURITY DEFINER 함수는 set search_path = '' 를 쓴다

## Git 규칙 (반드시 지킨다)

1. main 에서 직접 작업·커밋하지 않는다. 작업을 시작하면 먼저 브랜치를 만든다
2. 기능별로 브랜치를 만든다. 이름은 `{종류}/{작업내용}` (feature/login, fix/..., chore/..., docs/...)
3. 작업 전에 main 이 최신인지 확인한다 (원격이 있으면 pull)
4. 커밋은 `{타입}: {변경 내용}` 형식, 한 커밋에 한 가지 변경만. 타입은 feat / fix / docs / style / refactor / chore / test. 커밋 메시지에 Co-Authored-By 줄을 넣지 않는다
5. 작업이 끝나면 `npm run build` 통과를 확인하고, 브랜치에 커밋한 뒤 결과를 보고한다. 내가 "머지해"라고 하면 `git checkout main && git merge --no-ff <브랜치>` 로 합치고 브랜치를 삭제한다
6. git push 는 내가 요청할 때만 한다

## 보고 형식

작업이 끝나면 5줄 이내로 보고한다: 만든·수정한 파일 / 확인한 것 / 내가 직접 해야 할 것(SQL 실행, 환경설정 등) / 알려진 한계.
