import { supabase } from '../lib/supabase';

/**
 * 주어진 메뉴 중 내가 등록한 알레르기와 겹치는 메뉴 id (menu_allergens ∩ user_allergens).
 * 저장 목록·내가 평가한 메뉴가 같이 쓴다. 실패하면 예외를 그대로 던지므로 호출한 쪽이 처리한다.
 */
export async function getConflictingMenuIds(userId: string, menuIds: number[]): Promise<Set<number>> {
  if (menuIds.length === 0) return new Set();
  const [menuAllergens, myAllergens] = await Promise.all([
    supabase.from('menu_allergens').select('menu_id, allergen_id').in('menu_id', menuIds),
    supabase.from('user_allergens').select('allergen_id').eq('user_id', userId),
  ]);
  if (menuAllergens.error) throw menuAllergens.error;
  if (myAllergens.error) throw myAllergens.error;
  const mine = new Set((myAllergens.data ?? []).map((row) => row.allergen_id));
  const conflicting = new Set<number>();
  for (const row of menuAllergens.data ?? []) if (mine.has(row.allergen_id)) conflicting.add(row.menu_id);
  return conflicting;
}
