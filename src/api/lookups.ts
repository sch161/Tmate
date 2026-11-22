import { supabase } from '../lib/supabase';
import type { Tables } from '../types/database.types';

export type TasteTag = Tables<'taste_tags'>;
export type Allergen = Tables<'allergens'>;

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
    const { data, error } = await supabase.from('allergens').select('id, name').order('id');
    if (error) throw error;
    return data ?? [];
  } catch {
    throw new Error(LOAD_ERROR);
  }
}

/** 가게가 있는 지역(구 단위 문자열)을 중복 없이 가나다순으로 돌려준다. */
export async function getAvailableRegions(): Promise<string[]> {
  try {
    const { data, error } = await supabase.from('restaurants').select('region');
    if (error) throw error;
    const regions = new Set((data ?? []).map((row) => row.region));
    return Array.from(regions).sort((a, b) => a.localeCompare(b, 'ko'));
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
