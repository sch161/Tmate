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

/** 맛 비율 한 건 (get_my_summary 의 taste_ratios 원소) */
export interface TasteRatio {
  name: string;
  ratio: number;
}

/** 마이페이지 요약. 입맛 유형·설명은 입맛 정보가 없으면 null 일 수 있다. */
export interface MySummary {
  nickname: string;
  region: string | null;
  /** 비율 내림차순. 형태가 맞지 않는 항목은 버린다. */
  tasteRatios: TasteRatio[];
  tasteTypeName: string | null;
  tasteTypeDesc: string | null;
  savedRestaurantCount: number;
  reviewCount: number;
  mateCount: number;
}

/** taste_ratios(jsonb)를 런타임에서 검증해 읽는다. [{"name": "매콤함", "ratio": 60}] 형태만 받는다. */
export function parseTasteRatios(value: unknown): TasteRatio[] {
  if (!Array.isArray(value)) return [];
  const ratios: TasteRatio[] = [];
  for (const entry of value) {
    if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) continue;
    const { name, ratio } = entry as Record<string, unknown>;
    if (typeof name !== 'string' || name.trim() === '' || typeof ratio !== 'number' || !Number.isFinite(ratio)) continue;
    ratios.push({ name: name.trim(), ratio: Math.min(100, Math.max(0, ratio)) });
  }
  return ratios.sort((a, b) => b.ratio - a.ratio);
}

const count = (value: number | null | undefined): number => (typeof value === 'number' && Number.isFinite(value) ? value : 0);
const text = (value: string | null | undefined): string | null => (typeof value === 'string' && value.trim() !== '' ? value.trim() : null);

/** 마이페이지 요약(get_my_summary). 행이 없으면 null. */
export async function getMySummary(): Promise<MySummary | null> {
  try {
    const { data, error } = await supabase.rpc('get_my_summary');
    if (error) throw error;
    const row = data?.[0];
    if (!row) return null;
    return {
      nickname: text(row.nickname) ?? '',
      region: text(row.region),
      tasteRatios: parseTasteRatios(row.taste_ratios),
      tasteTypeName: text(row.taste_type_name),
      tasteTypeDesc: text(row.taste_type_desc),
      savedRestaurantCount: count(row.saved_restaurant_count),
      reviewCount: count(row.review_count),
      mateCount: count(row.mate_count),
    };
  } catch {
    throw new Error('내 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

/** 내가 등록한 알레르기 id 목록. user_id = 내 id 로 거른다. */
export async function getMyAllergenIds(): Promise<number[]> {
  try {
    const session = await getSession();
    if (!session) throw new Error('no session');
    const { data, error } = await supabase.from('user_allergens').select('allergen_id').eq('user_id', session.user.id);
    if (error) throw error;
    return (data ?? []).map((row) => row.allergen_id);
  } catch {
    throw new Error('알레르기 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

/** 내 알레르기를 통째로 교체한다(빈 배열이면 모두 해제). 서버 함수 하나가 한 트랜잭션으로 처리한다. */
export async function updateMyAllergens(allergenIds: number[]): Promise<void> {
  let message = '저장하지 못했어요. 잠시 후 다시 시도해주세요';
  try {
    const { error } = await supabase.rpc('update_my_allergens', { p_allergen_ids: allergenIds });
    if (!error) return;
    // RPC 가 던지는 한국어 예외 메시지는 그대로 보여준다
    if (/[가-힣]/.test(error.message)) message = error.message;
  } catch {
    message = '네트워크 오류가 발생했어요. 잠시 후 다시 시도해주세요';
  }
  throw new Error(message);
}

export const NICKNAME_MAX_LENGTH = 20;

/** 앞뒤 공백을 지운 닉네임이 1~20자인지. schema.sql 에는 닉네임 제약이 없어 앱 규칙으로 정한다. */
export function validateNickname(value: string): string | null {
  const nickname = value.trim();
  if (nickname.length === 0) return '닉네임을 입력해주세요';
  if (nickname.length > NICKNAME_MAX_LENGTH) return `닉네임은 ${NICKNAME_MAX_LENGTH}자 이하로 입력해주세요`;
  return null;
}

/** 닉네임을 바꾼다. RLS·컬럼 권한으로 본인 행의 nickname 만 수정된다. */
export async function updateMyNickname(nickname: string): Promise<void> {
  const trimmed = nickname.trim();
  const invalid = validateNickname(trimmed);
  if (invalid) throw new Error(invalid);
  try {
    const session = await getSession();
    if (!session) throw new Error('no session');
    const { error } = await supabase.from('profiles').update({ nickname: trimmed }).eq('id', session.user.id);
    if (error) throw error;
  } catch {
    throw new Error('닉네임을 바꾸지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

/** 내 입맛 한 건 (맛 id + 비율) */
export interface MyTaste {
  tasteId: number;
  ratio: number;
}

/** 내가 등록한 입맛(맛 id + 비율), 비율 내림차순. user_id = 내 id 로 거른다. */
export async function getMyTastes(): Promise<MyTaste[]> {
  try {
    const session = await getSession();
    if (!session) throw new Error('no session');
    const { data, error } = await supabase
      .from('user_taste_preferences')
      .select('taste_tag_id, ratio')
      .eq('user_id', session.user.id)
      .order('ratio', { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row) => ({ tasteId: row.taste_tag_id, ratio: row.ratio }));
  } catch {
    throw new Error('입맛 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  }
}

/** 내 입맛(맛 선택 + 비율)을 통째로 교체한다. tasteIds 와 ratios 는 같은 순서의 짝이고, 서버 함수가 한 트랜잭션으로 검증·저장한다. */
export async function updateMyTastes(tasteIds: number[], ratios: number[]): Promise<void> {
  let message = '저장하지 못했어요. 잠시 후 다시 시도해주세요';
  try {
    const { error } = await supabase.rpc('update_my_tastes', { p_taste_ids: tasteIds, p_ratios: ratios });
    if (!error) return;
    // RPC 가 던지는 한국어 예외 메시지는 그대로 보여준다
    if (/[가-힣]/.test(error.message)) message = error.message;
  } catch {
    message = '네트워크 오류가 발생했어요. 잠시 후 다시 시도해주세요';
  }
  throw new Error(message);
}
