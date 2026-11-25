import type { Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import { GUEST_USERNAME_PREFIX, toEmail } from '../lib/constants';
import type { Tables } from '../types/database.types';

export type MyProfile = Pick<Tables<'profiles'>, 'id' | 'username' | 'nickname' | 'region' | 'onboarding_done'>;

/** Supabase 에러를 한국어 메시지로 바꾼다. */
function toKoreanError(error: { message: string; status?: number; name?: string }): Error {
  const msg = error.message.toLowerCase();
  if (msg.includes('already registered') || msg.includes('already been registered') || msg.includes('user_already_exists')) {
    return new Error('이미 사용 중인 아이디예요');
  }
  if (msg.includes('invalid login credentials')) {
    return new Error('아이디 또는 비밀번호가 올바르지 않아요');
  }
  if (msg.includes('fetch') || msg.includes('network') || error.name === 'AuthRetryableFetchError') {
    return new Error('네트워크 오류가 발생했어요. 잠시 후 다시 시도해주세요');
  }
  if (msg.includes('rate limit') || error.status === 429) {
    return new Error('요청이 너무 많아요. 잠시 후 다시 시도해주세요');
  }
  if (msg.includes('password')) {
    return new Error('비밀번호가 너무 짧거나 사용할 수 없어요');
  }
  return new Error('문제가 발생했어요. 잠시 후 다시 시도해주세요');
}

/** 이미 한국어로 바뀐 에러는 그대로 두고, 그 외 예외(fetch 실패 등)는 한국어 에러로 맞춘다. */
function normalize(e: unknown): Error {
  if (e instanceof Error && /[가-힣]/.test(e.message)) return e;
  return toKoreanError({
    message: e instanceof Error ? e.message : String(e),
    name: e instanceof Error ? e.name : undefined,
  });
}

export async function signUp(username: string, password: string): Promise<Session> {
  try {
    const { data, error } = await supabase.auth.signUp({ email: toEmail(username), password });
    if (error) throw toKoreanError(error);
    if (!data.session) throw new Error('가입은 되었지만 로그인하지 못했어요. 로그인 화면에서 다시 시도해주세요');
    return data.session;
  } catch (e) {
    throw normalize(e);
  }
}

function randomText(length: number): string {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes, (b) => chars[b % chars.length]).join('');
}

/**
 * 닉네임만으로 시작하기: 아이디·비밀번호를 무작위로 만들어 가입한다 (사용자는 보지 않는다).
 * 로그인 상태는 이 기기의 브라우저에만 남으므로, 로그아웃하거나 브라우저 기록을 지우면 같은 계정으로 다시 들어올 수 없다.
 */
export async function startAsGuest(): Promise<Session> {
  return signUp(`${GUEST_USERNAME_PREFIX}${randomText(14)}`, randomText(32));
}

export async function signIn(username: string, password: string): Promise<Session> {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email: toEmail(username), password });
    if (error) throw toKoreanError(error);
    return data.session;
  } catch (e) {
    throw normalize(e);
  }
}

export async function signOut(): Promise<void> {
  try {
    const { error } = await supabase.auth.signOut();
    if (error) throw toKoreanError(error);
  } catch (e) {
    throw normalize(e);
  }
}

export async function getSession(): Promise<Session | null> {
  try {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw toKoreanError(error);
    return data.session;
  } catch (e) {
    throw normalize(e);
  }
}

/** 내 profiles 한 행. 세션이 없거나 행이 없으면 null. */
export async function getMyProfile(): Promise<MyProfile | null> {
  try {
    const session = await getSession();
    if (!session) return null;
    const { data, error } = await supabase
      .from('profiles')
      .select('id, username, nickname, region, onboarding_done')
      .eq('id', session.user.id)
      .maybeSingle();
    if (error) throw new Error('프로필을 불러오지 못했어요. 잠시 후 다시 시도해주세요');
    return data;
  } catch (e) {
    throw normalize(e);
  }
}
