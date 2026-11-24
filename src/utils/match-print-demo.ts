// 맛궁합 영수증 인쇄 화면의 데모 데이터 (?demo=1). 서버 없이 화면 흐름과 프린터를 시험할 때 쓴다. 실제 사용자 정보가 아니다.
import type { MatchFoodCompare, MatchRoomPair } from '../api/match';

export const DEMO_PAIRS: MatchRoomPair[] = [
  { memberNoA: 1, memberNoB: 2, nicknameA: '매운맛지수', nicknameB: '달달한하루', score: 80 },
  { memberNoA: 1, memberNoB: 3, nicknameA: '매운맛지수', nicknameB: '국밥러버', score: 50 },
  { memberNoA: 2, memberNoB: 3, nicknameA: '달달한하루', nicknameB: '국밥러버', score: 100 },
];

// 멤버별 음식 답 (방의 음식 5개). eaten 이면 별점, 아니면 먹어보고 싶은지
type DemoAnswer = { eaten: true; rating: number } | { eaten: false; wantTry: boolean };
const DEMO_FOODS = ['떡볶이', '민트초코 아이스크림', '마라탕', '평양냉면', '두리안'];
const DEMO_ANSWERS: Record<number, DemoAnswer[]> = {
  1: [{ eaten: true, rating: 5 }, { eaten: true, rating: 1 }, { eaten: true, rating: 5 }, { eaten: true, rating: 3 }, { eaten: false, wantTry: true }],
  2: [{ eaten: true, rating: 5 }, { eaten: true, rating: 5 }, { eaten: false, wantTry: true }, { eaten: true, rating: 2 }, { eaten: false, wantTry: true }],
  3: [{ eaten: true, rating: 3 }, { eaten: false, wantTry: false }, { eaten: true, rating: 4 }, { eaten: true, rating: 5 }, { eaten: false, wantTry: false }],
};

/** 두 멤버의 음식 답을 getMatchPairFoods 와 같은 모양으로 돌려준다 (A = my, B = friend) */
export function getDemoPairFoods(memberNoA: number, memberNoB: number): MatchFoodCompare[] {
  const a = DEMO_ANSWERS[memberNoA] ?? [];
  const b = DEMO_ANSWERS[memberNoB] ?? [];
  return DEMO_FOODS.flatMap((foodName, i) => {
    const mine = a[i];
    const theirs = b[i];
    if (!mine || !theirs) return [];
    return [
      {
        foodName,
        myEaten: mine.eaten,
        myRating: mine.eaten ? mine.rating : null,
        myWantTry: mine.eaten ? null : mine.wantTry,
        friendEaten: theirs.eaten,
        friendRating: theirs.eaten ? theirs.rating : null,
        friendWantTry: theirs.eaten ? null : theirs.wantTry,
      },
    ];
  });
}
