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
      menu_allergens: {
        Row: {
          allergen_id: number
          level: Database["public"]["Enums"]["allergen_level"]
          menu_id: number
        }
        Insert: {
          allergen_id: number
          level?: Database["public"]["Enums"]["allergen_level"]
          menu_id: number
        }
        Update: {
          allergen_id?: number
          level?: Database["public"]["Enums"]["allergen_level"]
          menu_id?: number
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
          description: string | null
          id: number
          image_url: string | null
          name: string
          restaurant_id: number
        }
        Insert: {
          description?: string | null
          id?: never
          image_url?: string | null
          name: string
          restaurant_id: number
        }
        Update: {
          description?: string | null
          id?: never
          image_url?: string | null
          name?: string
          restaurant_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "menus_restaurant_id_fkey"
            columns: ["restaurant_id"]
            isOneToOne: false
            referencedRelation: "restaurants"
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
          category_id: number | null
          created_at: string
          id: number
          image_url: string | null
          name: string
          phone: string | null
          region: string
        }
        Insert: {
          address: string
          category_id?: number | null
          created_at?: string
          id?: never
          image_url?: string | null
          name: string
          phone?: string | null
          region: string
        }
        Update: {
          address?: string
          category_id?: number | null
          created_at?: string
          id?: never
          image_url?: string | null
          name?: string
          phone?: string | null
          region?: string
        }
        Relationships: [
          {
            foreignKeyName: "restaurants_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "food_categories"
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
        Relationships: [
          {
            foreignKeyName: "menus_restaurant_id_fkey"
            columns: ["restaurant_id"]
            isOneToOne: false
            referencedRelation: "restaurants"
            referencedColumns: ["id"]
          },
        ]
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
          {
            foreignKeyName: "menus_restaurant_id_fkey"
            columns: ["restaurant_id"]
            isOneToOne: false
            referencedRelation: "restaurants"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      allergen_level: "danger" | "caution"
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
    },
  },
} as const
