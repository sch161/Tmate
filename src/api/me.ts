import { supabase } from '../lib/supabase';
import { getSession } from './auth';

/** 내 지역(profiles.region)을 바꾼다. RLS·컬럼 권한으로 본인 행만 수정된다. */
export async function updateMyRegion(region: string): Promise<void> {
  try {
    const session = await getSession();
    if (!session) throw new Error('no session');
    const { error } = await supabase.from('profiles').update({ region }).eq('id', session.user.id);
    if (error) throw error;
  } catch {
    throw new Error('지역을 바꾸지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

/** 내가 등록한 알레르기 개수. 0 이면 "등록한 알레르기 없음" 으로 취급한다. RLS 로 본인 행만 센다. */
export async function getMyAllergenCount(): Promise<number> {
  try {
    const { count, error } = await supabase.from('user_allergens').select('allergen_id', { count: 'exact', head: true });
    if (error) throw error;
    return count ?? 0;
  } catch {
    throw new Error('알레르기 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}
