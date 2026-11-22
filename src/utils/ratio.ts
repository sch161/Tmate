// 입맛 비율 계산. 합계는 항상 정확히 100, 각 비율은 최소 1 이다.
const TOTAL = 100;
const MIN = 1;

/** 균등 분배. 나머지는 앞 항목부터 1씩 (3개 → 34/33/33). */
export function equalSplit(count: number): number[] {
  if (count <= 0) return [];
  const base = Math.floor(TOTAL / count);
  const rest = TOTAL - base * count;
  return Array.from({ length: count }, (_, i) => base + (i < rest ? 1 : 0));
}

/**
 * values[index] 를 next 로 바꾸고 나머지를 현재 비율에 비례해 조정한다.
 * 반올림 오차는 나머지 중 가장 큰 항목에 맞춘다.
 */
export function adjustRatios(values: number[], index: number, next: number): number[] {
  const n = values.length;
  if (n <= 1) return [TOTAL];
  const target = Math.min(Math.max(Math.round(next), MIN), TOTAL - MIN * (n - 1));
  const rest = TOTAL - target;

  const others = values.map((v, i) => ({ v, i })).filter((o) => o.i !== index);
  const sumOthers = others.reduce((s, o) => s + o.v, 0);

  const result = values.slice();
  result[index] = target;
  for (const o of others) {
    const scaled = sumOthers > 0 ? (o.v / sumOthers) * rest : rest / others.length;
    result[o.i] = Math.max(MIN, Math.round(scaled));
  }

  // 반올림·최솟값 보정으로 생긴 차이를 가장 큰 항목에 맞춘다
  let diff = rest - others.reduce((s, o) => s + result[o.i], 0);
  while (diff !== 0) {
    const candidates = others
      .map((o) => o.i)
      .filter((i) => (diff > 0 ? true : result[i] > MIN))
      .sort((a, b) => result[b] - result[a]);
    if (candidates.length === 0) break;
    const step = diff > 0 ? 1 : -1;
    result[candidates[0]] += step;
    diff -= step;
  }
  return result;
}
