import { supabase } from '../lib/supabase';
import { getConflictingMenuIds } from './allergy-conflicts';
import { getSession } from './auth';
import { categoryOrNull, type AllergenStatus } from './restaurants';

/** 평가 작성 화면용 메뉴 정보. 평가는 브랜드 메뉴 단위라 같은 브랜드의 모든 지점이 공유한다. */
export interface ReviewMenu {
  menuId: number;
  name: string;
  description: string | null;
  imageUrl: string | null;
  brandName: string;
  /** 음식 카테고리 이름. 없으면 null */
  categoryName: string | null;
}

/** 내 기존 평가 */
export interface MyReview {
  rating: number;
  tagIds: number[];
}

export interface MenuForReview {
  menu: ReviewMenu;
  /** 평가한 적이 없으면 null */
  myReview: MyReview | null;
}

const GENERIC_ERROR = '문제가 발생했어요. 잠시 후 다시 시도해주세요';

/** RPC 가 던진 한국어 예외 메시지(로그인·별점·존재하지 않는 메뉴 등)는 그대로 쓰고, 그 외에는 기본 문구를 쓴다. */
function rpcMessage(error: { message?: string } | null, fallback: string): string {
  const message = error?.message ?? '';
  return /[가-힣]/.test(message) ? message : fallback;
}

/** 메뉴와 내 기존 평가. 없는 menuId 면 null. reviews 는 전체 select 가 가능하므로 반드시 user_id 로 거른다. */
export async function getMenuForReview(menuId: number): Promise<MenuForReview | null> {
  try {
    const session = await getSession();
    if (!session) throw new Error('로그인이 필요합니다.');
    const userId = session.user.id;

    const { data: menu, error: menuError } = await supabase
      .from('menus')
      .select('id, name, description, image_url, brands(name, food_categories(name))')
      .eq('id', menuId)
      .maybeSingle();
    if (menuError) throw menuError;
    if (!menu) return null;

    const { data: review, error: reviewError } = await supabase
      .from('reviews')
      .select('id, rating')
      .eq('user_id', userId)
      .eq('menu_id', menuId)
      .maybeSingle();
    if (reviewError) throw reviewError;

    let myReview: MyReview | null = null;
    if (review) {
      const { data: tags, error: tagError } = await supabase.from('review_taste_tags').select('taste_tag_id').eq('review_id', review.id);
      if (tagError) throw tagError;
      myReview = { rating: review.rating, tagIds: (tags ?? []).map((row) => row.taste_tag_id) };
    }

    return {
      menu: {
        menuId: menu.id,
        name: menu.name,
        description: menu.description?.trim() || null,
        imageUrl: menu.image_url?.trim() || null,
        brandName: menu.brands?.name ?? '',
        categoryName: categoryOrNull(menu.brands?.food_categories?.name),
      },
      myReview,
    };
  } catch {
    throw new Error('메뉴 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

/** 평가 저장(신규/수정). 맛 태그는 교체 저장된다. 저장된 review id 를 돌려준다. */
export async function upsertReview(menuId: number, rating: number, tagIds: number[]): Promise<number> {
  try {
    const { data, error } = await supabase.rpc('upsert_review', { p_menu_id: menuId, p_rating: rating, p_tag_ids: tagIds });
    if (error) throw new Error(rpcMessage(error, '평가를 저장하지 못했어요. 잠시 후 다시 시도해주세요'));
    return data;
  } catch (e) {
    throw new Error(e instanceof Error && /[가-힣]/.test(e.message) ? e.message : GENERIC_ERROR);
  }
}

/** 내 평가 삭제. 평가가 없어도 오류 없이 끝난다. */
export async function deleteReview(menuId: number): Promise<void> {
  try {
    const { error } = await supabase.rpc('delete_review', { p_menu_id: menuId });
    if (error) throw new Error(rpcMessage(error, '평가를 삭제하지 못했어요. 잠시 후 다시 시도해주세요'));
  } catch (e) {
    throw new Error(e instanceof Error && /[가-힣]/.test(e.message) ? e.message : GENERIC_ERROR);
  }
}

/** 내가 평가한 메뉴 한 건 (get_my_reviews + 알레르기 안전 정보) */
export interface MyReviewItem {
  menuId: number;
  menuName: string;
  brandId: number;
  brandName: string;
  /** 음식 카테고리 이름. 없으면 null */
  categoryName: string | null;
  imageUrl: string | null;
  /** 1~5 */
  rating: number;
  /** 내가 평가에 붙인 맛 태그 */
  tasteTags: string[];
  /** ISO 날짜 문자열 */
  createdAt: string;
  /** 수정 링크용 대표 지점. 브랜드에 지점이 하나도 없으면 null */
  restaurantId: number | null;
  allergenStatus: AllergenStatus;
  conflictsWithMyAllergens: boolean;
}

/** 내가 평가한 메뉴, 최신순(get_my_reviews 의 정렬 그대로). 모양이 맞지 않는 행(별점 1~5 정수 아님 등)은 버린다. */
export async function getMyReviews(): Promise<MyReviewItem[]> {
  try {
    const session = await getSession();
    if (!session) throw new Error('no session');
    const { data, error } = await supabase.rpc('get_my_reviews');
    if (error) throw error;
    const rows = (data ?? []).filter((row) => Number.isInteger(row.rating) && row.rating >= 1 && row.rating <= 5);
    const ids = rows.map((row) => row.menu_id);
    if (ids.length === 0) return [];

    const [statuses, conflicting] = await Promise.all([
      supabase.from('menus').select('id, allergen_status').in('id', ids),
      getConflictingMenuIds(session.user.id, ids),
    ]);
    if (statuses.error) throw statuses.error;
    const statusById = new Map((statuses.data ?? []).map((row) => [row.id, row.allergen_status]));

    return rows.map((row) => ({
      menuId: row.menu_id,
      menuName: row.menu_name,
      brandId: row.brand_id,
      brandName: row.brand_name,
      categoryName: categoryOrNull(row.category_name),
      imageUrl: row.image_url?.trim() || null,
      rating: row.rating,
      tasteTags: Array.isArray(row.taste_tags) ? row.taste_tags.filter((tag): tag is string => typeof tag === 'string' && tag !== '') : [],
      createdAt: row.created_at,
      restaurantId: typeof row.restaurant_id === 'number' ? row.restaurant_id : null,
      // 상태를 못 읽으면 안전하다고 표시하지 않도록 unknown 으로 둔다
      allergenStatus: statusById.get(row.menu_id) ?? 'unknown',
      conflictsWithMyAllergens: conflicting.has(row.menu_id),
    }));
  } catch {
    throw new Error('평가한 메뉴를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}
