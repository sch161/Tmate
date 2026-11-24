# T:MATE ERD

브랜드 구조 반영본. 구조를 바꾸면 `supabase/schema.sql`(+ 기존 DB 용 `supabase/migrations/`)과 `src/types/database.types.ts` 도 같이 수정한다.

- 지점(`restaurants`)은 공공데이터(소상공인 상가정보)에서 전국 지점을 가져온다.
- 메뉴·알레르기는 브랜드(`brands`) 단위로 한 번만 조사하고, 그 브랜드의 모든 지점이 공유한다. 개인 식당은 가게 1개 = 브랜드 1개(1:1).
- 평가(`reviews`)는 브랜드 메뉴에 붙는다. 알레르기는 식약처 표준 19종, 정보가 없으면 `allergen_status = unknown`.

```mermaid
erDiagram
    profiles ||--o{ user_taste_preferences : "입맛 선택·비율"
    taste_tags ||--o{ user_taste_preferences : ""
    profiles ||--o{ user_allergens : "알레르기"
    allergens ||--o{ user_allergens : ""
    food_categories ||--o{ brands : "분류"
    brands ||--o{ restaurants : "지점"
    brands ||--o{ menus : "공통 메뉴"
    menus ||--o{ menu_taste_tags : "맛 태그"
    taste_tags ||--o{ menu_taste_tags : ""
    menus ||--o{ menu_allergens : "알레르기 재료"
    allergens ||--o{ menu_allergens : ""
    profiles ||--o{ reviews : "작성"
    menus ||--o{ reviews : "평가 대상"
    reviews ||--o{ review_taste_tags : ""
    taste_tags ||--o{ review_taste_tags : ""
    profiles ||--o{ saved_restaurants : "저장"
    restaurants ||--o{ saved_restaurants : ""
    profiles ||--o{ saved_menus : "저장"
    menus ||--o{ saved_menus : ""

    profiles {
        uuid id PK "auth.users.id"
        text username UK "로그인 아이디"
        text nickname
        text region "예: 서울시 관악구"
        text avatar_url
        boolean onboarding_done
        timestamptz created_at
    }
    food_categories {
        smallint id PK
        text name "한식 중식 일식 양식"
    }
    taste_tags {
        smallint id PK
        text code UK
        text name UK "매콤함 달콤함 짭조름함 등"
    }
    allergens {
        smallint id PK
        text name UK "식약처 표준 19종 (알류 우유 메밀 ...)"
        text display_name "화면 표기 (알류=계란, 대두=콩)"
        text_array aliases "조사 결과 매핑용 별칭"
    }
    brands {
        bigint id PK
        text name "프랜차이즈는 이름 중복 불가"
        boolean is_franchise
        smallint category_id FK
        text image_url
        text_array official_domains
        text allergen_source_url "공식 알레르기 페이지"
        date allergen_data_date "공식 표 기준일"
        text shared_notice "조리기구 공유 등 공지"
        text research_status "pending running done failed"
        timestamptz researched_at
        text research_error
        timestamptz created_at
    }
    restaurants {
        bigint id PK
        bigint brand_id FK
        text external_id UK "공공데이터 상가업소번호"
        text name
        text address
        text sido
        text sigungu
        text region "구 단위 필터"
        text phone
        text image_url
    }
    menus {
        bigint id PK
        bigint brand_id FK "unique(brand_id, name)"
        text name
        text description
        text image_url
        enum allergen_status "verified official_extract estimated unknown"
        text allergen_source_url
        timestamptz allergen_checked_at
        text allergen_note
        text menu_source_url
        text menu_source_name "비공식 출처 표시용"
    }
    reviews {
        bigint id PK
        uuid user_id FK
        bigint menu_id FK
        smallint rating "1~5"
        timestamptz created_at
        timestamptz updated_at
    }
    user_taste_preferences {
        uuid user_id PK,FK
        smallint taste_tag_id PK,FK
        smallint ratio "1~100, 합계 100"
    }
    user_allergens {
        uuid user_id PK,FK
        smallint allergen_id PK,FK
    }
    menu_taste_tags {
        bigint menu_id PK,FK
        smallint taste_tag_id PK,FK
    }
    menu_allergens {
        bigint menu_id PK,FK
        smallint allergen_id PK,FK
        enum level "danger caution"
        text original_text "공식 원문 표기"
    }
    review_taste_tags {
        bigint review_id PK,FK
        smallint taste_tag_id PK,FK
    }
    saved_restaurants {
        uuid user_id PK,FK
        bigint restaurant_id PK,FK
        timestamptz created_at
    }
    saved_menus {
        uuid user_id PK,FK
        bigint menu_id PK,FK
        timestamptz created_at
    }
```

## 뷰 (테이블 아님, security_invoker)

- `menu_stats`: 메뉴별 평균 별점, 평가 수
- `brand_stats`: 브랜드별 평균 별점, 평가 수 (소속 메뉴 평가). 목록 RPC 는 지점이 많으므로 이 뷰를 브랜드 단위로 조회한다
- `restaurant_stats`: 지점별 평균 별점, 평가 수 (소속 브랜드 메뉴 평가)
- `restaurant_taste_tags`: 지점 카드의 입맛 태그 (소속 브랜드 메뉴 태그의 합집합)

## 알레르기 규칙

- `allergen_status`: `verified`(공식 본문 직접 확인) / `official_extract`(공식 도메인 검색 발췌) / `estimated`(일반 조리법 추정) / `unknown`(정보 없음)
- `menu_allergens.level`: `danger` = 함유(조사 결과의 contains), `caution` = 혼입 가능(may_contain). 정보 없는 메뉴는 행을 만들지 않는다
- 알레르기를 등록한 사용자의 추천에서는 겹치는 메뉴와 `unknown`/`estimated` 메뉴를 제외한다. 등록하지 않았다면 상태와 무관하게 포함한다

## RPC로 계산하는 값 (functions.sql)

- 메뉴·가게 취향 일치도(브랜드 메뉴 기준), 추천 이유 문장, 오늘의 추천 메뉴(브랜드당 한 번, 링크용 대표 지점 반환)
- 입맛 유형 이름 (지금 입맛의 비율 상위 2개 조합, 예: 매콤달콤)
- 지금 입맛(`calc_taste_profile`, 화면용 `get_my_taste_profile()`): 고른 입맛 비율에 평가로 본 입맛을 섞는다. 평가 1개마다 7%, 최대 70%. 평가로 본 입맛은 평가한 메뉴의 맛마다 (별점 - 3)을 더해 구한다. 저장하지 않고 조회할 때마다 계산한다
- 취향 메이트 목록과 수, 마이페이지 활동 수치(저장·평가·메이트)
- 지역 목록(`get_regions`: 지점이 있는 지역별 지점 수)
- 내 알레르기 교체 저장(`update_my_allergens(p_allergen_ids int[])`): 빈 배열이면 모두 해제, null·중복은 무시, 없는 알레르기 id 는 예외. 한 트랜잭션으로 삭제 후 삽입
- 내 입맛 교체 저장(`update_my_tastes(p_taste_ids int[], p_ratios int[])`): 두 배열은 같은 순서의 짝. 맛 1~3개, 비율 1~100, 합계 100, 중복·없는 맛 불가(`save_onboarding` 의 맛 검증과 같다). `user_taste_preferences` 의 내 행만 바꾸고 지역·온보딩 완료·알레르기는 건드리지 않는다
- 일치도 계산: 평가 수가 적은 사용자는 지금 입맛 비율 × 메뉴 태그, 평가가 쌓이면 유사 사용자 기반

## 가게 추가 (사용자가 직접 추가하는 개인 식당, migrations/007_store_add.sql)

- 가게 1개 = 브랜드 1개로 `brands`(is_franchise = false, `created_by` = 추가한 사람) · `restaurants` · `menus` 에 들어간다
- 흐름: 화면 → Edge Function `add-store`(supabase/functions/add-store) → `begin_store_add`(입력 확인·요청 기록) → AI 가 메뉴 이름으로 알레르기·맛 추정 → `add_user_store`(저장)
- 알레르기는 AI 추정이라 메뉴의 `allergen_status` 는 `estimated`(추정) 또는 `unknown`(이름만으로 알 수 없음)으로만 저장한다. `menu_allergens.original_text` 는 'AI 추정', `menus.menu_source_name` 은 '사용자 등록'
- `store_add_attempts`(id, user_id, created_at): AI 추정 요청 기록. 클라이언트에 열지 않는다
- 한도(`calc_setting`): 하루 가게 3곳(`store_add_daily_max`), 하루 요청 10회(`store_add_attempt_max`), 한 번에 메뉴 8개(`store_menu_max`). 같은 지역에 같은 이름(띄어쓰기·대소문자 무시)은 추가할 수 없다

## 궁합 영수증 사진 올리기 (migrations/008_match_photo_upload.sql)

- `match_print_requests`(id, room_id unique, requested_by, photo, created_at, printed_at): 손님이 폰으로 올린 사진(JPEG data URL, 200,000자 이하)과 인쇄 요청. 방마다 1건, 다시 올리면 바뀐다. 하루가 지나면 새 요청이 올 때 지운다
- `match_print_settings`(id, passcode): 진행자 번호 1행. 값은 저장소에 두지 않는다
- `get_match_pair_choices(p_code, p_member_no_a, p_member_no_b)`(migrations/009): 두 사람의 PART 1 문항별 답. 결과 화면과 영수증의 "통한 취향 / 갈린 취향"에 쓴다
- 손님 RPC `request_match_print(p_code, p_photo, p_show_on_rank)`: 그 방에서 검사를 마친 두 사람만 가능. `show_on_rank` 는 랭킹 화면에 사진을 띄워도 된다는 동의(기본 false)
- `get_match_rank_photos(p_limit)`(migrations/010): 동의한 사진만 최근 것부터 (닉네임·점수·사진)
- `match_photo_tokens`(token, room_id, created_by, created_at)(migrations/011): PC 로 검사한 손님이 QR 로 다른 폰에서 사진을 올릴 때 쓰는 표. 30분 유효. `create_match_photo_token(p_code)` 는 방 멤버만, `get_match_photo_token_info(p_token)` · `upload_match_photo_by_token(p_token, p_photo, p_show_on_rank)` 는 로그인 없이(anon) 부를 수 있다
- 진행자 RPC `get_match_print_queue(p_passcode)` · `get_match_print_photo(p_passcode, p_request_id)` · `mark_match_printed(p_passcode, p_request_id)`: 진행자 번호가 맞아야 한다

## 친구랑 궁합 검사 (행사 체험용, migrations/003_match_test.sql)

클라이언트에 직접 열지 않는 테이블이다. RLS 를 켜고 권한·정책을 주지 않으며 RPC 로만 읽고 쓴다.
흐름: 방 만들기/들어가기 → 검사(PART 1 둘 중 하나 문항 + PART 2 그 방의 음식) → 방 사람들과의 궁합.

| 테이블 | 주요 컬럼 | 설명 |
|---|---|---|
| `match_questions` | `sort_order`, `body`, `option_a`, `option_b`, `is_active` | PART 1 문항 (둘 중 하나) |
| `match_foods` | `name`(unique), `is_active` | PART 2 음식 후보 |
| `match_rooms` | `code`(숫자 4자리, unique), `created_by → profiles`, `created_at` | 같이 온 친구끼리 묶는 방. 검사 한 번 = 방 하나 |
| `match_room_foods` | PK(`room_id → match_rooms`, `food_id → match_foods`), `sort_order` | 그 방에서 나올 음식. 방을 만들 때 무작위로 정해져 같은 방 친구에게 같은 음식이 나온다 |
| `match_room_members` | PK(`room_id`, `user_id → profiles`), `member_no`(방 안 번호), `joined_at`, `completed_at` | 방 멤버. 다른 사람은 `member_no` 로 가리킨다 |
| `match_answers` | PK(`room_id`, `user_id`, `question_id → match_questions`), `choice`(1=A, 2=B) | PART 1 답 |
| `match_food_answers` | PK(`room_id`, `user_id`, `food_id → match_foods`), `eaten`, `rating`(1~5), `want_try` | PART 2 답. 먹어봤으면 별점, 안 먹어봤으면 먹어보고 싶은지 |

- 궁합(%) = 두 사람이 같은 답을 고른 PART 1 문항 수 / 둘 다 답한 문항 수 × 100 (문항 10개면 10% 단위). 둘 중 하나라도 검사를 마치지 않았으면 계산하지 않는다
- PART 2(음식)는 점수에 넣지 않는다. 결과 카드(둘 다 좋아하는 음식, 한쪽만 먹어본 음식 등)와 랭킹 동점 처리에만 쓴다
- RPC: `create_match_room`(방 번호 반환, 음식 `match_food_count`(5)개 무작위 고정), `join_match_room(p_code)`, `get_my_match_room`(가장 최근 방 번호), `get_match_questions(p_code)`, `get_match_foods(p_code)`, `save_match_test(p_code, p_choices, p_foods)`(모든 문항·음식에 답해야 저장), `get_match_room(p_code)`(방 사람들과 나의 궁합), `get_match_compare(p_code, p_member_no)`(음식별 나와 친구의 답), `get_match_ranking(p_limit, p_hours)`(같은 방 두 사람의 궁합 순위)
- 다른 사람의 정보는 같은 방 사람의 닉네임·궁합 점수·그 방 음식에 대한 답만 돌려준다. 한 방의 최대 인원은 `match_room_max`(2)명 — 둘만의 궁합이다
- 영수증 인쇄(부스 진행자용, migrations/004_match_print.sql): `get_match_room_pairs(p_code)`(그 방에서 둘 다 검사를 마친 두 사람 조합의 `member_no_a`·`member_no_b`·닉네임·궁합 점수), `get_match_pair_foods(p_code, p_member_no_a, p_member_no_b)`(두 사람의 음식별 답 `a_*`·`b_*`). 위 RPC 와 달리 방 멤버가 아니어도 로그인만 하면 방 번호로 읽을 수 있고, 돌려주는 범위는 같다(닉네임·점수·그 방 음식 답, 사용자 id 없음). 테이블은 바꾸지 않는다
- `match_room_keep_days`(7)일이 지난 방은 새 방을 만들 때 지워진다(답 포함). 4자리 방 번호를 다시 쓰기 위해서다
- 문항·음식은 `seed_match.sql` 로 넣는다. 문항을 다시 넣으면 그 문항의 답이 함께 지워진다
