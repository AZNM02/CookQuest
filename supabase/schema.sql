-- CookQuest Database Schema
-- Run this in the Supabase SQL Editor (SQL → New Query)

-- ============================================================
-- TABLES
-- ============================================================

-- Profiles (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  xp INTEGER DEFAULT 0,
  level INTEGER DEFAULT 1,
  streak_count INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_cooked_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Techniques master list
CREATE TABLE IF NOT EXISTS techniques (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('knife_skills', 'heat_control', 'sauces', 'baking', 'prep')),
  difficulty_tier TEXT NOT NULL CHECK (difficulty_tier IN ('beginner', 'intermediate', 'advanced')),
  description TEXT,
  xp_reward INTEGER NOT NULL DEFAULT 10
);

-- Cooking sessions
CREATE TABLE IF NOT EXISTS cooking_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  dish_name TEXT NOT NULL,
  cuisine_type TEXT NOT NULL CHECK (cuisine_type IN ('asian', 'western', 'mediterranean', 'middle_eastern', 'other')),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  self_rating INTEGER CHECK (self_rating BETWEEN 1 AND 5),
  difficulty_felt INTEGER CHECK (difficulty_felt BETWEEN 1 AND 5),
  time_taken_mins INTEGER,
  notes TEXT,
  photo_url TEXT,
  xp_earned INTEGER DEFAULT 0,
  ai_feedback TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Junction: techniques used per session
CREATE TABLE IF NOT EXISTS session_techniques (
  session_id UUID REFERENCES cooking_sessions(id) ON DELETE CASCADE,
  technique_id INTEGER REFERENCES techniques(id),
  PRIMARY KEY (session_id, technique_id)
);

-- User technique proficiency
CREATE TABLE IF NOT EXISTS user_technique_proficiency (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  technique_id INTEGER REFERENCES techniques(id),
  times_used INTEGER DEFAULT 0,
  avg_rating FLOAT DEFAULT 0,
  last_used DATE,
  proficiency_score FLOAT DEFAULT 0,
  PRIMARY KEY (user_id, technique_id)
);

-- Badges master list
CREATE TABLE IF NOT EXISTS badges (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL,
  unlock_condition_type TEXT NOT NULL CHECK (
    unlock_condition_type IN ('session_count', 'streak', 'technique_count', 'cuisine_count', 'xp', 'specific_technique')
  ),
  unlock_condition_value INTEGER,
  unlock_condition_extra TEXT
);

-- User earned badges
CREATE TABLE IF NOT EXISTS user_badges (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  badge_id INTEGER REFERENCES badges(id),
  earned_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, badge_id)
);

-- Recipes
CREATE TABLE IF NOT EXISTS recipes (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  cuisine_type TEXT NOT NULL,
  difficulty TEXT NOT NULL CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  estimated_time_mins INTEGER,
  description TEXT,
  instructions TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Junction: techniques required per recipe
CREATE TABLE IF NOT EXISTS recipe_techniques (
  recipe_id INTEGER REFERENCES recipes(id),
  technique_id INTEGER REFERENCES techniques(id),
  PRIMARY KEY (recipe_id, technique_id)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE cooking_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_techniques ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_technique_proficiency ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

-- Profiles: users can only read/update their own profile
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Cooking sessions: users can only access their own sessions
CREATE POLICY "sessions_select_own" ON cooking_sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "sessions_insert_own" ON cooking_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "sessions_update_own" ON cooking_sessions
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "sessions_delete_own" ON cooking_sessions
  FOR DELETE USING (auth.uid() = user_id);

-- Session techniques: accessible if the user owns the session
CREATE POLICY "session_techniques_select_own" ON session_techniques
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM cooking_sessions
      WHERE cooking_sessions.id = session_techniques.session_id
        AND cooking_sessions.user_id = auth.uid()
    )
  );

CREATE POLICY "session_techniques_insert_own" ON session_techniques
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM cooking_sessions
      WHERE cooking_sessions.id = session_techniques.session_id
        AND cooking_sessions.user_id = auth.uid()
    )
  );

CREATE POLICY "session_techniques_delete_own" ON session_techniques
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM cooking_sessions
      WHERE cooking_sessions.id = session_techniques.session_id
        AND cooking_sessions.user_id = auth.uid()
    )
  );

-- User technique proficiency: own rows only
CREATE POLICY "proficiency_select_own" ON user_technique_proficiency
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "proficiency_insert_own" ON user_technique_proficiency
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "proficiency_update_own" ON user_technique_proficiency
  FOR UPDATE USING (auth.uid() = user_id);

-- User badges: own rows only
CREATE POLICY "badges_select_own" ON user_badges
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "badges_insert_own" ON user_badges
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Public read for reference tables (techniques, badges, recipes, recipe_techniques)
-- No RLS needed; these are read-only catalog tables managed by the backend service role

-- ============================================================
-- TRIGGER: auto-create profile on user signup
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
