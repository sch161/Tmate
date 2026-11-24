export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      allergens: {
        Row: {
          aliases: string[]
          display_name: string
          id: number
          name: string
        }
        Insert: {
          aliases?: string[]
          display_name: string
          id?: never
          name: string
        }
        Update: {
          aliases?: string[]
          display_name?: string
          id?: never
          name?: string
        }
        Relationships: []
      }
      brands: {
        Row: {
          allergen_data_date: string | null
          allergen_source_url: string | null
          category_id: number | null
          created_at: string
          id: number
          image_url: string | null
          is_franchise: boolean
          name: string
          official_domains: string[]
          research_error: string | null
          research_status: string
          researched_at: string | null
          shared_notice: string | null
        }
        Insert: {
          allergen_data_date?: string | null
          allergen_source_url?: string | null
          category_id?: number | null
          created_at?: string
          id?: never
          image_url?: string | null
          is_franchise?: boolean
          name: string
          official_domains?: string[]
          research_error?: string | null
          research_status?: string
          researched_at?: string | null
          shared_notice?: string | null
        }
        Update: {
          allergen_data_date?: string | null
          allergen_source_url?: string | null
          category_id?: number | null
          created_at?: string
          id?: never
          image_url?: string | null
          is_franchise?: boolean
          name?: string
          official_domains?: string[]
          research_error?: string | null
          research_status?: string
          researched_at?: string | null
          shared_notice?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "brands_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "food_categories"
            referencedColumns: ["id"]
          },
        ]
      }
      food_categories: {
        Row: {
          id: number
          name: string
        }
        Insert: {
          id?: never
          name: string
        }
        Update: {
          id?: never
          name?: string
        }
        Relationships: []
      }
      match_answers: {
        Row: {
          choice: number
          question_id: number
          room_id: number
          user_id: string
        }
        Insert: {
          choice: number
          question_id: number
          room_id: number
          user_id: string
        }
        Update: {
          choice?: number
          question_id?: number
          room_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "match_answers_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "match_questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "match_answers_room_id_user_id_fkey"
            columns: ["room_id", "user_id"]
            isOneToOne: false
            referencedRelation: "match_room_members"
            referencedColumns: ["room_id", "user_id"]
          },
        ]
      }
      match_food_answers: {
        Row: {
          eaten: boolean
          food_id: number
          rating: number | null
          room_id: number
          user_id: string
          want_try: boolean | null
        }
        Insert: {
          eaten: boolean
          food_id: number
          rating?: number | null
          room_id: number
          user_id: string
          want_try?: boolean | null
        }
        Update: {
          eaten?: boolean
          food_id?: number
          rating?: number | null
          room_id?: number
          user_id?: string
          want_try?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "match_food_answers_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "match_foods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "match_food_answers_room_id_user_id_fkey"
            columns: ["room_id", "user_id"]
            isOneToOne: false
            referencedRelation: "match_room_members"
            referencedColumns: ["room_id", "user_id"]
          },
        ]
      }
      match_foods: {
        Row: {
          id: number
          is_active: boolean
          name: string
        }
        Insert: {
          id?: never
          is_active?: boolean
          name: string
        }
        Update: {
          id?: never
          is_active?: boolean
          name?: string
        }
        Relationships: []
      }
      match_questions: {
        Row: {
          body: string
          id: number
          is_active: boolean
          option_a: string
          option_b: string
          sort_order: number
        }
        Insert: {
          body: string
          id?: never
          is_active?: boolean
          option_a: string
          option_b: string
          sort_order: number
        }
        Update: {
          body?: string
          id?: never
          is_active?: boolean
          option_a?: string
          option_b?: string
          sort_order?: number
        }
        Relationships: []
      }
      match_room_foods: {
        Row: {
          food_id: number
          room_id: number
          sort_order: number
        }
        Insert: {
          food_id: number
          room_id: number
          sort_order: number
        }
        Update: {
          food_id?: number
          room_id?: number
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "match_room_foods_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "match_foods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "match_room_foods_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "match_rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      match_room_members: {
        Row: {
          completed_at: string | null
          joined_at: string
          member_no: number
          room_id: number
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          joined_at?: string
          member_no: number
          room_id: number
          user_id: string
        }
        Update: {
          completed_at?: string | null
          joined_at?: string
          member_no?: number
          room_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "match_room_members_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "match_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "match_room_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      match_rooms: {
        Row: {
          code: string
          created_at: string
          created_by: string
          id: number
        }
        Insert: {
          code: string
          created_at?: string
          created_by: string
          id?: never
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string
          id?: never
        }
        Relationships: [
          {
            foreignKeyName: "match_rooms_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      menu_allergens: {
        Row: {
          allergen_id: number
          level: Database["public"]["Enums"]["allergen_level"]
          menu_id: number
          original_text: string | null
        }
        Insert: {
          allergen_id: number
          level?: Database["public"]["Enums"]["allergen_level"]
          menu_id: number
          original_text?: string | null
        }
        Update: {
          allergen_id?: number
          level?: Database["public"]["Enums"]["allergen_level"]
          menu_id?: number
          original_text?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "menu_allergens_allergen_id_fkey"
            columns: ["allergen_id"]
            isOneToOne: false
            referencedRelation: "allergens"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "menu_allergens_menu_id_fkey"
            columns: ["menu_id"]
            isOneToOne: false
            referencedRelation: "menus"
            referencedColumns: ["id"]
          },
        ]
      }
      menu_taste_tags: {
        Row: {
          menu_id: number
          taste_tag_id: number
        }
        Insert: {
          menu_id: number
          taste_tag_id: number
        }
        Update: {
          menu_id?: number
          taste_tag_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "menu_taste_tags_menu_id_fkey"
            columns: ["menu_id"]
            isOneToOne: false
            referencedRelation: "menus"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "menu_taste_tags_taste_tag_id_fkey"
            columns: ["taste_tag_id"]
            isOneToOne: false
            referencedRelation: "taste_tags"
            referencedColumns: ["id"]
          },
        ]
      }
      menus: {
        Row: {
          allergen_checked_at: string | null
          allergen_note: string | null
          allergen_source_url: string | null
          allergen_status: Database["public"]["Enums"]["allergen_status"]
          brand_id: number
          description: string | null
          id: number
          image_url: string | null
          menu_source_name: string | null
          menu_source_url: string | null
          name: string
        }
        Insert: {
          allergen_checked_at?: string | null
          allergen_note?: string | null
          allergen_source_url?: string | null
          allergen_status?: Database["public"]["Enums"]["allergen_status"]
          brand_id: number
          description?: string | null
          id?: never
          image_url?: string | null
          menu_source_name?: string | null
          menu_source_url?: string | null
          name: string
        }
        Update: {
          allergen_checked_at?: string | null
          allergen_note?: string | null
          allergen_source_url?: string | null
          allergen_status?: Database["public"]["Enums"]["allergen_status"]
          brand_id?: number
          description?: string | null
          id?: never
          image_url?: string | null
          menu_source_name?: string | null
          menu_source_url?: string | null
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "menus_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          id: string
          nickname: string
          onboarding_done: boolean
          region: string | null
          username: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          id: string
          nickname: string
          onboarding_done?: boolean
          region?: string | null
          username: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          id?: string
          nickname?: string
          onboarding_done?: boolean
          region?: string | null
          username?: string
        }
        Relationships: []
      }
      restaurants: {
        Row: {
          address: string
          brand_id: number
          created_at: string
          external_id: string | null
          id: number
          image_url: string | null
          name: string
          phone: string | null
          region: string
          sido: string | null
          sigungu: string | null
        }
        Insert: {
          address: string
          brand_id: number
          created_at?: string
          external_id?: string | null
          id?: never
          image_url?: string | null
          name: string
          phone?: string | null
          region: string
          sido?: string | null
          sigungu?: string | null
        }
        Update: {
          address?: string
          brand_id?: number
          created_at?: string
          external_id?: string | null
          id?: never
          image_url?: string | null
          name?: string
          phone?: string | null
          region?: string
          sido?: string | null
          sigungu?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "restaurants_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
        ]
      }
      review_taste_tags: {
        Row: {
          review_id: number
          taste_tag_id: number
        }
        Insert: {
          review_id: number
          taste_tag_id: number
        }
        Update: {
          review_id?: number
          taste_tag_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "review_taste_tags_review_id_fkey"
            columns: ["review_id"]
            isOneToOne: false
            referencedRelation: "reviews"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "review_taste_tags_taste_tag_id_fkey"
            columns: ["taste_tag_id"]
            isOneToOne: false
            referencedRelation: "taste_tags"
            referencedColumns: ["id"]
          },
        ]
      }
      reviews: {
        Row: {
          created_at: string
          id: number
          menu_id: number
          rating: number
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: never
          menu_id: number
          rating: number
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: never
          menu_id?: number
          rating?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reviews_menu_id_fkey"
            columns: ["menu_id"]
            isOneToOne: false
            referencedRelation: "menus"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_menus: {
        Row: {
          created_at: string
          menu_id: number
          user_id: string
        }
        Insert: {
          created_at?: string
          menu_id: number
          user_id: string
        }
        Update: {
          created_at?: string
          menu_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "saved_menus_menu_id_fkey"
            columns: ["menu_id"]
            isOneToOne: false
            referencedRelation: "menus"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "saved_menus_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_restaurants: {
        Row: {
          created_at: string
          restaurant_id: number
          user_id: string
        }
        Insert: {
          created_at?: string
          restaurant_id: number
          user_id: string
        }
        Update: {
          created_at?: string
          restaurant_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "saved_restaurants_restaurant_id_fkey"
            columns: ["restaurant_id"]
            isOneToOne: false
            referencedRelation: "restaurant_stats"
            referencedColumns: ["restaurant_id"]
          },
          {
            foreignKeyName: "saved_restaurants_restaurant_id_fkey"
            columns: ["restaurant_id"]
            isOneToOne: false
            referencedRelation: "restaurant_taste_tags"
            referencedColumns: ["restaurant_id"]
          },
          {
            foreignKeyName: "saved_restaurants_restaurant_id_fkey"
            columns: ["restaurant_id"]
            isOneToOne: false
            referencedRelation: "restaurants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "saved_restaurants_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      taste_tags: {
        Row: {
          code: string
          id: number
          name: string
        }
        Insert: {
          code: string
          id?: never
          name: string
        }
        Update: {
          code?: string
          id?: never
          name?: string
        }
        Relationships: []
      }
      user_allergens: {
        Row: {
          allergen_id: number
          user_id: string
        }
        Insert: {
          allergen_id: number
          user_id: string
        }
        Update: {
          allergen_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_allergens_allergen_id_fkey"
            columns: ["allergen_id"]
            isOneToOne: false
            referencedRelation: "allergens"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_allergens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_taste_preferences: {
        Row: {
          ratio: number
          taste_tag_id: number
          user_id: string
        }
        Insert: {
          ratio: number
          taste_tag_id: number
          user_id: string
        }
        Update: {
          ratio?: number
          taste_tag_id?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_taste_preferences_taste_tag_id_fkey"
            columns: ["taste_tag_id"]
            isOneToOne: false
            referencedRelation: "taste_tags"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_taste_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      brand_stats: {
        Row: {
          avg_rating: number | null
          brand_id: number | null
          review_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "menus_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
        ]
      }
      menu_stats: {
        Row: {
          avg_rating: number | null
          menu_id: number | null
          review_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "reviews_menu_id_fkey"
            columns: ["menu_id"]
            isOneToOne: false
            referencedRelation: "menus"
            referencedColumns: ["id"]
          },
        ]
      }
      restaurant_stats: {
        Row: {
          avg_rating: number | null
          restaurant_id: number | null
          review_count: number | null
        }
        Relationships: []
      }
      restaurant_taste_tags: {
        Row: {
          restaurant_id: number | null
          taste_tag_id: number | null
        }
        Relationships: [
          {
            foreignKeyName: "menu_taste_tags_taste_tag_id_fkey"
            columns: ["taste_tag_id"]
            isOneToOne: false
            referencedRelation: "taste_tags"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      calc_content_match: {
        Args: { p_menu: number; p_user: string }
        Returns: number
      }
      calc_match_room_id: { Args: { p_code: string }; Returns: number }
      calc_match_score: {
        Args: { p_a: string; p_b: string; p_room: number }
        Returns: number
      }
      calc_menu_match: {
        Args: { p_menu: number; p_user: string }
        Returns: number
      }
      calc_menu_match_detail: {
        Args: { p_menu: number; p_user: string }
        Returns: {
          match: number
          neighbor_avg: number
          neighbor_count: number
        }[]
      }
      calc_menu_reason: {
        Args: { p_menu: number; p_user: string }
        Returns: string
      }
      calc_setting: { Args: { p_key: string }; Returns: number }
      calc_taste_type: {
        Args: { p_user: string }
        Returns: {
          type_desc: string
          type_name: string
        }[]
      }
      calc_user_similarity: {
        Args: { p_a: string; p_b: string }
        Returns: number
      }
      create_match_room: { Args: never; Returns: string }
      delete_review: { Args: { p_menu_id: number }; Returns: undefined }
      get_allergy_menus: {
        Args: { p_restaurant_id: number }
        Returns: {
          allergen_status: Database["public"]["Enums"]["allergen_status"]
          allergens: Json
          image_url: string
          kind: string
          menu_id: number
          name: string
        }[]
      }
      get_match_compare: {
        Args: { p_code: string; p_member_no: number }
        Returns: {
          food_name: string
          friend_eaten: boolean
          friend_rating: number
          friend_want_try: boolean
          my_eaten: boolean
          my_rating: number
          my_want_try: boolean
        }[]
      }
      get_match_foods: {
        Args: { p_code: string }
        Returns: {
          food_id: number
          my_eaten: boolean
          my_rating: number
          my_want_try: boolean
          name: string
        }[]
      }
      get_match_pair_foods: {
        Args: { p_code: string; p_member_no_a: number; p_member_no_b: number }
        Returns: {
          a_eaten: boolean
          a_rating: number
          a_want_try: boolean
          b_eaten: boolean
          b_rating: number
          b_want_try: boolean
          food_name: string
        }[]
      }
      get_match_questions: {
        Args: { p_code: string }
        Returns: {
          body: string
          my_choice: number
          option_a: string
          option_b: string
          question_id: number
        }[]
      }
      get_match_ranking: {
        Args: { p_hours?: number; p_limit?: number }
        Returns: {
          nickname_a: string
          nickname_b: string
          rank: number
          score: number
        }[]
      }
      get_match_room: {
        Args: { p_code: string }
        Returns: {
          completed: boolean
          is_me: boolean
          member_no: number
          nickname: string
          score: number
        }[]
      }
      get_match_room_pairs: {
        Args: { p_code: string }
        Returns: {
          member_no_a: number
          member_no_b: number
          nickname_a: string
          nickname_b: string
          score: number
        }[]
      }
      get_my_match_room: { Args: never; Returns: string }
      get_my_reviews: {
        Args: never
        Returns: {
          brand_id: number
          brand_name: string
          category_name: string
          created_at: string
          image_url: string
          menu_id: number
          menu_name: string
          rating: number
          restaurant_id: number
          restaurant_name: string
          taste_tags: string[]
        }[]
      }
      get_my_summary: {
        Args: never
        Returns: {
          mate_count: number
          nickname: string
          region: string
          review_count: number
          saved_restaurant_count: number
          taste_ratios: Json
          taste_type_desc: string
          taste_type_name: string
        }[]
      }
      get_recommended_menus: {
        Args: { p_limit?: number; p_region: string }
        Returns: {
          allergen_status: Database["public"]["Enums"]["allergen_status"]
          avg_rating: number
          brand_name: string
          category_name: string
          image_url: string
          match_percent: number
          menu_id: number
          menu_name: string
          reason: string
          region: string
          restaurant_id: number
          restaurant_name: string
        }[]
      }
      get_regions: {
        Args: never
        Returns: {
          region: string
          restaurant_count: number
          sido: string
          sigungu: string
        }[]
      }
      get_restaurant_detail: {
        Args: { p_restaurant_id: number }
        Returns: {
          address: string
          allergen_data_date: string
          allergen_source_url: string
          avg_rating: number
          brand_id: number
          brand_name: string
          category_name: string
          image_url: string
          is_franchise: boolean
          is_saved: boolean
          match_percent: number
          name: string
          phone: string
          reason: string
          region: string
          restaurant_id: number
          review_count: number
          shared_notice: string
        }[]
      }
      get_restaurant_menus: {
        Args: { p_restaurant_id: number }
        Returns: {
          allergen_checked_at: string
          allergen_source_url: string
          allergen_status: Database["public"]["Enums"]["allergen_status"]
          avg_rating: number
          description: string
          image_url: string
          is_saved: boolean
          match_percent: number
          menu_id: number
          menu_source_name: string
          menu_source_url: string
          my_rating: number
          name: string
          taste_tags: string[]
        }[]
      }
      get_restaurants: {
        Args: {
          p_category_id?: number
          p_limit?: number
          p_query?: string
          p_region: string
        }
        Returns: {
          avg_rating: number
          brand_id: number
          brand_name: string
          category_name: string
          has_official_allergen: boolean
          image_url: string
          is_franchise: boolean
          is_saved: boolean
          match_percent: number
          name: string
          region: string
          restaurant_id: number
          review_count: number
          taste_tags: string[]
        }[]
      }
      get_taste_mates: {
        Args: { p_limit?: number }
        Returns: {
          common_menu_count: number
          nickname: string
          similarity_percent: number
          taste_type_name: string
        }[]
      }
      has_batchim: { Args: { p_text: string }; Returns: boolean }
      join_match_room: { Args: { p_code: string }; Returns: undefined }
      josa: { Args: { p_pair: string; p_text: string }; Returns: string }
      save_match_test: {
        Args: { p_choices: Json; p_code: string; p_foods: Json }
        Returns: undefined
      }
      save_onboarding: {
        Args: { p_allergens: number[]; p_region: string; p_tastes: Json }
        Returns: undefined
      }
      taste_short_name: {
        Args: { p_code: string; p_name: string }
        Returns: string
      }
      update_my_allergens: {
        Args: { p_allergen_ids: number[] }
        Returns: undefined
      }
      update_my_tastes: {
        Args: { p_ratios: number[]; p_taste_ids: number[] }
        Returns: undefined
      }
      upsert_review: {
        Args: { p_menu_id: number; p_rating: number; p_tag_ids: number[] }
        Returns: number
      }
    }
    Enums: {
      allergen_level: "danger" | "caution"
      allergen_status: "verified" | "official_extract" | "estimated" | "unknown"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      allergen_level: ["danger", "caution"],
      allergen_status: ["verified", "official_extract", "estimated", "unknown"],
    },
  },
} as const
