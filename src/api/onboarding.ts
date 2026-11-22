import { supabase } from '../lib/supabase';

export type TasteRatio = { taste_tag_id: number; ratio: number };

export interface SaveOnboardingInput {
  region: string;
  tastes: TasteRatio[];
  allergenIds: number[];
}

/** 온보딩 결과를 한 번에 저장한다 (취향·알레르기 교체, region 설정, onboarding_done = true). */
export async function saveOnboarding(input: SaveOnboardingInput): Promise<void> {
  let message = '저장하지 못했어요. 잠시 후 다시 시도해주세요';
  try {
    const { error } = await supabase.rpc('save_onboarding', {
      p_region: input.region,
      p_tastes: input.tastes,
      p_allergens: input.allergenIds,
    });
    if (!error) return;
    // RPC 가 던지는 한국어 예외 메시지는 그대로 보여준다
    if (/[가-힣]/.test(error.message)) message = error.message;
  } catch {
    message = '네트워크 오류가 발생했어요. 잠시 후 다시 시도해주세요';
  }
  throw new Error(message);
}
