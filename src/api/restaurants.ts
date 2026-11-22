import { supabase } from '../lib/supabase';
import type { Database } from '../types/database.types';

type RpcReturns<K extends 'get_restaurants' | 'get_recommended_menus'> = Database['public']['Functions'][K]['Returns'][number];

type RestaurantRow = RpcReturns<'get_restaurants'>;
type RecommendedMenuRow = RpcReturns<'get_recommended_menus'>;

/** 주변 맛집 한 건. RPC 는 평가가 없으면 avg_rating 등에 null 을 돌려주므로 null 을 허용한다. */
export interface RestaurantSummary {
  restaurantId: number;
  name: string;
  region: string;
  imageUrl: string | null;
  avgRating: number | null;
  matchPercent: number | null;
  reviewCount: number;
  isSaved: boolean;
  tasteTags: string[];
}

/** 오늘의 추천 메뉴 한 건. */
export interface RecommendedMenu {
  menuId: number;
  menuName: string;
  restaurantId: number;
  restaurantName: string;
  region: string;
  imageUrl: string | null;
  avgRating: number | null;
  matchPercent: number | null;
}

export interface GetRestaurantsParams {
  region: string;
  categoryId?: number;
  query?: string;
}

// 생성 타입은 null 을 표현하지 않으므로 실제 응답에 맞춰 느슨하게 읽는다
function numOrNull(value: number | null | undefined): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function toRestaurant(row: RestaurantRow): RestaurantSummary {
  return {
    restaurantId: row.restaurant_id,
    name: row.name,
    region: row.region,
    imageUrl: row.image_url || null,
    avgRating: numOrNull(row.avg_rating),
    matchPercent: numOrNull(row.match_percent),
    reviewCount: numOrNull(row.review_count) ?? 0,
    isSaved: Boolean(row.is_saved),
    tasteTags: row.taste_tags ?? [],
  };
}

function toMenu(row: RecommendedMenuRow): RecommendedMenu {
  return {
    menuId: row.menu_id,
    menuName: row.menu_name,
    restaurantId: row.restaurant_id,
    restaurantName: row.restaurant_name,
    region: row.region,
    imageUrl: row.image_url || null,
    avgRating: numOrNull(row.avg_rating),
    matchPercent: numOrNull(row.match_percent),
  };
}

export async function getRestaurants(params: GetRestaurantsParams): Promise<RestaurantSummary[]> {
  try {
    const { data, error } = await supabase.rpc('get_restaurants', {
      p_region: params.region,
      ...(params.categoryId !== undefined ? { p_category_id: params.categoryId } : {}),
      ...(params.query ? { p_query: params.query } : {}),
    });
    if (error) throw error;
    return (data ?? []).map(toRestaurant);
  } catch {
    throw new Error('맛집 목록을 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

export async function getRecommendedMenus(region: string): Promise<RecommendedMenu[]> {
  try {
    const { data, error } = await supabase.rpc('get_recommended_menus', { p_region: region });
    if (error) throw error;
    return (data ?? []).map(toMenu);
  } catch {
    throw new Error('추천 메뉴를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

/** 가게 저장/저장 해제. RLS 로 본인 행만 가능하다. */
export async function toggleSaveRestaurant(restaurantId: number, saved: boolean): Promise<void> {
  try {
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) throw userError ?? new Error('no user');
    const userId = userData.user.id;
    const { error } = saved
      ? await supabase.from('saved_restaurants').upsert({ user_id: userId, restaurant_id: restaurantId }, { ignoreDuplicates: true })
      : await supabase.from('saved_restaurants').delete().eq('user_id', userId).eq('restaurant_id', restaurantId);
    if (error) throw error;
  } catch {
    throw new Error(saved ? '저장하지 못했어요. 잠시 후 다시 시도해주세요' : '저장을 해제하지 못했어요. 잠시 후 다시 시도해주세요');
  }
}
