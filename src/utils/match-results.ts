// 디자인 대기: 화면 나오면 교체
// 궁합 검사 결과 문구와 결과 카드 계산. 점수 계산은 서버(functions.sql)가 하고, 여기서는 보여줄 문구만 고른다.
import type { MatchFoodCompare } from '../api/match';

export interface MatchTier {
  title: string;
  desc: string;
}

// 점수 구간(10% 단위) → 결과 이름·설명. min 이상이면 그 구간이다 (위에서부터 찾는다)
const TIERS: { min: number; tier: MatchTier }[] = [
  { min: 100, tier: { title: '전생에 한 식탁을 쓴 사이', desc: '메뉴판을 볼 필요도 없는 영혼의 먹친구' } },
  { min: 90, tier: { title: '혀도 쌍둥이인가요?', desc: 'DNA 검사보다 정확한 입맛의 일치' } },
  { min: 80, tier: { title: '먹방 듀오 데뷔 가능', desc: '함께 맛집 투어를 떠나기 좋은 사이' } },
  { min: 70, tier: { title: '한입만 해도 기분 좋은 사이', desc: '서로의 메뉴까지 탐나는 이상적인 먹친구' } },
  { min: 60, tier: { title: '평화로운 겸상 가능', desc: '서로의 취향을 존중하면 문제없음' } },
  { min: 50, tier: { title: '반반 메뉴가 살린 우정', desc: '반반 메뉴를 개발한 사람에게 감사하세요' } },
  { min: 40, tier: { title: '아슬아슬한 식탁 외교', desc: '메뉴 선정부터 치열한 협상이 필요함' } },
  { min: 30, tier: { title: '메뉴판 앞에서는 남남', desc: '친한 건 알겠는데 입맛은 초면이네요' } },
  { min: 20, tier: { title: '같은 식당, 다른 세계관', desc: '서로의 주문을 이해하기 어려운 사이' } },
  { min: 0, tier: { title: '각자 배달시키세요', desc: '소중한 우정을 지키기 위해 개별 주문을 권장합니다' } },
];

export function getMatchTier(score: number): MatchTier {
  return (TIERS.find((t) => score >= t.min) ?? TIERS[TIERS.length - 1]).tier;
}

export interface MatchResultCard {
  label: string;
  foodName: string;
  detail: string;
}

const LOVE_MIN = 4; // 둘 다 이 별점 이상이면 "둘 다 사랑하는 음식"
const FIGHT_DIFF = 3; // 별점 차이가 이 값 이상이면 "우정을 위협하는 음식"

/** 카드 문구에 넣을 두 사람의 이름 (영수증처럼 "나·친구"가 아닌 제3자가 볼 때) */
export interface MatchCardNames {
  me: string;
  friend: string;
}

/**
 * 음식별 답으로 결과 카드를 만든다. 종류마다 가장 뚜렷한 음식 하나만 고르고, 해당하는 음식이 없는 카드는 만들지 않는다.
 * 안 먹어본 음식은 점수에 쓰지 않고 "영업할 음식"·"함께 도전할 음식" 카드에만 쓴다.
 * names 를 주면 "나"·"친구" 대신 그 이름으로 쓴다 (맛궁합 영수증용).
 */
export function buildResultCards(rows: MatchFoodCompare[], names?: MatchCardNames): MatchResultCard[] {
  const cards: MatchResultCard[] = [];
  const me = names?.me ?? '나';
  const friend = names?.friend ?? '친구';
  const both = rows.filter((r) => r.myEaten && r.friendEaten && r.myRating !== null && r.friendRating !== null);
  const rating = (v: number | null): number => v ?? 0;

  const love = both.filter((r) => rating(r.myRating) >= LOVE_MIN && rating(r.friendRating) >= LOVE_MIN).sort((a, b) => rating(b.myRating) + rating(b.friendRating) - (rating(a.myRating) + rating(a.friendRating)))[0];
  if (love) cards.push({ label: '둘 다 사랑하는 음식', foodName: love.foodName, detail: `${me} ${love.myRating}점 · ${friend} ${love.friendRating}점` });

  const fight = both.filter((r) => Math.abs(rating(r.myRating) - rating(r.friendRating)) >= FIGHT_DIFF).sort((a, b) => Math.abs(rating(b.myRating) - rating(b.friendRating)) - Math.abs(rating(a.myRating) - rating(a.friendRating)))[0];
  if (fight) cards.push({ label: '우정을 위협하는 음식', foodName: fight.foodName, detail: `${me} ${fight.myRating}점 · ${friend} ${fight.friendRating}점` });

  const pitch = rows.filter((r) => r.myEaten && rating(r.myRating) >= LOVE_MIN && !r.friendEaten).sort((a, b) => rating(b.myRating) - rating(a.myRating))[0];
  if (pitch) cards.push({ label: names ? `${me} 님이 영업할 음식` : '친구에게 영업할 음식', foodName: pitch.foodName, detail: `${me} ${pitch.myRating}점 · ${friend} 아직 안 먹어봄` });

  const pitched = rows.filter((r) => r.friendEaten && rating(r.friendRating) >= LOVE_MIN && !r.myEaten).sort((a, b) => rating(b.friendRating) - rating(a.friendRating))[0];
  if (pitched) cards.push({ label: names ? `${friend} 님이 영업할 음식` : '친구가 영업할 음식', foodName: pitched.foodName, detail: `${friend} ${pitched.friendRating}점 · ${me} 아직 안 먹어봄` });

  const dare = rows.find((r) => !r.myEaten && !r.friendEaten && r.myWantTry === true && r.friendWantTry === true);
  if (dare) cards.push({ label: '함께 도전할 음식', foodName: dare.foodName, detail: '둘 다 안 먹어봤지만 먹어보고 싶음' });

  return cards;
}
