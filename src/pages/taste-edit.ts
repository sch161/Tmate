// 입맛 수정 (마이페이지 → 계정 및 취향 설정, 홈의 "입맛 변경하기"). 온보딩과 같은 맛 선택·비율 UI 를 한 페이지의 두 단계로 쓴다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 입맛 수정 화면이 없다)
import { getMyTastes, updateMyTastes, type MyTaste } from '../api/me';
import { getTasteTags } from '../api/lookups';
import { PATHS } from '../lib/constants';
import { requireAuth } from '../utils/auth-guard';
import { el, qs, showToast } from '../utils/dom';
import { equalSplit } from '../utils/ratio';
import { createRatioSliders } from '../utils/ratio-sliders';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';
import { createTasteGrid, type TasteTagItem } from '../utils/taste-grid';

const LEAVE_DELAY_MS = 700;

const body = qs<HTMLElement>('#body');
const title = qs('#title');
const desc = qs('#desc');
const next = qs<HTMLButtonElement>('#next');
const footer = qs<HTMLElement>('.taste-edit__footer');
const backButton = qs<HTMLButtonElement>('#back');

type Step = 'select' | 'ratio';

// 뒤로가기 동작: 비율 단계에서는 맛 선택으로, 그 외에는 이전 화면으로
let onBack: () => void = leave;

function leave(): void {
  if (window.history.length > 1) window.history.back();
  else window.location.replace(PATHS.mypage);
}

/** 저장된 값과 같은지 (맛 id 와 비율이 모두 같으면 변경 없음) */
function sameTastes(a: MyTaste[], b: MyTaste[]): boolean {
  if (a.length !== b.length) return false;
  const byId = new Map(b.map((t) => [t.tasteId, t.ratio]));
  return a.every((t) => byId.get(t.tasteId) === t.ratio);
}

function render(tags: TasteTagItem[], mine: MyTaste[]): void {
  if (!body || !title || !desc || !next || !footer) return;
  // 목록에 없는 맛은 버린다. initial 은 서버에 저장된 값
  const valid = new Set(tags.map((t) => t.id));
  const initial = mine.filter((t) => valid.has(t.tasteId));
  const selected = new Set(initial.map((t) => t.tasteId));
  let step: Step = 'select';
  let ratios: number[] = [];
  let busy = false;

  /** 태그 목록 순서의 선택된 맛 */
  const chosen = (): TasteTagItem[] => tags.filter((t) => selected.has(t.id));
  const initialIds = new Set(initial.map((t) => t.tasteId));
  const selectionUnchanged = (): boolean => selected.size === initialIds.size && [...selected].every((id) => initialIds.has(id));

  /** 현재 화면의 값으로 만든 최종 입맛. 맛이 1개면 비율은 100 으로 자동 설정한다 */
  const current = (): MyTaste[] => {
    const items = chosen();
    if (items.length === 1) return [{ tasteId: items[0].id, ratio: 100 }];
    return items.map((t, i) => ({ tasteId: t.id, ratio: ratios[i] }));
  };

  const sync = (): void => {
    if (step === 'select') {
      const count = selected.size;
      next.textContent = count === 1 ? (busy ? '저장 중...' : '저장하기') : '다음으로';
      // 1개면 바로 저장하므로 변경이 없을 때는 저장할 수 없다. 2개 이상은 비율을 조절하러 갈 수 있다
      next.disabled = busy || count === 0 || (count === 1 && sameTastes(current(), initial));
    } else {
      next.textContent = busy ? '저장 중...' : '저장하기';
      next.disabled = busy || sameTastes(current(), initial);
    }
  };

  const showSelect = (): void => {
    step = 'select';
    title.textContent = '입맛 수정';
    desc.textContent = '최대 3개까지 선택할 수 있어요';
    body.replaceChildren(createTasteGrid(tags, selected, sync));
    footer.querySelector('.taste-edit__prev')?.remove();
    sync();
  };

  const showRatio = (): void => {
    step = 'ratio';
    title.textContent = '입맛 비율을 조절해 주세요';
    desc.textContent = '선택한 입맛의 비율을 조절해 주세요';
    const items = chosen();
    // 선택이 저장된 값과 같으면 저장된 비율로, 바뀌었으면 균등 분배로 시작한다
    const start = selectionUnchanged() ? items.map((t) => initial.find((i) => i.tasteId === t.id)?.ratio ?? 0) : equalSplit(items.length);
    ratios = start.reduce((s, v) => s + v, 0) === 100 ? start : equalSplit(items.length);
    body.replaceChildren(
      createRatioSliders(items, ratios, (values) => {
        ratios = values;
        sync();
      }),
    );
    if (!footer.querySelector('.taste-edit__prev')) {
      const prev = el('button', { class: 'taste-edit__prev', type: 'button' }, '맛 다시 고르기');
      prev.addEventListener('click', () => {
        if (!busy) showSelect();
      });
      footer.append(prev);
    }
    sync();
  };

  const save = async (): Promise<void> => {
    if (busy || next.disabled) return;
    const values = current();
    busy = true;
    sync();
    try {
      await updateMyTastes(values.map((t) => t.tasteId), values.map((t) => t.ratio));
      showToast('입맛을 바꿨어요');
      window.setTimeout(() => window.location.replace(PATHS.mypage), LEAVE_DELAY_MS);
    } catch (e) {
      showToast(e instanceof Error ? e.message : '저장하지 못했어요. 잠시 후 다시 시도해주세요');
      busy = false;
      sync();
    }
  };

  next.onclick = () => {
    if (next.disabled) return;
    if (step === 'select' && selected.size >= 2) showRatio();
    else void save();
  };
  onBack = () => {
    if (step === 'ratio' && !busy) showSelect();
    else leave();
  };
  showSelect();
}

async function load(): Promise<void> {
  if (!body || !next) return;
  next.disabled = true;
  renderLoading(body);
  try {
    const [tags, mine] = await Promise.all([getTasteTags(), getMyTastes()]);
    if (tags.length === 0) {
      renderEmpty(body, '선택할 수 있는 맛이 없어요', '잠시 후 다시 시도해주세요');
      return;
    }
    render(tags, mine);
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요', () => void load());
  }
}

async function start(): Promise<void> {
  backButton?.addEventListener('click', () => onBack());
  if (!(await requireAuth())) return;
  await load();
}

void start();
