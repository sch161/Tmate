// 맛궁합 랭킹: 부스의 큰 화면에 띄워 두는 페이지. 진행자 계정으로 로그인한 뒤 열어 두면 몇 초마다 스스로 갱신한다.
// 디자인 대기: 화면 나오면 교체 (Figma 에 이 화면이 없다)
import { getMatchRanking, type MatchRankingRow } from '../api/match';
import { requireAuth } from '../utils/auth-guard';
import { el, qs } from '../utils/dom';
import { getMatchTier } from '../utils/match-results';
import { renderEmpty, renderError, renderLoading } from '../utils/state-views';

const REFRESH_MS = 5000;
const LIMIT = 10;

const body = qs<HTMLElement>('#body');
const updated = qs('#updated');
let lastKey = '';

function row(item: MatchRankingRow): HTMLElement {
  return el(
    'li',
    { class: item.rank <= 3 ? 'rank-row rank-row--top' : 'rank-row' },
    el('span', { class: 'rank-row__rank' }, String(item.rank)),
    el('span', { class: 'rank-row__names' }, el('span', { class: 'rank-row__pair' }, `${item.nicknameA} · ${item.nicknameB}`), el('span', { class: 'rank-row__tier' }, getMatchTier(item.score).title)),
    el('span', { class: 'rank-row__score' }, `${item.score}%`),
  );
}

function paint(list: MatchRankingRow[]): void {
  if (!body) return;
  if (updated) updated.textContent = `${new Date().toLocaleTimeString('ko-KR')} 기준`;
  // 바뀐 것이 없으면 다시 그리지 않는다
  const key = JSON.stringify(list);
  if (key === lastKey) return;
  lastKey = key;
  if (list.length === 0) {
    renderEmpty(body, '아직 검사를 마친 팀이 없어요', '첫 번째 주인공이 되어 보세요');
    return;
  }
  body.replaceChildren(el('ol', { class: 'rank__list' }, ...list.map(row)));
}

async function load(): Promise<void> {
  if (!body) return;
  renderLoading(body);
  try {
    paint(await getMatchRanking(LIMIT));
  } catch (e) {
    renderError(body, e instanceof Error ? e.message : '랭킹을 불러오지 못했어요', () => void load());
    return;
  }
  window.setInterval(() => {
    // 일시적인 조회 실패는 화면을 그대로 두고 다음 주기에 다시 시도한다
    getMatchRanking(LIMIT).then(paint).catch(() => undefined);
  }, REFRESH_MS);
}

async function start(): Promise<void> {
  if (!(await requireAuth())) return;
  await load();
}

void start();
