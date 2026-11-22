import { supabase } from '../lib/supabase';
import type { Tables } from '../types/database.types';

export type TasteTag = Tables<'taste_tags'>;
/** 화면에는 display_name(예: 알류 → '계란')을 보여주고, 저장·비교는 id 로 한다. */
export type Allergen = Pick<Tables<'allergens'>, 'id' | 'name' | 'display_name'>;

const LOAD_ERROR = '목록을 불러오지 못했어요. 잠시 후 다시 시도해주세요';

export async function getTasteTags(): Promise<TasteTag[]> {
  try {
    const { data, error } = await supabase.from('taste_tags').select('id, code, name').order('id');
    if (error) throw error;
    return data ?? [];
  } catch {
    throw new Error(LOAD_ERROR);
  }
}

export async function getAllergens(): Promise<Allergen[]> {
  try {
    const { data, error } = await supabase.from('allergens').select('id, name, display_name').order('id');
    if (error) throw error;
    return data ?? [];
  } catch {
    throw new Error(LOAD_ERROR);
  }
}

/** 지점이 있는 지역 한 건 (get_regions RPC) */
export interface RegionOption {
  region: string;
  sido: string | null;
  sigungu: string | null;
  restaurantCount: number;
}

/** 지점이 있는 지역 목록을 가나다순으로 돌려준다. 지점이 없으면 빈 배열. */
export async function getAvailableRegions(): Promise<RegionOption[]> {
  try {
    const { data, error } = await supabase.rpc('get_regions');
    if (error) throw error;
    return (data ?? [])
      .map((row) => ({
        region: row.region,
        sido: row.sido ?? null,
        sigungu: row.sigungu ?? null,
        restaurantCount: Number(row.restaurant_count) || 0,
      }))
      .sort((a, b) => a.region.localeCompare(b.region, 'ko'));
  } catch {
    throw new Error(LOAD_ERROR);
  }
}

export type FoodCategory = Tables<'food_categories'>;

export async function getFoodCategories(): Promise<FoodCategory[]> {
  try {
    const { data, error } = await supabase.from('food_categories').select('id, name').order('id');
    if (error) throw error;
    return data ?? [];
  } catch {
    throw new Error(LOAD_ERROR);
  }
}
