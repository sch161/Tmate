// 프로젝트 전체에서 Supabase 클라이언트는 이 파일 하나만 사용한다.
// 화면 코드에서 직접 import 하지 말고 src/api/ 의 함수를 통해 호출한다.
import { createClient } from '@supabase/supabase-js';
import type { Database } from '../types/database.types';

export const supabase = createClient<Database>(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY,
);
