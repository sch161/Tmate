// 친구랑 궁합 검사 RPC 호출. 테이블은 클라이언트에 열려 있지 않아 모두 RPC 로만 읽고 쓴다.
import { supabase } from '../lib/supabase';
import type { MatchPairChoice } from '../utils/match-results';

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

/** 방 안에서 둘 다 검사를 마친 두 사람 (영수증 인쇄용). memberNoA < memberNoB */
export interface MatchRoomPair {
  memberNoA: number;
  memberNoB: number;
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

/** 영수증 인쇄(진행자용): 방 번호로 그 방에서 둘 다 검사를 마친 두 사람 조합과 궁합을 본다. 방 멤버가 아니어도 된다. */
export async function getMatchRoomPairs(code: string): Promise<MatchRoomPair[]> {
  const { data, error } = await supabase.rpc('get_match_room_pairs', { p_code: code });
  if (error) throw toError(error, '방 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  return (data ?? []).map((row) => ({ memberNoA: row.member_no_a, memberNoB: row.member_no_b, nicknameA: row.nickname_a, nicknameB: row.nickname_b, score: row.score }));
}

/** 영수증 인쇄(진행자용): 두 사람(member_no)의 음식별 답. buildResultCards 에 그대로 넣을 수 있게 A 를 my, B 를 friend 자리에 담는다. */
export async function getMatchPairFoods(code: string, memberNoA: number, memberNoB: number): Promise<MatchFoodCompare[]> {
  const { data, error } = await supabase.rpc('get_match_pair_foods', { p_code: code, p_member_no_a: memberNoA, p_member_no_b: memberNoB });
  if (error) throw toError(error, '음식 결과를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  // 생성된 타입은 nullable 을 표현하지 못해 number/boolean 으로 나오지만, 해당하지 않는 칸에는 null 이 온다
  return (data ?? []).map((row) => ({
    foodName: row.food_name,
    myEaten: row.a_eaten,
    myRating: (row.a_rating as number | null) ?? null,
    myWantTry: (row.a_want_try as boolean | null) ?? null,
    friendEaten: row.b_eaten,
    friendRating: (row.b_rating as number | null) ?? null,
    friendWantTry: (row.b_want_try as boolean | null) ?? null,
  }));
}

/** 손님: 결과 화면에서 찍은 사진(JPEG data URL)과 함께 영수증 인쇄를 요청한다. 그 방에서 검사를 마친 두 사람만 할 수 있다. showOnRank 는 랭킹 화면에 사진을 띄워도 된다는 동의다. */
export async function requestMatchPrint(code: string, photo: string, showOnRank: boolean): Promise<void> {
  const { error } = await supabase.rpc('request_match_print', { p_code: code, p_photo: photo, p_show_on_rank: showOnRank });
  if (error) throw toError(error, '사진을 올리지 못했어요. 잠시 후 다시 시도해주세요');
}

/** 인쇄 대기 1건 (진행자용). 사진은 getMatchPrintPhoto 로 따로 받는다 */
export interface MatchPrintRequest {
  requestId: number;
  code: string;
  pair: MatchRoomPair;
  requestedAt: string;
  printed: boolean;
}

/** 진행자: 인쇄 대기 목록. 아직 안 뽑은 것이 먼저 온다. 진행자 번호가 틀리면 오류 */
export async function getMatchPrintQueue(passcode: string): Promise<MatchPrintRequest[]> {
  const { data, error } = await supabase.rpc('get_match_print_queue', { p_passcode: passcode });
  if (error) throw toError(error, '대기 목록을 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  return (data ?? []).map((row) => ({
    requestId: row.request_id,
    code: row.code,
    pair: { memberNoA: row.member_no_a, memberNoB: row.member_no_b, nicknameA: row.nickname_a, nicknameB: row.nickname_b, score: row.score },
    requestedAt: row.requested_at,
    // 생성된 타입은 nullable 을 표현하지 못한다. 아직 안 뽑았으면 null 이 온다
    printed: (row.printed_at as string | null) !== null,
  }));
}

/** 진행자: 요청 1건의 사진(JPEG data URL). 없으면 null */
export async function getMatchPrintPhoto(passcode: string, requestId: number): Promise<string | null> {
  const { data, error } = await supabase.rpc('get_match_print_photo', { p_passcode: passcode, p_request_id: requestId });
  if (error) throw toError(error, '사진을 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  return typeof data === 'string' && data !== '' ? data : null;
}

/** 진행자: 인쇄를 마친 요청으로 표시한다 */
export async function markMatchPrinted(passcode: string, requestId: number): Promise<void> {
  const { error } = await supabase.rpc('mark_match_printed', { p_passcode: passcode, p_request_id: requestId });
  if (error) throw toError(error, '인쇄 완료로 표시하지 못했어요');
}

/** 두 사람(member_no)의 PART 1 문항별 답. 결과 화면과 영수증의 "통한 취향 / 갈린 취향"에 쓴다. 둘 다 검사를 마쳐야 한다. */
export async function getMatchPairChoices(code: string, memberNoA: number, memberNoB: number): Promise<MatchPairChoice[]> {
  const { data, error } = await supabase.rpc('get_match_pair_choices', { p_code: code, p_member_no_a: memberNoA, p_member_no_b: memberNoB });
  if (error) throw toError(error, '문항 결과를 불러오지 못했어요. 잠시 후 다시 시도해주세요');
  return (data ?? []).map((row) => ({ optionA: row.option_a, optionB: row.option_b, aChoice: row.a_choice, bChoice: row.b_choice }));
}

/** 랭킹 화면에 띄울 사진 (손님이 동의한 것만) */
export interface MatchRankPhoto {
  requestId: number;
  nicknameA: string;
  nicknameB: string;
  score: number;
  /** JPEG data URL */
  photo: string;
}

/** 랭킹 화면: 손님이 띄워도 된다고 한 사진을 최근 것부터 */
export async function getMatchRankPhotos(limit = 6): Promise<MatchRankPhoto[]> {
  const { data, error } = await supabase.rpc('get_match_rank_photos', { p_limit: limit });
  if (error) throw toError(error, '사진을 불러오지 못했어요');
  // DB 가 JPEG data URL 만 받지만, 화면에 그대로 넣는 값이라 한 번 더 확인한다
  return (data ?? []).filter((row) => row.photo.startsWith('data:image/jpeg;base64,')).map((row) => ({ requestId: row.request_id, nicknameA: row.nickname_a, nicknameB: row.nickname_b, score: row.score, photo: row.photo }));
}

/** 다른 폰으로 사진 보내기: 그 방의 사진을 올릴 수 있는 표(token)를 만든다. 30분 동안 쓸 수 있다 */
export async function createMatchPhotoToken(code: string): Promise<string> {
  const { data, error } = await supabase.rpc('create_match_photo_token', { p_code: code });
  if (error || !data) throw toError(error, 'QR 코드를 만들지 못했어요. 잠시 후 다시 시도해주세요');
  return data;
}

/** 표(token)가 가리키는 두 사람의 닉네임과 궁합 (사진 보내는 화면용. 로그인 없이 부른다) */
export async function getMatchPhotoTokenInfo(token: string): Promise<{ nicknameA: string; nicknameB: string; score: number } | null> {
  const { data, error } = await supabase.rpc('get_match_photo_token_info', { p_token: token });
  if (error) throw toError(error, 'QR 코드를 확인하지 못했어요. 다시 찍어주세요');
  const row = data?.[0];
  return row ? { nicknameA: row.nickname_a, nicknameB: row.nickname_b, score: row.score } : null;
}

/** 표(token)로 사진을 올린다 (로그인 없이 부른다) */
export async function uploadMatchPhotoByToken(token: string, photo: string, showOnRank: boolean): Promise<void> {
  const { error } = await supabase.rpc('upload_match_photo_by_token', { p_token: token, p_photo: photo, p_show_on_rank: showOnRank });
  if (error) throw toError(error, '사진을 올리지 못했어요. 잠시 후 다시 시도해주세요');
}
