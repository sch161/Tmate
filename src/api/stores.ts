// 가게 추가. Edge Function(add-store)이 메뉴 이름으로 알레르기·맛을 AI 로 추정해 저장한다 (브라우저에서 AI 를 직접 부르지 않는다).
import { FunctionsHttpError } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

/** 한 번에 넣을 수 있는 메뉴 수 (functions.sql 의 store_menu_max 와 같다) */
export const STORE_MENU_MAX = 8;
export const STORE_NAME_MAX_LENGTH = 40;
export const MENU_NAME_MAX_LENGTH = 40;

export interface NewStoreMenu {
  name: string;
  description: string;
}

export interface NewStore {
  name: string;
  region: string;
  address: string;
  categoryId: number;
  menus: NewStoreMenu[];
}

export interface AddedStore {
  restaurantId: number;
  /** 이름만으로는 재료를 알 수 없어 알레르기가 "정보 없음"으로 저장된 메뉴 이름 */
  unknownMenus: string[];
}

const FALLBACK_MESSAGE = '추가하지 못했어요. 잠시 후 다시 시도해주세요';

/** 함수가 돌려준 오류 본문({ message })에서 사용자에게 보여줄 문구를 꺼낸다 */
async function readErrorMessage(error: unknown): Promise<string> {
  if (!(error instanceof FunctionsHttpError)) return FALLBACK_MESSAGE;
  try {
    const body: unknown = await (error.context as Response).json();
    const message = typeof body === 'object' && body !== null ? (body as Record<string, unknown>).message : null;
    return typeof message === 'string' && message.trim() !== '' ? message : FALLBACK_MESSAGE;
  } catch {
    return FALLBACK_MESSAGE;
  }
}

/** 가게와 메뉴를 추가한다. AI 추정 때문에 몇 초에서 십몇 초 걸릴 수 있다. */
export async function addStore(store: NewStore): Promise<AddedStore> {
  const { data, error } = await supabase.functions.invoke('add-store', { body: store });
  if (error) throw new Error(await readErrorMessage(error));
  const result = typeof data === 'object' && data !== null ? (data as Record<string, unknown>) : {};
  const restaurantId = result.restaurant_id;
  if (typeof restaurantId !== 'number') throw new Error(FALLBACK_MESSAGE);
  const unknownMenus = Array.isArray(result.unknown_menus) ? result.unknown_menus.filter((name): name is string => typeof name === 'string') : [];
  return { restaurantId, unknownMenus };
}

/** 내가 추가한 가게인지 (가게 상세에서 "메뉴 추가"를 보여줄지 정한다). 확인하지 못하면 false */
export async function isMyStore(restaurantId: number): Promise<boolean> {
  const { data, error } = await supabase.rpc('is_my_store', { p_restaurant_id: restaurantId });
  return !error && data === true;
}

/** 내가 추가한 가게에 메뉴를 더 넣는다 (알레르기·맛은 가게 추가와 똑같이 AI 가 추정한다) */
export async function addStoreMenus(restaurantId: number, menus: NewStoreMenu[]): Promise<AddedStore> {
  const { data, error } = await supabase.functions.invoke('add-store', { body: { restaurantId, menus } });
  if (error) throw new Error(await readErrorMessage(error));
  const result = typeof data === 'object' && data !== null ? (data as Record<string, unknown>) : {};
  const unknownMenus = Array.isArray(result.unknown_menus) ? result.unknown_menus.filter((name): name is string => typeof name === 'string') : [];
  return { restaurantId, unknownMenus };
}
