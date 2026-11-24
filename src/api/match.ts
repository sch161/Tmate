// 친구랑 궁합 검사 RPC 호출. 테이블은 클라이언트에 열려 있지 않아 모두 RPC 로만 읽고 쓴다.
import { supabase } from '../lib/supabase';

export interface MatchQuestion {
  questionId: number;
  body: string;
  optionA: string;
  optionB: string;
  /** 1 = A, 2 = B, null = 아직 답하지 않음 */
  myChoice: 1 | 2 | null;
}

export interface MatchFood {
  foodId: number;
  name: string;
  /** null = 아직 답하지 않음 */
  myEaten: boolean | null;
  myRating: number | null;
  myWantTry: boolean | null;
}

export interface MatchMember {
  memberNo: number;
  nickname: string;
  isMe: boolean;
  completed: boolean;
  /** 나와의 궁합(%). 나 자신이거나 둘 중 하나가 검사를 마치지 않았으면 null */
  score: number | null;
}

export interface MatchFoodCompare {
  foodName: string;
  myEaten: boolean;
  myRating: number | null;
  myWantTry: boolean | null;
  friendEaten: boolean;
  friendRating: number | null;
  friendWantTry: boolean | null;
}

export interface MatchRankingRow {
  rank: number;
  nicknameA: string;
  nicknameB: string;
  score: number;
}

export interface MatchChoiceAnswer {
  questionId: number;
  choice: 1 | 2;
}

export type MatchFoodAnswer = { foodId: number; eaten: true; rating: number } | { foodId: number; eaten: false; wantTry: boolean };

/** 서버가 raise 한 한국어 메시지(방 번호 오류 등)는 그대로 보여주고, 그 외에는 fallback 문구를 쓴다 */
function toError(error: { message?: string; code?: string } | null, fallback: string): Error {
  // P0001 = plpgsql raise exception. 우리 RPC 가 사용자에게 보여줄 문구로 던진 것이다
  if (error?.code === 'P0001' && error.message) return new Error(error.message);
  return new Error(fallback);
}

/** 방을 만들고 들어간다. 4자리 방 번호를 돌려준다. */
export async function createMatchRoom(): Promise<string> {
  const { data, error } = await supabase.rpc('create_match_room');
  if (error || !data) throw toError(error, '방을 만들지 못했어요. 잠시 후 다시 시도해주세요');
  return data;
}

export async function joinMatchRoom(code: string): Promise<void> {
  const { error } = await supabase.rpc('join_match_room', { p_code: code });
  if (error) throw toError(error, '방에 들어가지 못했어요. 잠시 후 다시 시도해주세요');
}

/** 내가 가장 최근에 들어간 방 번호. 없으면 null */
export async function getMyMatchRoom(): Promise<string | null> {
  const { data, error } = await supabase.rpc('get_my_match_room');
  if (error) throw toError(error, '방 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  return data || null;
}

export async function getMatchQuestions(code: string): Promise<MatchQuestion[]> {
  const { data, error } = await supabase.rpc('get_match_questions', { p_code: code });
  if (error) throw toError(error, '문항을 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  return (data ?? []).map((row) => ({
    questionId: row.question_id,
    body: row.body,
    optionA: row.option_a,
    optionB: row.option_b,
    myChoice: row.my_choice === 1 || row.my_choice === 2 ? row.my_choice : null,
  }));
}

export async function getMatchFoods(code: string): Promise<MatchFood[]> {
  const { data, error } = await supabase.rpc('get_match_foods', { p_code: code });
  if (error) throw toError(error, '음식 목록을 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  // 생성된 타입은 nullable 을 표현하지 못해 number/boolean 으로 나오지만, 답하기 전에는 null 이 온다
  return (data ?? []).map((row) => ({
    foodId: row.food_id,
    name: row.name,
    myEaten: (row.my_eaten as boolean | null) ?? null,
    myRating: (row.my_rating as number | null) ?? null,
    myWantTry: (row.my_want_try as boolean | null) ?? null,
  }));
}

export async function saveMatchTest(code: string, choices: MatchChoiceAnswer[], foods: MatchFoodAnswer[]): Promise<void> {
  const { error } = await supabase.rpc('save_match_test', {
    p_code: code,
    p_choices: choices.map((c) => ({ question_id: c.questionId, choice: c.choice })),
    p_foods: foods.map((f) => (f.eaten ? { food_id: f.foodId, eaten: true, rating: f.rating } : { food_id: f.foodId, eaten: false, want_try: f.wantTry })),
  });
  if (error) throw toError(error, '검사 결과를 저장하지 못했어요. 잠시 후 다시 시도해주세요');
}

export async function getMatchRoom(code: string): Promise<MatchMember[]> {
  const { data, error } = await supabase.rpc('get_match_room', { p_code: code });
  if (error) throw toError(error, '방 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  return (data ?? []).map((row) => ({
    memberNo: row.member_no,
    nickname: row.nickname,
    isMe: row.is_me,
    completed: row.completed,
    score: (row.score as number | null) ?? null,
  }));
}

export async function getMatchCompare(code: string, memberNo: number): Promise<MatchFoodCompare[]> {
  const { data, error } = await supabase.rpc('get_match_compare', { p_code: code, p_member_no: memberNo });
  if (error) throw toError(error, '결과를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  return (data ?? []).map((row) => ({
    foodName: row.food_name,
    myEaten: row.my_eaten,
    myRating: (row.my_rating as number | null) ?? null,
    myWantTry: (row.my_want_try as boolean | null) ?? null,
    friendEaten: row.friend_eaten,
    friendRating: (row.friend_rating as number | null) ?? null,
    friendWantTry: (row.friend_want_try as boolean | null) ?? null,
  }));
}

export async function getMatchRanking(limit = 10): Promise<MatchRankingRow[]> {
  const { data, error } = await supabase.rpc('get_match_ranking', { p_limit: limit });
  if (error) throw toError(error, '랭킹을 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  return (data ?? []).map((row) => ({ rank: row.rank, nicknameA: row.nickname_a, nicknameB: row.nickname_b, score: row.score }));
}
