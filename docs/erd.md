# T:MATE ERD

Figma 디자인(2026-11-23 기준) 반영본. 구조를 바꾸면 `supabase/schema.sql` 과 `src/types/database.types.ts` 도 같이 수정한다.

```mermaid
erDiagram
    profiles ||--o{ user_taste_preferences : "입맛 선택·비율"
    taste_tags ||--o{ user_taste_preferences : ""
    profiles ||--o{ user_allergens : "알레르기"
    allergens ||--o{ user_allergens : ""
    food_categories ||--o{ restaurants : "분류"
    restaurants ||--o{ menus : "보유"
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
        text name UK
    }
    restaurants {
        bigint id PK
        text name
        text address
        text region "구 단위 필터"
        text phone
        text image_url
        smallint category_id FK
    }
    menus {
        bigint id PK
        bigint restaurant_id FK
        text name
        text description
        text image_url
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

## 뷰 (테이블 아님)

- `menu_stats`: 메뉴별 평균 별점, 평가 수
- `restaurant_stats`: 가게별 평균 별점, 평가 수 (소속 메뉴 평가의 평균)
- `restaurant_taste_tags`: 가게 카드의 입맛 태그 (소속 메뉴 태그의 합집합)

## RPC로 계산하는 값 (functions.sql)

- 메뉴·가게 취향 일치도, 추천 이유 문장, 오늘의 추천 메뉴
- 입맛 유형 이름 (비율 상위 2개 조합, 예: 매콤달콤)
- 취향 메이트 목록과 수, 마이페이지 활동 수치(저장·평가·메이트)
- 일치도 계산: 평가 수가 적은 사용자는 입맛 비율 × 메뉴 태그, 평가가 쌓이면 유사 사용자 기반
