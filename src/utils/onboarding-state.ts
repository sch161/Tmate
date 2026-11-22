// 온보딩 단계 간 선택값을 sessionStorage 의 단일 키에 JSON 으로 보관한다.
const STORAGE_KEY = 'tmate.onboarding';

export interface OnboardingState {
  region: string | null;
  /** 선택한 맛 id (최대 3개) */
  tasteIds: number[];
  /** 맛 id → 비율(%) */
  ratios: Record<number, number>;
  allergenIds: number[];
}

function emptyState(): OnboardingState {
  return { region: null, tasteIds: [], ratios: {}, allergenIds: [] };
}

function isNumberArray(v: unknown): v is number[] {
  return Array.isArray(v) && v.every((x) => typeof x === 'number' && Number.isInteger(x));
}

/** 저장된 값을 읽는다. 없거나 깨져 있으면 빈 상태를 돌려준다. */
export function loadState(): OnboardingState {
  const state = emptyState();
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (!raw) return state;
    const data: unknown = JSON.parse(raw);
    if (typeof data !== 'object' || data === null) return state;
    const d = data as Record<string, unknown>;
    if (typeof d.region === 'string' && d.region) state.region = d.region;
    if (isNumberArray(d.tasteIds)) state.tasteIds = d.tasteIds;
    if (isNumberArray(d.allergenIds)) state.allergenIds = d.allergenIds;
    if (typeof d.ratios === 'object' && d.ratios !== null) {
      for (const [key, value] of Object.entries(d.ratios)) {
        if (typeof value === 'number' && Number.isInteger(value)) state.ratios[Number(key)] = value;
      }
    }
  } catch {
    // 저장소를 못 읽으면 빈 상태로 시작한다
  }
  return state;
}

/** 일부 값만 바꿔 저장하고 합쳐진 상태를 돌려준다. */
export function updateState(patch: Partial<OnboardingState>): OnboardingState {
  const next = { ...loadState(), ...patch };
  try {
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  } catch {
    // 저장 실패 시 현재 단계만 진행된다 (뒤로가기 복원은 안 될 수 있음)
  }
  return next;
}

export function clearState(): void {
  try {
    sessionStorage.removeItem(STORAGE_KEY);
  } catch {
    // 무시
  }
}

/** 모든 선택한 맛에 비율이 있고 합계가 100 인지 */
export function hasValidRatios(state: OnboardingState): boolean {
  if (state.tasteIds.length === 0) return false;
  let sum = 0;
  for (const id of state.tasteIds) {
    const r = state.ratios[id];
    if (typeof r !== 'number' || r < 1) return false;
    sum += r;
  }
  return sum === 100;
}
