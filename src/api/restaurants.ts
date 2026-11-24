import { supabase } from '../lib/supabase';
import type { Database, Json } from '../types/database.types';

type RpcReturns<K extends 'get_restaurants' | 'get_recommended_menus'> = Database['public']['Functions'][K]['Returns'][number];

export type AllergenStatus = Database['public']['Enums']['allergen_status'];

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
  /** 브랜드 정보 (아직 화면에는 쓰지 않는다) */
  brandId: number;
  brandName: string;
  isFranchise: boolean;
  hasOfficialAllergen: boolean;
  /** 음식 카테고리 이름(한식·중식·일식·양식). 기본 이미지 선택에 쓴다. 없으면 null */
  categoryName: string | null;
  /** 내 위치에서의 직선 거리(m). 위치를 보내지 않았거나 가게 좌표가 없으면 null */
  distanceM: number | null;
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
  /** 브랜드·알레르기 상태 (아직 화면에는 쓰지 않는다) */
  brandName: string;
  allergenStatus: AllergenStatus;
  /** 음식 카테고리 이름. 없으면 null */
  categoryName: string | null;
}

export interface GetRestaurantsParams {
  region: string;
  categoryId?: number;
  query?: string;
  /** 내 위치(위도·경도). 주면 가까운 순으로 정렬한다. 서버에 저장하지 않는다 */
  location?: { lat: number; lng: number };
}

// 생성 타입은 null 을 표현하지 않으므로 실제 응답에 맞춰 느슨하게 읽는다
/** 서버가 준 카테고리 이름. 배포 순서상 아직 컬럼이 없거나 값이 비면 null (화면은 기본 색 박스를 쓴다) */
export function categoryOrNull(value: string | null | undefined): string | null {
  return typeof value === 'string' && value.trim() !== '' ? value.trim() : null;
}

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
    brandId: row.brand_id,
    brandName: row.brand_name,
    isFranchise: Boolean(row.is_franchise),
    hasOfficialAllergen: Boolean(row.has_official_allergen),
    categoryName: categoryOrNull(row.category_name),
    distanceM: numOrNull(row.distance_m),
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
    brandName: row.brand_name,
    allergenStatus: row.allergen_status,
    categoryName: categoryOrNull(row.category_name),
  };
}

export async function getRestaurants(params: GetRestaurantsParams): Promise<RestaurantSummary[]> {
  try {
    const { data, error } = await supabase.rpc('get_restaurants', {
      p_region: params.region,
      ...(params.categoryId !== undefined ? { p_category_id: params.categoryId } : {}),
      ...(params.query ? { p_query: params.query } : {}),
      ...(params.location ? { p_lat: params.location.lat, p_lng: params.location.lng } : {}),
    });
    if (error) throw error;
    return (data ?? []).map(toRestaurant);
  } catch {
    throw new Error('맛집 목록을 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

export async function getRecommendedMenus(region: string, limit = 10): Promise<RecommendedMenu[]> {
  try {
    const { data, error } = await supabase.rpc('get_recommended_menus', { p_region: region, p_limit: limit });
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

// ---------- 가게(지점) 상세 ----------

type DetailRow = Database['public']['Functions']['get_restaurant_detail']['Returns'][number];
type MenuRow = Database['public']['Functions']['get_restaurant_menus']['Returns'][number];
type AllergyRow = Database['public']['Functions']['get_allergy_menus']['Returns'][number];

const str = (value: string | null | undefined): string | null => (typeof value === 'string' && value.trim() !== '' ? value.trim() : null);

/** 지점 상세. 메뉴·알레르기·평점은 소속 브랜드 기준이라 브랜드 정보(공지·출처·기준일)가 함께 온다. */
export interface RestaurantDetail {
  restaurantId: number;
  name: string;
  address: string;
  region: string;
  phone: string | null;
  imageUrl: string | null;
  avgRating: number | null;
  reviewCount: number;
  matchPercent: number | null;
  reason: string | null;
  isSaved: boolean;
  brandId: number;
  brandName: string;
  isFranchise: boolean;
  sharedNotice: string | null;
  allergenSourceUrl: string | null;
  allergenDataDate: string | null;
  /** 음식 카테고리 이름. 없으면 null */
  categoryName: string | null;
}

/** 브랜드 메뉴 한 건 (메뉴별 평가 탭) */
export interface RestaurantMenu {
  menuId: number;
  name: string;
  description: string | null;
  imageUrl: string | null;
  tasteTags: string[];
  avgRating: number | null;
  matchPercent: number | null;
  isSaved: boolean;
  myRating: number | null;
  allergenStatus: AllergenStatus;
  allergenSourceUrl: string | null;
  allergenCheckedAt: string | null;
  menuSourceName: string | null;
  menuSourceUrl: string | null;
}

export type AllergenLevel = 'danger' | 'caution';

export interface AllergenItem {
  name: string;
  level: AllergenLevel;
  originalText: string | null;
}

/** 알레르기 정보 탭의 메뉴 한 건. conflict = 내 알레르기와 겹침, unknown = 정보 없음/추정(알레르기 등록자에게만 온다) */
export interface AllergyMenu {
  menuId: number;
  name: string;
  imageUrl: string | null;
  allergens: AllergenItem[];
  allergenStatus: AllergenStatus;
  kind: 'conflict' | 'unknown';
}

/** get_allergy_menus 의 allergens(jsonb)를 런타임에서 검증해 읽는다. 모양이 다른 항목은 버린다. */
export function parseAllergenItems(value: Json): AllergenItem[] {
  if (!Array.isArray(value)) return [];
  const items: AllergenItem[] = [];
  for (const entry of value) {
    if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) continue;
    const { name, level, original_text: originalText } = entry;
    if (typeof name !== 'string' || (level !== 'danger' && level !== 'caution')) continue;
    items.push({ name, level, originalText: typeof originalText === 'string' && originalText !== '' ? originalText : null });
  }
  return items;
}

function toDetail(row: DetailRow): RestaurantDetail {
  return {
    restaurantId: row.restaurant_id,
    name: row.name,
    address: row.address,
    region: row.region,
    phone: str(row.phone),
    imageUrl: str(row.image_url),
    avgRating: numOrNull(row.avg_rating),
    reviewCount: numOrNull(row.review_count) ?? 0,
    matchPercent: numOrNull(row.match_percent),
    reason: str(row.reason),
    isSaved: Boolean(row.is_saved),
    brandId: row.brand_id,
    brandName: row.brand_name,
    isFranchise: Boolean(row.is_franchise),
    sharedNotice: str(row.shared_notice),
    allergenSourceUrl: str(row.allergen_source_url),
    allergenDataDate: str(row.allergen_data_date),
    categoryName: categoryOrNull(row.category_name),
  };
}

function toRestaurantMenu(row: MenuRow): RestaurantMenu {
  return {
    menuId: row.menu_id,
    name: row.name,
    description: str(row.description),
    imageUrl: str(row.image_url),
    tasteTags: row.taste_tags ?? [],
    avgRating: numOrNull(row.avg_rating),
    matchPercent: numOrNull(row.match_percent),
    isSaved: Boolean(row.is_saved),
    myRating: numOrNull(row.my_rating),
    allergenStatus: row.allergen_status,
    allergenSourceUrl: str(row.allergen_source_url),
    allergenCheckedAt: str(row.allergen_checked_at),
    menuSourceName: str(row.menu_source_name),
    menuSourceUrl: str(row.menu_source_url),
  };
}

function toAllergyMenu(row: AllergyRow): AllergyMenu {
  return {
    menuId: row.menu_id,
    name: row.name,
    imageUrl: str(row.image_url),
    allergens: parseAllergenItems(row.allergens),
    allergenStatus: row.allergen_status,
    kind: row.kind === 'conflict' ? 'conflict' : 'unknown',
  };
}

/** 지점 상세. 없는 id 면 null (RPC 가 0행을 돌려준다). */
export async function getRestaurantDetail(restaurantId: number): Promise<RestaurantDetail | null> {
  try {
    const { data, error } = await supabase.rpc('get_restaurant_detail', { p_restaurant_id: restaurantId });
    if (error) throw error;
    const row = data?.[0];
    return row ? toDetail(row) : null;
  } catch {
    throw new Error('가게 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

export async function getRestaurantMenus(restaurantId: number): Promise<RestaurantMenu[]> {
  try {
    const { data, error } = await supabase.rpc('get_restaurant_menus', { p_restaurant_id: restaurantId });
    if (error) throw error;
    return (data ?? []).map(toRestaurantMenu);
  } catch {
    throw new Error('메뉴를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

export async function getAllergyMenus(restaurantId: number): Promise<AllergyMenu[]> {
  try {
    const { data, error } = await supabase.rpc('get_allergy_menus', { p_restaurant_id: restaurantId });
    if (error) throw error;
    return (data ?? []).map(toAllergyMenu);
  } catch {
    throw new Error('알레르기 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

/** 주어진 메뉴 중 내가 저장한 메뉴 id (RLS 로 본인 행만 조회된다). 알레르기 탭의 저장 버튼 초기 상태에 쓴다. */
export async function getSavedMenuIds(menuIds: number[]): Promise<Set<number>> {
  if (menuIds.length === 0) return new Set();
  try {
    const { data, error } = await supabase.from('saved_menus').select('menu_id').in('menu_id', menuIds);
    if (error) throw error;
    return new Set((data ?? []).map((row) => row.menu_id));
  } catch {
    throw new Error('저장한 메뉴를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

/** 메뉴 저장/저장 해제. RLS 로 본인 행만 가능하다. */
export async function toggleSaveMenu(menuId: number, saved: boolean): Promise<void> {
  try {
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) throw userError ?? new Error('no user');
    const userId = userData.user.id;
    const { error } = saved
      ? await supabase.from('saved_menus').upsert({ user_id: userId, menu_id: menuId }, { ignoreDuplicates: true })
      : await supabase.from('saved_menus').delete().eq('user_id', userId).eq('menu_id', menuId);
    if (error) throw error;
  } catch {
    throw new Error(saved ? '저장하지 못했어요. 잠시 후 다시 시도해주세요' : '저장을 해제하지 못했어요. 잠시 후 다시 시도해주세요');
  }
}
