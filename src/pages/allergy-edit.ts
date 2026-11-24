// 알레르기 수정 (마이페이지 → 계정 및 취향 설정). 온보딩 알레르기 화면과 같은 카드 그리드를 쓴다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 알레르기 수정 화면이 없다)
import { getAllergens, type Allergen } from '../api/lookups';
import { getMyAllergenIds, updateMyAllergens } from '../api/me';
import { createAllergenGrid } from '../utils/allergen-grid';
import { requireAuth } from '../utils/auth-guard';
import { qs, showToast } from '../utils/dom';
import { goAfterSave, goBack } from '../utils/navigation';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';

const LEAVE_DELAY_MS = 700;

const body = qs<HTMLElement>('#body');
const saveButton = qs<HTMLButtonElement>('#save');
const backButton = qs<HTMLButtonElement>('#back');

function sameSet(a: Set<number>, b: Set<number>): boolean {
  return a.size === b.size && [...a].every((id) => b.has(id));
}

function leave(): void {
  goBack();
}

function render(allergens: Allergen[], mine: number[]): void {
  if (!body || !saveButton) return;
  // 목록에 없는 id 는 버린다. initial 은 서버에 저장된 값, selected 는 화면에서 고른 값
  const valid = new Set(allergens.map((a) => a.id));
  const initial = new Set(mine.filter((id) => valid.has(id)));
  const selected = new Set(initial);
  let busy = false;

  const sync = (): void => {
    // 변경이 없으면 저장할 수 없다. 0개 선택(전부 해제)도 변경이면 저장할 수 있다
    saveButton.disabled = busy || sameSet(initial, selected);
  };

  body.replaceChildren(createAllergenGrid(allergens, selected, sync));
  sync();

  saveButton.onclick = async () => {
    if (busy || sameSet(initial, selected)) return;
    // 안전 확인: 알레르기가 있었는데 전부 해제하면 추천의 알레르기 필터가 꺼진다
    if (initial.size > 0 && selected.size === 0 && !window.confirm('알레르기를 모두 해제할까요? 추천에서 알레르기 필터가 적용되지 않아요')) return;
    busy = true;
    saveButton.textContent = '저장 중...';
    sync();
    try {
      await updateMyAllergens([...selected]);
      showToast('알레르기를 바꿨어요');
      window.setTimeout(goAfterSave, LEAVE_DELAY_MS);
    } catch (e) {
      showToast(e instanceof Error ? e.message : '저장하지 못했어요. 잠시 후 다시 시도해주세요');
      busy = false;
      saveButton.textContent = '저장하기';
      sync();
    }
  };
}

async function load(): Promise<void> {
  if (!body || !saveButton) return;
  saveButton.disabled = true;
  renderLoading(body);
  try {
    const [allergens, mine] = await Promise.all([getAllergens(), getMyAllergenIds()]);
    if (allergens.length === 0) {
      renderEmpty(body, '선택할 수 있는 항목이 없어요', '잠시 후 다시 확인해주세요');
      return;
    }
    render(allergens, mine);
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요', () => void load());
  }
}

async function start(): Promise<void> {
  backButton?.addEventListener('click', leave);
  if (!(await requireAuth())) return;
  await load();
}

void start();
