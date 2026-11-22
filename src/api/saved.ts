import { supabase } from '../lib/supabase';
import { getSession } from './auth';
import { getTasteTags } from './lookups';
import type { AllergenStatus } from './restaurants';

// 저장 목록: saved_restaurants 는 지점 단위, saved_menus 는 브랜드 메뉴 단위다.
// 테이블 직접 조회는 RLS 가 허용한 범위만 쓰고, user_id = 내 id 필터를 항상 건다.

/** 저장한 가게(지점) 한 건 */
export interface SavedRestaurant {
  restaurantId: number;
  name: string;
  address: string;
  region: string;
  imageUrl: string | null;
  brandName: string;
  /** 평가가 없으면 null */
  avgRating: number | null;
  tasteTags: string[];
}

/** 저장한 메뉴(브랜드 메뉴) 한 건. 메뉴는 지점이 아니라 브랜드에 속한다. */
export interface SavedMenu {
  menuId: number;
  name: string;
  description: string | null;
  imageUrl: string | null;
  brandId: number;
  brandName: string;
  /** 평가가 없으면 null */
  avgRating: number | null;
  tasteTags: string[];
  allergenStatus: AllergenStatus;
  /** 내가 등록한 알레르기와 이 메뉴의 알레르기가 겹치는지 (menu_allergens ∩ user_allergens) */
  conflictsWithMyAllergens: boolean;
}

const LOAD_ERROR = '저장 목록을 불러오지 못했어요. 잠시 후 다시 시도해주세요';

function str(value: string | null | undefined): string | null {
  return typeof value === 'string' && value.trim() !== '' ? value.trim() : null;
}

async function requireUserId(): Promise<string> {
  const session = await getSession();
  if (!session) throw new Error('no session');
  return session.user.id;
}

/** 저장한 가게, 저장 최신순. */
export async function getSavedRestaurants(): Promise<SavedRestaurant[]> {
  try {
    const userId = await requireUserId();
    const { data: saved, error: savedError } = await supabase
      .from('saved_restaurants')
      .select('restaurant_id, created_at')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });
    if (savedError) throw savedError;
    const ids = (saved ?? []).map((row) => row.restaurant_id);
    if (ids.length === 0) return [];

    const [restaurants, stats, tagLinks, tags] = await Promise.all([
      supabase.from('restaurants').select('id, name, address, region, image_url, brands(name)').in('id', ids),
      supabase.from('restaurant_stats').select('restaurant_id, avg_rating').in('restaurant_id', ids),
      supabase.from('restaurant_taste_tags').select('restaurant_id, taste_tag_id').in('restaurant_id', ids),
      getTasteTags(),
    ]);
    if (restaurants.error) throw restaurants.error;
    if (stats.error) throw stats.error;
    if (tagLinks.error) throw tagLinks.error;

    const rows = new Map((restaurants.data ?? []).map((row) => [row.id, row]));
    const ratings = new Map<number, number | null>();
    for (const row of stats.data ?? []) if (row.restaurant_id !== null) ratings.set(row.restaurant_id, row.avg_rating);
    const tagNames = new Map(tags.map((tag) => [tag.id, tag.name]));
    const tagsByRestaurant = new Map<number, string[]>();
    for (const link of tagLinks.data ?? []) {
      if (link.restaurant_id === null || link.taste_tag_id === null) continue;
      const name = tagNames.get(link.taste_tag_id);
      if (name) tagsByRestaurant.set(link.restaurant_id, [...(tagsByRestaurant.get(link.restaurant_id) ?? []), name]);
    }

    const result: SavedRestaurant[] = [];
    for (const id of ids) {
      const row = rows.get(id);
      if (!row) continue;
      result.push({
        restaurantId: row.id,
        name: row.name,
        address: row.address,
        region: row.region,
        imageUrl: str(row.image_url),
        brandName: row.brands?.name ?? '',
        avgRating: ratings.get(id) ?? null,
        tasteTags: tagsByRestaurant.get(id) ?? [],
      });
    }
    return result;
  } catch {
    throw new Error(LOAD_ERROR);
  }
}

/** 저장한 메뉴, 저장 최신순. */
export async function getSavedMenus(): Promise<SavedMenu[]> {
  try {
    const userId = await requireUserId();
    const { data: saved, error: savedError } = await supabase
      .from('saved_menus')
      .select('menu_id, created_at')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });
    if (savedError) throw savedError;
    const ids = (saved ?? []).map((row) => row.menu_id);
    if (ids.length === 0) return [];

    const [menus, stats, tagLinks, menuAllergens, myAllergens, tags] = await Promise.all([
      supabase.from('menus').select('id, name, description, image_url, brand_id, allergen_status, brands(name)').in('id', ids),
      supabase.from('menu_stats').select('menu_id, avg_rating').in('menu_id', ids),
      supabase.from('menu_taste_tags').select('menu_id, taste_tag_id').in('menu_id', ids),
      supabase.from('menu_allergens').select('menu_id, allergen_id').in('menu_id', ids),
      supabase.from('user_allergens').select('allergen_id').eq('user_id', userId),
      getTasteTags(),
    ]);
    if (menus.error) throw menus.error;
    if (stats.error) throw stats.error;
    if (tagLinks.error) throw tagLinks.error;
    if (menuAllergens.error) throw menuAllergens.error;
    if (myAllergens.error) throw myAllergens.error;

    const rows = new Map((menus.data ?? []).map((row) => [row.id, row]));
    const ratings = new Map<number, number | null>();
    for (const row of stats.data ?? []) if (row.menu_id !== null) ratings.set(row.menu_id, row.avg_rating);
    const tagNames = new Map(tags.map((tag) => [tag.id, tag.name]));
    const tagsByMenu = new Map<number, string[]>();
    for (const link of tagLinks.data ?? []) {
      const name = tagNames.get(link.taste_tag_id);
      if (name) tagsByMenu.set(link.menu_id, [...(tagsByMenu.get(link.menu_id) ?? []), name]);
    }
    const mine = new Set((myAllergens.data ?? []).map((row) => row.allergen_id));
    const conflicting = new Set<number>();
    for (const row of menuAllergens.data ?? []) if (mine.has(row.allergen_id)) conflicting.add(row.menu_id);

    const result: SavedMenu[] = [];
    for (const id of ids) {
      const row = rows.get(id);
      if (!row) continue;
      result.push({
        menuId: row.id,
        name: row.name,
        description: str(row.description),
        imageUrl: str(row.image_url),
        brandId: row.brand_id,
        brandName: row.brands?.name ?? '',
        avgRating: ratings.get(id) ?? null,
        tasteTags: tagsByMenu.get(id) ?? [],
        allergenStatus: row.allergen_status,
        conflictsWithMyAllergens: conflicting.has(id),
      });
    }
    return result;
  } catch {
    throw new Error(LOAD_ERROR);
  }
}

/** 해당 지역에서 그 브랜드의 지점 중 id 가 가장 작은 하나. 없으면 null. 저장 메뉴 카드의 이동 대상이다. */
export async function findBranchInRegion(brandId: number, region: string): Promise<number | null> {
  try {
    const { data, error } = await supabase
      .from('restaurants')
      .select('id')
      .eq('brand_id', brandId)
      .eq('region', region)
      .order('id', { ascending: true })
      .limit(1);
    if (error) throw error;
    return data?.[0]?.id ?? null;
  } catch {
    throw new Error('지점을 찾지 못했어요. 잠시 후 다시 시도해주세요');
  }
}
