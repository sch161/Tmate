// 프로젝트 전체에서 Supabase 클라이언트는 이 파일 하나만 사용한다.
// 화면 코드에서 직접 import 하지 말고 src/api/ 의 함수를 통해 호출한다.
import { createClient } from '@supabase/supabase-js';
import type { Database } from '../types/database.types';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

// 배포 환경에 환경변수가 빠지면 원인이 분명한 에러를 낸다 (그대로 두면 "supabaseUrl is required" 만 보인다)
if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Supabase 환경변수가 설정되지 않았어요. VITE_SUPABASE_URL 과 VITE_SUPABASE_ANON_KEY 를 확인하세요 (로컬은 .env, 배포는 호스팅 환경변수).');
}

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey);
