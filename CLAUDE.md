# T:MATE

입맛이 비슷한 사람의 메뉴 평가를 바탕으로 메뉴와 가게를 추천하는 모바일 우선 웹 서비스. 혼자 개발하는 포트폴리오 프로젝트다.

## 기술 스택 (이 외의 라이브러리는 추가하지 않는다)

- 프론트: Vite + TypeScript (vanilla-ts), 멀티 페이지(HTML 여러 개). React 등 프레임워크 사용 금지
- 백엔드: Supabase (Auth, Postgres, RLS, RPC). 별도 서버 없음
- 유사도·추천 계산: Postgres 함수(RPC). 브라우저(클라이언트)에서 LLM 호출 금지. 서버 측 조사 함수·스크립트에서만 허용. 유사도·추천 계산에는 쓰지 않는다
- 환경변수: VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY (.env, 커밋 금지). service_role 키는 어디에도 쓰지 않는다

## 폴더 구조

- index.html, src/pages/_.html + src/pages/_.ts : 페이지와 페이지 스크립트 (vite.config.ts 가 .html 을 자동 등록한다)
- src/lib/supabase.ts : Supabase 클라이언트 (프로젝트에서 이 파일 하나만)
- src/api/\*.ts : Supabase 호출 함수. 화면 코드에서 supabase 를 직접 import 하지 않는다. 반환 타입 명시
- src/utils/\*.ts : 공통 유틸 (DOM 헬퍼, 하단 네비, 인증 가드 등)
- src/types/database.types.ts : 자동 생성 파일. 직접 수정 금지 (npm run gen:types)
- src/types/web-bluetooth.d.ts : Web Bluetooth 타입 중 쓰는 부분만 직접 적은 파일 (라이브러리를 추가하지 않기 위해 둔다)
- src/lib/ : supabase.ts(클라이언트), constants.ts(PATHS 경로 상수, 아이디 → 이메일 변환)
- src/css/ : index.css(모든 페이지의 진입점), reset.css, variables.css(디자인 토큰), common.css
- src/assets/ : 아이콘·이미지·폰트. 마스코트 표정 10종은 src/assets/images/mascot/ 에 있고 src/utils/mascots.ts 의 createMascot 로만 쓴다. 궁합 검사 음식 사진은 src/assets/images/match-foods/ 에 있고(위키미디어 공용의 자유 이용 사진) src/utils/match-food-images.ts 에서 음식 이름과 연결한다. 새 사진을 넣으면 작가·라이선스·원본 주소를 그 파일과 docs/image-credits.md 에 함께 적는다. 브랜드 로고와 대표 메뉴 사진은 src/assets/images/brands/ 에 있고 src/utils/brand-logos.ts 에서 브랜드 이름과 연결한다(위키미디어 공용의 퍼블릭 도메인 로고 13개 + 프로젝트 주인이 모아 준 로고 72개·대표 메뉴 사진 78개. 뒤의 것은 각 회사 저작물이다). 가게 카드·가게 상세의 큰 사진은 대표 메뉴 사진 → 로고 → 음식 종류 기본 그림 → 색 박스 순, 메뉴 카드는 로고 → 음식 종류 기본 그림 → 색 박스 순으로 보여준다
- supabase/functions/ : Supabase Edge Function(Deno). add-store(가게 추가의 AI 추정) 하나가 있다. src 의 tsconfig 에는 포함되지 않는다
- supabase/ : schema.sql(최종 구조), migrations/(기존 DB 에 한 번만 적용), policies.sql, functions.sql, seed_reference.sql(기준 데이터), seed_branches.sql·seed_brand_menus.sql(스크립트가 생성하는 지점·브랜드 메뉴 seed, 직접 수정 금지), seed_demo_users.sql(개발용 가상 사용자, 배포 전 삭제), seed_demo_reviews.sql·seed_demo_more.sql(체험용 데모 평가. 데모 사용자 20명이 전체 메뉴를 평가한다. 실제 평가가 아니다)
- scripts/import/ : 공공데이터 CSV → 지점·브랜드 메뉴 seed SQL 생성 스크립트 (README 참고)
- scripts/research/ : 브랜드 메뉴·알레르기 AI 조사 로컬 스크립트 (README 참고, 결과물 out/ 은 git 제외)
- data/raw/ : 공공데이터 원본 CSV (git 제외)
- README.md : 프로젝트 소개·기능·화면·실행·DB 설정 순서·데이터 출처와 한계
- docs/erd.md : ERD (DB 구조를 바꾸면 schema.sql, erd.md, 타입 파일을 같이 갱신)
- docs/match-print.md : 맛궁합 영수증 인쇄를 맥북에서 처음 시험하는 방법

## 도메인 규칙

- 로그인은 아이디 방식이다. 아이디는 영문 소문자·숫자·밑줄 4~20자이고, Supabase Auth 에는 `${아이디}@tmate-app.com` 이메일로 가입/로그인한다 (변환은 src/lib/constants.ts 한 곳에서만). 이메일 인증은 꺼져 있다. 가입 시 트리거가 profiles 를 자동 생성하고 nickname 기본값은 아이디다. 회원가입 화면에서 닉네임을 필수로 받아 가입 직후 저장한다(랭킹·영수증·결과 화면에는 아이디가 아니라 닉네임이 나온다)
- 지역은 구 단위 문자열이다 (예: '서울시 구로구'). profiles.region 과 restaurants.region 을 문자열로 비교해 "주변 맛집"을 필터한다. 홈의 "가까운 순" 버튼을 누르면 그때만 위치 권한을 묻고, 그 지역 안에서 내 위치와 가까운 순으로 정렬해 거리를 보여준다(get_restaurants 의 p_lat·p_lng. 내 위치는 저장하지 않는다). 가게 좌표(restaurants.lat·lng)는 공공데이터 지점에만 있고 supabase/seed_branch_coords.sql(scripts/import/build-branch-coords.mjs 가 생성, 직접 수정 금지)이 채운다
- 온보딩 순서: 위치(Location) → 맛 선택(Flavor Info, 최대 3개) → 비율 조절(Allergy Info_g, 합계 100) → 알레르기 선택(Allergy Info, 선택 사항) → 홈
- 브랜드 구조: 지점(restaurants)은 공공데이터(소상공인 상가정보)에서 가져오고, 메뉴·알레르기는 브랜드(brands) 단위로 한 번만 조사해 그 브랜드의 모든 지점이 공유한다. 개인 식당은 가게 1개 = 브랜드 1개(1:1)로 같은 구조를 쓴다. 음식 종류는 한식·중식·일식·양식·카페·디저트·치킨·분식·아시안 8개다. 공식 알레르기 표를 확인한 브랜드는 6개이고, 나머지 87개 브랜드는 대표 메뉴를 AI 추정(estimated)으로 넣었다
- 평가 단위는 브랜드 메뉴다 (별점 1~5 + 맛 태그 여러 개). 지점 평점·맛 태그·취향 일치도는 소속 브랜드 메뉴 기준이라 같은 브랜드의 지점은 같은 값이다
- 취향 일치도(%)는 메뉴·가게 카드에 표시한다. 정수 %, 평점은 소수 1자리 + " / 5" (예: 4.7 / 5)
- 알레르기는 식약처 공식 19종 표준(allergens.name)으로 통일한다 (화면 표기는 display_name, 조사 결과 매핑은 aliases). 정보가 없으면 "정보 없음(unknown)"으로 저장하고, 모르는 메뉴를 안전하다고 표시하지 않는다. 메뉴의 allergen_status 는 verified(공식 본문 확인) / official_extract(공식 도메인 발췌) / estimated(추정) / unknown(정보 없음)이다
- 알레르기 추천 규칙: 사용자가 알레르기를 1개 이상 등록했으면 추천에서 겹치는 메뉴(추정 포함)와 unknown 메뉴를 제외한다. estimated(AI 추정) 메뉴는 겹치지 않으면 추천하되 카드에 "알레르기 추정 · 가게 확인"을 붙인다(공식 표를 확인한 브랜드가 6개뿐이라 추정을 빼면 추천이 거의 빈다). 등록한 알레르기가 없으면 상태와 무관하게 포함한다. 가게 상세의 알레르기 탭에서는 겹치는 메뉴를 경고(위험/주의)로, 등록자의 unknown/estimated 메뉴를 "정보 없음"으로 보여준다
- 하단 네비게이션은 홈 / 저장 / 마이페이지 3개다
- 친구랑 궁합 검사(행사 체험용): 방 번호(4자리)로 친구와 묶고(한 방에 2명까지), 둘 중 하나 문항 10개 + 방마다 무작위 음식 5개에 답한다. 궁합(%)은 같은 답을 고른 문항 비율이고 음식 답은 결과 카드에만 쓴다. 결과 화면과 영수증에는 같이 고른 보기(통한 취향)와 다르게 고른 보기(갈린 취향)도 보여준다(get_match_pair_choices). 결과 화면 아래에는 두 사람 취향 일치도의 평균이 높은 가게를 "둘이 같이 가볼 만한 곳"으로 보여준다(get_match_pair_places. 둘 다 입맛 정보가 없으면 평점 순). 문항·음식은 supabase/seed_match.sql, 결과 문구는 src/utils/match-results.ts 에 있다
- 맛궁합 영수증 인쇄(부스 진행자용): 맥북 Chrome 에서 MXW01 미니 감열 프린터(가로 384점, BLE)로 사진과 궁합 결과를 뽑는다. 바이트를 만드는 순수 함수는 src/utils/mxw01-protocol.ts(node scripts/test-mxw01.mjs 로 테스트), Web Bluetooth 전송은 src/utils/mxw01-printer.ts, 영수증 그림은 src/utils/match-receipt.ts 에 있다. 진행자는 방 멤버가 아니므로 get_match_room_pairs · get_match_pair_foods(migrations/004_match_print.sql)로 읽는다. 실제 프린터 통신은 여기서 확인할 수 없으므로 프로토콜을 바꾸면 docs/match-print.md 의 절차로 실제 기기에서 다시 확인한다
- 궁합 결과 화면의 맨 아래 버튼은 맛집 추천으로 이어 준다(입맛을 등록했으면 홈, 아니면 온보딩)
- 궁합 영수증 사진 올리기: 손님이 결과 화면에서 폰으로 찍은 사진(src/utils/match-photo.ts 가 자르지 않고 흰 바탕의 480×360 JPEG 안에 줄여 넣는다)을 request_match_print 로 올리면 인쇄 화면의 "폰으로 올라온 사진" 대기 목록에 뜬다. 손님이 동의(show_on_rank)한 사진만 랭킹 화면에 띄운다(get_match_rank_photos). 결과 화면의 "결과 이미지 저장"은 영수증과 같은 그림을 PNG 로 저장·공유한다. 랭킹 화면의 바로가기 QR 은 정적 그림(src/assets/images/site-qr.svg, 사이트 주소가 바뀌면 다시 만든다)이다. 진행자용 RPC(get_match_print_queue 등)는 진행자 번호(match_print_settings.passcode, DB 에만 둔다)가 맞아야 하고, 사진은 하루 뒤 지운다
- 다른 폰으로 사진 보내기: PC 로 검사한 손님은 결과 화면의 QR(src/utils/qr.ts 가 직접 만든다. node scripts/test-qr.mjs)을 폰으로 찍어 match-photo 화면에서 로그인 없이 사진을 올린다. QR 주소의 표(match_photo_tokens)는 30분만 쓸 수 있고, 이 화면용 RPC 2개만 anon 에게 열려 있다
- 온보딩 위치 화면은 위치 권한을 요청하지 않고 지역 선택 시트(src/utils/region-picker.ts)에서 고르게 한다
- 알레르기·입맛(맛 선택+비율) 수정은 RPC(update_my_allergens, update_my_tastes)가 한 트랜잭션으로 교체 저장한다. 지역·닉네임은 profiles 의 해당 컬럼만 update 한다
- 가게 추가: 목록에 없는 개인 식당을 사용자가 직접 넣는다(가게 1개 = 브랜드 1개, brands.created_by). 메뉴의 알레르기·맛은 Edge Function(supabase/functions/add-store)이 Claude API 로 메뉴 이름에서 추정하고, RPC(add_user_store)가 언제나 estimated 또는 unknown 으로 저장한다. API 키는 Supabase 의 Edge Function 비밀값 ANTHROPIC_API_KEY 에만 둔다(저장소·브라우저 금지). 가게를 추가한 사람은 가게 상세의 "메뉴 추가하기"로 메뉴를 더 넣을 수 있다(add_user_store_menus, 한 가게 30개까지). 하루 한도는 functions.sql 의 calc_setting 에 있다
- 평가로 입맛 자동 보정: 취향 일치도·입맛 유형·마이페이지 맛 비율은 고른 비율(user_taste_preferences)에 평가로 본 입맛을 섞은 "지금 입맛"(calc_taste_profile)으로 계산한다. 평가 1개마다 7%, 최대 70% 섞는다. 저장하지 않고 조회할 때 계산하며, 입맛 수정 화면은 고른 비율만 다룬다

## 디자인 규칙

- Figma 파일 키: InclP71egM1wVUNz6L4cJ2 (Figma MCP 의 get_design_context 로 화면을 읽고, 출력은 참고용으로만 쓰고 이 프로젝트 구조에 맞게 다시 작성한다)
- 화면 폭은 402px 기준 모바일이다. 데스크톱에서는 가운데 정렬한 최대 폭 402px 프레임으로 보여준다
- 색상·폰트·간격은 반드시 variables.css 의 CSS 변수를 쓴다. 하드코딩 금지
- 모든 페이지(index.html 포함)의 <head>에는 src/css/index.css 하나만 링크하고, 페이지 전용 스타일은 그 뒤에 별도 파일로 링크한다. 폰트·토큰·공통 CSS 를 개별로 링크하지 않는다.
- 하단 네비게이션을 쓰는 페이지는 .has-bottom-nav 를 본문에 적용해 마지막 콘텐츠가 네비에 가려지지 않게 한다.
- 화면 노드 id: Splash 1:199 / User-Login 1:851 / User-Signup 1:884 / Location 1:312 / Flavor Info 1:201 / Allergy Info_g(비율 조절) 1:222 / Allergy Info 1:268 / Home 1:2 / Details_s(가게 상세·메뉴별 평가) 1:329 / Details_m(알레르기 정보 탭) 1:453 / Save 1:546 / User(마이페이지) 1:716
- Figma 에 아직 없는 화면은 토큰 기반의 단순한 임시 UI 로 만들고 파일 상단에 `// 디자인 대기: 화면 나오면 교체` 주석을 남긴다

## 화면 현황

- 구현된 화면(src/pages): 스플래시(index.html), login, signup, onboarding-location / flavor / ratio / allergy, home, restaurant, review, save, mypage, my-reviews, taste-detail, taste-edit, taste-mates, allergy-edit, profile-edit, store-add(가게 추가), match(친구랑 궁합 검사), match-rank(맛궁합 랭킹, 부스 큰 화면용이라 402px 프레임을 쓰지 않는다), match-photo(다른 폰으로 사진 보내기, 로그인 없이 쓴다), match-print(맛궁합 영수증 인쇄, 부스 진행자 노트북용이라 402px 프레임을 쓰지 않는다. ?demo=1 은 데모 데이터) (ui-preview 는 개발용 임시 페이지)
- 아직 없는 것: 알림 설정, 프로필 사진 (마이페이지 Figma 의 "알림 설정" 줄은 만들지 않았다)
- Figma 에 있어 읽고 구현한 화면: Splash, User-Login, User-Signup, Location, Flavor Info, Allergy Info_g, Allergy Info, Home, Details_s, Details_m, Save, User
- Figma 에 없어 임시 UI 로 만든 화면 (`// 디자인 대기` 주석, 검색: `grep -rn "디자인 대기" src`): review(평가 작성), my-reviews, allergy-edit, profile-edit, taste-edit, taste-detail, taste-mates, store-add, match, match-rank, match-photo, match-print(영수증 배치 src/utils/match-receipt.ts 포함), 지역 선택 시트(src/utils/region-picker.ts)
- 일부만 임시인 요소: 가게 상세의 알레르기 탭 안내 영역·"정보 없음" 칩·출처 링크(restaurant.*), 알레르기 정보 상태 라벨(src/utils/allergen-status.ts), 저장 화면의 겹침 경고 칩·검색창 문구(save.*), 홈의 가까운 순 버튼(home.*), 홈의 추천·카테고리 빈 상태 문구(home.ts), 마이페이지의 입맛 정보 없음 카드·현재 지역 표시(mypage.*), 내 입맛 화면의 평가 반영 안내(taste-detail.*), 온보딩 위치 화면 문구(Figma 문구와 다름), 알레르기·맛 아이콘 매핑(allergen-icons.ts 는 3종만, taste-icons.ts 는 비어 있음), 홈 상단 궁합 검사 배너(home.*, 노란 띠 위로 검은 고딕 글자가 흘러가는 임시 배너), 홈의 오늘의 추천 메뉴 캐러셀(home.*, 한 줄로 옆으로 넘기고 3.5초마다 한 장씩 넘어간다. Figma 는 2열 격자), 맛 선택 카드의 예시 음식 문구와 2열 배치·비율 슬라이더의 예시 문구(src/utils/taste-examples.ts, Figma 의 Flavor Info 는 3열에 이름만 있음)

## 코드 규칙

- strict TypeScript, any 지양(불가피하면 이유 주석). 파일명은 소문자+하이픈, 변수·함수 camelCase, 타입 PascalCase, CSS 클래스 kebab-case
- 사용자에게 보이는 문구와 에러 메시지는 한국어
- 비동기 호출은 로딩·빈 상태·에러 상태를 항상 처리한다
- 필요한 것보다 크게 만들지 않는다. 시킨 범위 밖의 파일은 수정하지 않는다

## DB 규칙

- Supabase 조회(select)와 추가하는 변경(테이블·함수 추가, 가게·메뉴 같은 데이터 입력)은 묻지 않고 적용한다. 단 SQL 파일을 먼저 작성해 저장소에 남기고, 적용한 뒤 무엇을 넣었는지와 확인 결과를 보고한다. 기존 데이터를 지우거나 테이블·컬럼을 없애는 변경은 되돌릴 수 없으므로 승인받은 뒤에만 한다. `migrations/001_brand_structure.sql` 은 데이터를 지우므로 절대 실행하지 않는다. 직접 적용하지 못할 때는 "SQL Editor 에서 실행할 파일과 순서"를 보고한다 (.claude/settings.json 이 Supabase SQL 실행 도구의 승인 창을 생략하게 한다)
- RPC 는 auth.uid() 로 사용자를 식별하고, 다른 사용자의 데이터를 반환할 때는 닉네임·유사도 같은 최소 정보만 반환한다. SECURITY DEFINER 함수는 set search_path = '' 를 쓴다
- 새 테이블·뷰를 만들면 authenticated 에 필요한 GRANT 를 policies.sql 에 함께 쓴다 (권한이 없으면 RLS 정책 이전에 permission denied 가 난다).

## Git 규칙 (반드시 지킨다)

1. main 에서 직접 작업·커밋하지 않는다. 작업을 시작하면 먼저 브랜치를 만든다
2. 기능별로 브랜치를 만든다. 이름은 `{종류}/{작업내용}` (feature/login, fix/..., chore/..., docs/...)
3. 작업 전에 main 이 최신인지 확인한다 (원격이 있으면 pull)
4. 커밋은 `{타입}: {변경 내용}` 형식, 한 커밋에 한 가지 변경만. 타입은 feat / fix / docs / style / refactor / chore / test. 커밋 메시지에 Co-Authored-By 줄을 넣지 않는다
5. 작업이 끝나면 `npm run build` 통과와 동작을 확인하고, 묻지 않고 `git checkout main && git merge --no-ff <브랜치>` 로 합친 뒤 main 을 push 하고 결과를 보고한다. 합친 브랜치는 삭제한다
6. 작업 브랜치(feature/... 등)는 커밋하면 바로 push 한다(작업 환경이 임시라 push 하지 않은 커밋은 사라질 수 있다). 커밋은 작은 단위로 자주 나누고(구조·함수·API·화면·문서를 따로), 브랜치도 기능 단위로 잘게 만들어 머지 기록을 남긴다

## 보고 형식

작업이 끝나면 5줄 이내로 보고한다: 만든·수정한 파일 / 확인한 것 / 내가 직접 해야 할 것(SQL 실행, 환경설정 등) / 알려진 한계.
