// ⚠️ 자동 생성 파일입니다. 직접 수정하지 마세요.
// DB 구조가 바뀌면 `npm run gen:types` 로 갱신합니다. (README 참고)
// 아래는 gen:types 를 처음 실행하기 전까지 빌드가 깨지지 않도록 둔 임시 타입입니다.

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export interface Database {
  public: {
    Tables: { [_ in never]: never };
    Views: { [_ in never]: never };
    Functions: { [_ in never]: never };
    Enums: { [_ in never]: never };
    CompositeTypes: { [_ in never]: never };
  };
}
