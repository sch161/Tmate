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
- 입맛 유형 이름 (비율 상위 2개 조합, 예: 매콤달콤)
- 취향 메이트 목록과 수, 마이페이지 활동 수치(저장·평가·메이트)
- 지역 목록(`get_regions`: 지점이 있는 지역별 지점 수)
- 일치도 계산: 평가 수가 적은 사용자는 입맛 비율 × 메뉴 태그, 평가가 쌓이면 유사 사용자 기반
