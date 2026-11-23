# T:MATE (Taste + Mate)

입맛이 비슷한 사람의 평가와 내 입맛 비율로 메뉴와 가게를 추천하고, 알레르기 정보를 공식 표와 출처로 안전하게 보여주는 모바일 우선 웹 서비스입니다. 혼자 개발하는 포트폴리오 프로젝트입니다.

> 알레르기 정보는 **참고용**입니다. 먹기 전에 반드시 가게에 확인하세요. 정보가 없는 메뉴를 "알레르기 없음"으로 표시하지 않습니다.

## 구현된 기능

- **로그인·회원가입**: 아이디 방식입니다. 아이디(영문 소문자·숫자·밑줄 4~20자)를 `아이디@tmate-app.com` 형태의 이메일로 바꿔 Supabase Auth 에 가입·로그인합니다. 가입하면 트리거가 프로필을 만듭니다.
- **온보딩**: 지역 선택 → 맛 선택(최대 3개) → 맛 비율 조절(합계 100) → 알레르기 선택(선택 사항) → 홈.
- **홈**: 오늘의 추천 메뉴, 주변 맛집(내 지역 기준), 가게명·브랜드명·메뉴명 검색, 음식 카테고리 필터, 가게 저장, 지역 변경. 알레르기 때문에 추천이 비면 그 이유를 안내합니다.
- **가게 상세**: 지점의 메뉴·평점·맛 태그는 소속 브랜드 기준입니다.
  - 메뉴별 평가 탭: 메뉴별 취향 일치도, 맛 태그, 내 별점, 메뉴 저장, 평가하기, 메뉴 출처.
  - 알레르기 정보 탭: 내 알레르기와 겹치는 메뉴(위험/주의), 정보 없는 메뉴, 메뉴별 정보 상태 라벨, 공식 표 기준일·공식 출처 링크, 조리기구 공유 공지, 참고용 안내.
- **메뉴 평가**: 별점 1~5 + 맛 태그 여러 개. 작성·수정·삭제할 수 있습니다.
- **저장**: 저장한 가게와 메뉴를 검색하고, 저장 해제할 수 있습니다. 메뉴 카드에 알레르기 겹침 경고와 정보 상태를 보여줍니다.
- **마이페이지**: 프로필 요약, 입맛 유형, 활동 수치(저장한 가게·평가한 메뉴·취향 메이트), 로그아웃.
  - 내 입맛 자세히 보기, 입맛 수정(맛 선택·비율), 내가 평가한 메뉴(수정·삭제), 나의 취향 메이트 목록.
  - 설정: 닉네임 수정, 알레르기 수정, 내 주변 맛집 위치(지역) 설정.
- **아직 없는 것**: 알림 설정, 프로필 사진.

## 화면 목록

`src/pages/` 의 HTML 하나가 한 화면입니다(`vite.config.ts` 가 `.html` 을 자동 등록).

| 화면 | 파일 |
|------|------|
| 스플래시(로그인 여부에 따라 분기) | `index.html` |
| 로그인 / 회원가입 | `login.html` / `signup.html` |
| 온보딩 위치 / 맛 선택 / 비율 / 알레르기 | `onboarding-location.html` / `onboarding-flavor.html` / `onboarding-ratio.html` / `onboarding-allergy.html` |
| 홈 | `home.html` |
| 가게 상세 (`?id=지점id`) | `restaurant.html` |
| 메뉴 평가 (`?menuId=메뉴id`) | `review.html` |
| 저장 | `save.html` |
| 마이페이지 | `mypage.html` |
| 내 입맛 자세히 보기 / 입맛 수정 | `taste-detail.html` / `taste-edit.html` |
| 내가 평가한 메뉴 | `my-reviews.html` |
| 나의 취향 메이트 | `taste-mates.html` |
| 알레르기 수정 / 프로필 수정 | `allergy-edit.html` / `profile-edit.html` |
| 개발용 컴포넌트 미리보기(임시) | `ui-preview.html` |

하단 네비게이션은 홈 / 저장 / 마이페이지 3개입니다.

## 기술 스택

- 프론트: Vite + TypeScript(strict), 프레임워크 없는 멀티 페이지 구성
- 백엔드: Supabase(Auth, Postgres, RLS, RPC). 별도 서버 없음
- 추천·유사도 계산: Postgres 함수(RPC). 브라우저에서 LLM 을 호출하지 않습니다
- 데이터 준비: 로컬 Node 스크립트(`scripts/`)

## 실행 방법

필요한 것: Node.js `^20.19.0` 또는 `>=22.12.0`(Vite 8 요구), 그리고 아래 DB 설정을 마친 Supabase 프로젝트.

```bash
npm install
cp .env.example .env   # 환경변수 값을 채운다 (.env 는 커밋하지 않는다)
npm run dev
```

환경변수(이름만):

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

`service_role` 키는 어디에도 쓰지 않습니다. Supabase 대시보드의 Authentication 설정에서 이메일 확인(Confirm email)을 꺼야 가입 직후 로그인됩니다.

| 명령 | 설명 |
|------|------|
| `npm run dev` | 개발 서버 |
| `npm run build` | 타입 체크 + 빌드 |
| `npm run preview` | 빌드 결과 미리보기 |
| `npm run gen:types` | Supabase DB 타입 생성(`src/types/database.types.ts`, Supabase CLI 로그인 필요) |

## DB 설정 순서

모든 SQL 은 Supabase SQL Editor 에서 실행합니다.

**새로 설치**

1. `supabase/schema.sql`
2. `supabase/policies.sql`
3. `supabase/functions.sql` (재실행 가능)
4. `supabase/seed_reference.sql` (음식 카테고리, 맛 태그, 알레르기 표준 19종)
5. `supabase/seed_branches.sql` (브랜드와 지점, 재실행 가능)
6. `supabase/seed_brand_menus.sql` (브랜드 메뉴·알레르기, 재실행 가능)
7. `npm run gen:types`

**옛 구조(가게·메뉴 1:N)의 기존 DB**: `schema.sql` 대신 `supabase/migrations/001_brand_structure.sql` 을 한 번만 적용합니다(파괴적 마이그레이션, 기존 시드 데이터를 지웁니다). 이후 2번부터 같은 순서로 진행합니다.

> `seed_branches.sql` 은 대상 브랜드의 지점 중 이번 목록에 없는 행을 삭제합니다. 그 지점을 저장해 둔 사용자의 저장 목록(`saved_restaurants`)도 함께 지워질 수 있습니다.

**체험용 데모 사용자 (선택)**: 체험 행사에서 취향 메이트·협업 추천이 보이도록 가상 사용자 6명(`seed01`~`seed06`, 닉네임이 "데모"로 시작)을 넣을 수 있습니다. 6번 다음에 아래 두 파일을 순서대로 실행합니다. `seed_demo_reviews.sql` 은 두 번 실행해도 같은 결과입니다.

- `supabase/seed_demo_users.sql` (데모 사용자 6명과 입맛 비율)
- `supabase/seed_demo_reviews.sql` (예전 가상 사용자 `seed07`~`seed12` 삭제, 로그인 불가 처리, 데모 평가 데이터)

> 데모 사용자는 **로그인할 수 없습니다**(비밀번호가 무작위 값이며 어디에도 남지 않습니다). 행사가 끝나면 `delete from auth.users where email like 'seed%@tmate-app.com';` 한 줄로 데모 사용자와 그 평가를 모두 지울 수 있습니다.

## 데이터 출처와 한계

- **지점**: 소상공인시장진흥공단 상가(상권)정보 서울 CSV(공공데이터포털). `scripts/import/` 의 스크립트가 지정 브랜드의 지점만 뽑아 `seed_branches.sql` 을 만들며, 같은 (브랜드, 도로명주소)는 1개 지점으로 합칩니다.
- **메뉴·알레르기**: 브랜드 단위로 한 번만 조사합니다. 조사는 OpenAI 웹 검색을 쓰는 **로컬 스크립트**(`scripts/research/`)로 하며, 앱(브라우저)에서는 호출하지 않습니다. 조사 결과는 코드로 검증한 뒤 `seed_brand_menus.sql` 로 만듭니다. 맛 태그는 추정값입니다.
- **알레르기 표준**: 식약처 표시 대상 19종으로 통일합니다(화면 표기는 `display_name`).

### 알레르기 정보 상태

| 상태 | 의미 | 화면 라벨 |
|------|------|-----------|
| `verified` | 공식 표 본문을 직접 확인 | 공식 표 기준 |
| `official_extract` | 공식 도메인 검색 결과 발췌(본문 재확인 못 함) | 공식 사이트 검색 결과 기준 · 원문 확인 권장 |
| `estimated` | 일반 조리법 기준 추정 | 추정 · 가게 확인 필요 |
| `unknown` | 정보 없음 | 정보 없음 |

알레르기를 1개 이상 등록한 사용자의 추천에서는 겹치는 메뉴와 `unknown`/`estimated` 메뉴를 제외합니다(안전 우선). 등록하지 않았다면 상태와 무관하게 포함합니다. 가게 상세의 알레르기 탭에서는 겹치는 메뉴를 경고로, 등록자의 `unknown`/`estimated` 메뉴를 "정보 없음"으로 보여줍니다.

### 알려진 한계

- 현재 시드 데이터는 브랜드 2개(맥도날드, 롯데리아)와 서울 지점뿐이며, 시드 메뉴는 브랜드당 10개입니다. 한식·중식·일식 카테고리에는 가게가 없습니다.
- 가게·메뉴 이미지가 없어 색 플레이스홀더를 보여줍니다.
- 개인 식당의 알레르기 정보는 없습니다.
- 평가 데이터가 적으면 사용자 간 추천(취향 메이트·유사 사용자 기반 점수)이 비어 있습니다. 두 사용자의 유사도는 같은 메뉴를 3개 이상 함께 평가해야 계산되고, 내 평가가 5개 이상일 때부터 유사 사용자 기반 점수가 일치도에 섞입니다(`functions.sql` 의 `calc_setting`). 그 전에는 내 맛 비율 × 메뉴 맛 태그로만 일치도를 계산합니다.
- 체험용 데모 사용자 6명(로그인 불가, 닉네임 "데모 ○○러")이 맥도날드·롯데리아 메뉴 20개를 사람당 13~14개씩 평가해 둡니다. 이 평가는 **가게·메뉴 평균 평점에 포함**되므로 실제 방문자 평가와 섞여 보입니다. 취향 메이트 화면에는 가상 사용자라는 안내가 나옵니다. 방문자가 남긴 데이터(가입 계정·평가·저장)의 삭제는 행사 후 별도로 합니다.
- 지역은 구 단위 문자열(예: `서울시 구로구`)로 비교합니다. 좌표·거리 계산은 하지 않습니다.
- Figma 에 없는 화면(평가 작성, 내가 평가한 메뉴, 알레르기·프로필·입맛 수정, 내 입맛 자세히 보기, 취향 메이트 등)은 임시 UI 입니다. 해당 파일 상단에 `// 디자인 대기` 주석이 있습니다.

## 폴더 구조

```
index.html              스플래시
src/pages/              화면(HTML + 페이지 스크립트 + 페이지 CSS)
src/api/                Supabase 호출 함수 (화면 코드는 supabase 를 직접 import 하지 않는다)
src/lib/                supabase.ts(클라이언트), constants.ts(경로·아이디→이메일 변환)
src/utils/              공통 유틸(DOM, 하단 네비, 인증 가드, 상태 뷰, 지역 선택 시트 등)
src/types/              database.types.ts (자동 생성, 직접 수정 금지)
src/css/                index.css(진입점), reset / variables(디자인 토큰) / common
src/assets/             아이콘·이미지·폰트
supabase/               schema / policies / functions / seed_*.sql / migrations/
scripts/import/         공공데이터 CSV → 지점·브랜드 메뉴 seed SQL 생성 (README 참고)
scripts/research/       브랜드 메뉴·알레르기 AI 조사 로컬 스크립트 (README 참고)
data/raw/               공공데이터 원본 CSV (git 제외)
docs/erd.md             ERD
```

## 스크립트 자체 테스트

네트워크·DB 없이 실행됩니다.

```bash
node scripts/import/selftest.mjs
node scripts/research/selftest.mjs
node scripts/test-notice.mjs
```

## 협업 규칙

파일 추가 규칙, 브랜치·커밋 규칙은 [CONTRIBUTING.md](CONTRIBUTING.md) 를 참고하세요. DB 구조·정책·RPC 를 바꾸면 `supabase/*.sql` 과 `docs/erd.md` 를 고치고 `npm run gen:types` 로 타입을 갱신합니다.
