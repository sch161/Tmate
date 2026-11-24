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
- **가게 추가**: 목록에 없는 가게와 메뉴(최대 8개)를 직접 넣습니다. 메뉴의 알레르기와 맛은 서버에서 AI(Claude)가 메뉴 이름으로 추정하고 "추정"으로 표시합니다. 하루 3곳까지 추가할 수 있고, 내가 추가한 가게에는 나중에 메뉴를 더 넣을 수 있습니다(한 가게 30개까지).
- **메뉴 평가**: 별점 1~5 + 맛 태그 여러 개. 작성·수정·삭제할 수 있습니다.
- **저장**: 저장한 가게와 메뉴를 검색하고, 저장 해제할 수 있습니다. 메뉴 카드에 알레르기 겹침 경고와 정보 상태를 보여줍니다.
- **마이페이지**: 프로필 요약, 입맛 유형, 활동 수치(저장한 가게·평가한 메뉴·취향 메이트), 로그아웃.
  - 내 입맛 자세히 보기, 입맛 수정(맛 선택·비율), 내가 평가한 메뉴(수정·삭제), 나의 취향 메이트 목록.
  - 설정: 닉네임 수정, 알레르기 수정, 내 주변 맛집 위치(지역) 설정.
- **친구랑 궁합 검사**(행사 체험용): 홈 상단 배너에서 시작합니다. 방을 만들거나 친구의 방 번호(4자리)로 들어가 둘 중 하나 문항 10개와 음식 경험 5개에 답하면, 같은 방 친구와의 맛궁합(%)·결과 이름·음식 카드(둘 다 좋아하는 음식 등)를 보여줍니다. 부스 화면용 랭킹 페이지가 따로 있습니다.
- **맛궁합 영수증 인쇄**(부스 진행자용): 노트북(맥북 Chrome)에서 방 번호로 팀을 고르고, 웹캠 사진과 궁합 결과(점수·결과 이름·음식 카드)를 MXW01 미니 감열 프린터(블루투스)로 뽑습니다. 미리보기는 실제로 찍힐 흑백 점 그대로 보여줍니다. `?demo=1` 로 열면 예시 팀으로 전체 흐름을 시험할 수 있습니다. 처음 시험하는 방법은 `docs/match-print.md` 에 있습니다.
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
| 가게 추가 (`?region=지역`) | `store-add.html` |
| 메뉴 평가 (`?menuId=메뉴id`) | `review.html` |
| 저장 | `save.html` |
| 마이페이지 | `mypage.html` |
| 내 입맛 자세히 보기 / 입맛 수정 | `taste-detail.html` / `taste-edit.html` |
| 내가 평가한 메뉴 | `my-reviews.html` |
| 나의 취향 메이트 | `taste-mates.html` |
| 알레르기 수정 / 프로필 수정 | `allergy-edit.html` / `profile-edit.html` |
| 친구랑 궁합 검사 (`?room=방번호`) | `match.html` |
| 맛궁합 랭킹(부스 큰 화면용) | `match-rank.html` |
| 다른 폰으로 사진 보내기 (`?t=표`, 로그인 없이) | `match-photo.html` |
| 맛궁합 영수증 인쇄(부스 진행자 노트북용, `?demo=1` 은 데모 데이터) | `match-print.html` |
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

### 체험용 데모 데이터 (선택)

체험 환경에서 취향 메이트·협업 추천이 보이도록 가상 계정 6명(`seed01`~`seed06`, 닉네임이 "데모"로 시작)과 이들의 메뉴 평가를 넣을 수 있습니다.

- **로그인 불가 계정**: 데모 사용자는 취향 메이트용 가상 계정입니다. 비밀번호가 없고, 무작위 값의 해시만 저장되어 있어(원문은 어디에도 남지 않음) 로그인할 수 없습니다.
- **평점에 섞임**: 데모 사용자의 평가(맥도날드·롯데리아 메뉴 20개, 사람당 13~14개)는 가게·메뉴 평균 평점에 포함되어 실제 사용자 평가와 섞여 보입니다. 취향 메이트 화면에는 가상 사용자라는 안내가 나옵니다.
- **실행 순서** (6번 `seed_brand_menus.sql` 까지 끝낸 뒤):
  - 새 DB: `supabase/seed_demo_users.sql` → `supabase/seed_demo_reviews.sql`
  - 기존 DB(예전 가상 사용자 `seed01`~`seed12` 가 이미 있음): `supabase/seed_demo_reviews.sql` 만 실행합니다. `seed07`~`seed12` 삭제, 로그인 불가 처리, 닉네임·입맛 비율 수정, 평가 입력을 모두 합니다.
  - `seed_demo_reviews.sql` 은 두 번 실행해도 같은 결과입니다.
- **정리 방법**: 아래 한 줄로 데모 사용자와 그 취향·알레르기·평가 데이터가 모두 지워집니다.

```sql
delete from auth.users where email like 'seed%@tmate-app.com';
```

### 궁합 영수증 사진 올리기

손님이 결과 화면에서 "사진 찍고 영수증 뽑기"로 폰 사진을 올리면, 진행자의 인쇄 화면(`match-print.html`) "폰으로 올라온 사진" 목록에 뜨고 누르면 바로 미리보기·인쇄로 갑니다. 기존 DB 에는 `supabase/migrations/008_match_photo_upload.sql` 을 실행한 뒤 진행자 번호를 한 번 넣습니다: `insert into match_print_settings (passcode) values ('6자 이상');` 진행자는 인쇄 화면에서 이 번호를 입력합니다.

### 가게 추가 (AI 알레르기 추정)

목록에 없는 가게와 메뉴를 사용자가 직접 넣는 기능입니다. 기존 DB 에는 `supabase/migrations/007_store_add.sql` 하나를 실행합니다(컬럼·표·함수 추가만). 그다음 Edge Function 을 배포하고 비밀값을 넣습니다.

1. `supabase/functions/add-store/index.ts` 를 Edge Function `add-store` 로 배포합니다 (JWT 확인 켬).
2. Supabase 대시보드 → Edge Functions → Secrets 에 `ANTHROPIC_API_KEY`(Claude API 키)를 넣습니다. 키는 저장소나 `.env` 에 두지 않습니다.

비밀값이 없으면 가게 추가 화면에서 "가게를 추가하지 못했어요"가 나옵니다. 알레르기는 메뉴 이름으로 추정한 값이라 언제나 "추정" 또는 "정보 없음"으로 저장됩니다.

### 친구랑 궁합 검사 (행사 체험용)

방 번호로 묶인 친구와 둘 중 하나 문항 10개·음식 경험 5개에 답하고 궁합(%)을 보는 기능의 DB 부분입니다. `supabase/migrations/003_match_test.sql` → `supabase/functions.sql` → `supabase/seed_match.sql` 순서로 실행합니다. 구조는 `docs/erd.md` 에 있습니다.

영수증 인쇄 화면(`match-print.html`)은 방 멤버가 아닌 진행자가 방 번호로 읽는 RPC 2개(`get_match_room_pairs`, `get_match_pair_foods`)를 씁니다. 위 순서로 이미 설정한 DB 에는 `supabase/migrations/004_match_print.sql` 하나만 더 실행하면 됩니다(함수만 추가, 테이블·데이터 변경 없음. 새로 설정하는 DB 는 `functions.sql` 에 들어 있어 따로 실행할 필요가 없습니다). 적용 전에는 `?demo=1` 데모 데이터로만 동작합니다.

## 데이터 출처와 한계

- **지점**: 소상공인시장진흥공단 상가(상권)정보 서울 CSV(공공데이터포털). `scripts/import/` 의 스크립트가 지정 브랜드의 지점만 뽑아 `seed_branches.sql` 을 만들며, 같은 (브랜드, 도로명주소)는 1개 지점으로 합칩니다.
- **메뉴·알레르기**: 브랜드 단위로 한 번만 조사합니다. 조사는 Claude API 웹 검색을 쓰는 **로컬 스크립트**(`scripts/research/`)로 하며, 앱(브라우저)에서는 호출하지 않습니다. 조사 결과는 코드로 검증한 뒤 `seed_brand_menus.sql` 로 만듭니다. 맛 태그는 추정값입니다.
- **브랜드 범위(2026-11 기준)**: 서울 31개 브랜드 6,378개 지점. 양식 6개(맥도날드·롯데리아·버거킹·BBQ·피자헛·파파존스)는 공식 알레르기 표를 확인한 값이고, 한식 8개·중식 1개·일식 4개·카페·디저트 12개(총 25개 브랜드, 메뉴 139개)는 **대표 메뉴 이름으로 AI 가 추정한 값(`estimated`)** 입니다. 이 25개 브랜드의 메뉴 목록은 널리 알려진 대표 메뉴를 정리한 것으로 공식 메뉴판과 대조하지 않았습니다.
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
- 체험용 데모 사용자 6명(로그인 불가, 닉네임 "데모 ○○러")이 맥도날드·롯데리아 메뉴 20개를 사람당 13~14개씩 평가해 둡니다. 이 평가는 **가게·메뉴 평균 평점에 포함**되므로 실제 방문자 평가와 섞여 보입니다. 취향 메이트 화면에는 가상 사용자라는 안내가 나옵니다. 정리 방법은 위 "체험용 데모 데이터" 항목을 보세요. 방문자가 남긴 데이터(가입 계정·평가·저장)는 이 SQL 로 지워지지 않습니다.
- 지역은 구 단위 문자열(예: `서울시 구로구`)로 비교합니다. 좌표·거리 계산은 하지 않습니다.
- Figma 에 없는 화면(평가 작성, 내가 평가한 메뉴, 알레르기·프로필·입맛 수정, 내 입맛 자세히 보기, 취향 메이트 등)은 임시 UI 입니다. 해당 파일 상단에 `// 디자인 대기` 주석이 있습니다.

## 폴더 구조

```
index.html              스플래시
src/pages/              화면(HTML + 페이지 스크립트 + 페이지 CSS)
src/api/                Supabase 호출 함수 (화면 코드는 supabase 를 직접 import 하지 않는다)
src/lib/                supabase.ts(클라이언트), constants.ts(경로·아이디→이메일 변환)
src/utils/              공통 유틸(DOM, 하단 네비, 인증 가드, 상태 뷰, 지역 선택 시트 등)
src/types/              database.types.ts (자동 생성, 직접 수정 금지), web-bluetooth.d.ts (Web Bluetooth 타입, 직접 작성)
src/css/                index.css(진입점), reset / variables(디자인 토큰) / common
src/assets/             아이콘·이미지·폰트
supabase/               schema / policies / functions / seed_*.sql / migrations/
scripts/import/         공공데이터 CSV → 지점·브랜드 메뉴 seed SQL 생성 (README 참고)
scripts/research/       브랜드 메뉴·알레르기 AI 조사 로컬 스크립트 (README 참고)
data/raw/               공공데이터 원본 CSV (git 제외)
docs/erd.md             ERD
docs/match-print.md     맛궁합 영수증 인쇄(미니 프린터) 처음 시험하는 방법
```

## 스크립트 자체 테스트

네트워크·DB 없이 실행됩니다.

```bash
node scripts/import/selftest.mjs
node scripts/research/selftest.mjs
node scripts/test-notice.mjs
node scripts/test-mxw01.mjs   # MXW01 프린터 프로토콜(CRC·패킷·줄 묶기·디더링·전체 쓰기 순서)
```

프린터와의 실제 블루투스 통신은 자동 테스트로 확인할 수 없습니다. 실제 기기 시험 절차는 `docs/match-print.md` 를 따릅니다.

## 협업 규칙

파일 추가 규칙, 브랜치·커밋 규칙은 [CONTRIBUTING.md](CONTRIBUTING.md) 를 참고하세요. DB 구조·정책·RPC 를 바꾸면 `supabase/*.sql` 과 `docs/erd.md` 를 고치고 `npm run gen:types` 로 타입을 갱신합니다.
