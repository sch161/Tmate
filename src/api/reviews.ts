import { supabase } from '../lib/supabase';
import { getSession } from './auth';

/** 평가 작성 화면용 메뉴 정보. 평가는 브랜드 메뉴 단위라 같은 브랜드의 모든 지점이 공유한다. */
export interface ReviewMenu {
  menuId: number;
  name: string;
  description: string | null;
  imageUrl: string | null;
  brandName: string;
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
      .select('id, name, description, image_url, brands(name)')
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
