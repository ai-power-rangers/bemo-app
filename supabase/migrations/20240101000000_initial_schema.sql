-- Initial database schema for Bemo app
-- This migration sets up the core tables for parent profiles, child profiles, and learning analytics

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create parent_profiles table
-- Maps Supabase auth users to Apple ID users and stores parent metadata
CREATE TABLE parent_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  apple_user_id TEXT UNIQUE NOT NULL, -- Maps to Apple Sign-In user identifier
  full_name TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create child_profiles table
-- Stores individual child profiles belonging to authenticated parents
CREATE TABLE child_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  age INTEGER NOT NULL CHECK (age > 0 AND age < 18),
  gender TEXT NOT NULL,
  total_xp INTEGER DEFAULT 0 CHECK (total_xp >= 0),
  preferences JSONB DEFAULT '{"soundEnabled": true, "musicEnabled": true, "difficultySetting": "normal", "colorScheme": "default"}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure unique child names per parent
  CONSTRAINT unique_child_name_per_parent UNIQUE(parent_user_id, name)
);

-- Create learning_events table
-- Records all learning activities and achievements for analytics
CREATE TABLE learning_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'game_started', 'level_completed', 'xp_earned', 'achievement_unlocked', etc.
  game_id TEXT NOT NULL, -- References the game identifier (e.g., 'tangram')
  xp_awarded INTEGER DEFAULT 0 CHECK (xp_awarded >= 0),
  event_data JSONB DEFAULT '{}', -- Flexible storage for game-specific metrics
  session_id UUID, -- Groups events within the same gaming session
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create game_sessions table  
-- Tracks individual gaming sessions for time-based analytics
CREATE TABLE game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
  game_id TEXT NOT NULL,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  total_xp_earned INTEGER DEFAULT 0 CHECK (total_xp_earned >= 0),
  levels_completed INTEGER DEFAULT 0 CHECK (levels_completed >= 0),
  session_data JSONB DEFAULT '{}', -- Store game-specific session metadata
  
  -- Ensure session end time is after start time
  CONSTRAINT valid_session_duration CHECK (ended_at IS NULL OR ended_at >= started_at)
);

-- Create indexes for performance
CREATE INDEX idx_parent_profiles_user_id ON parent_profiles(user_id);
CREATE INDEX idx_parent_profiles_apple_user_id ON parent_profiles(apple_user_id);
CREATE INDEX idx_child_profiles_parent_user_id ON child_profiles(parent_user_id);
CREATE INDEX idx_child_profiles_name ON child_profiles(name);
CREATE INDEX idx_learning_events_child_profile_id ON learning_events(child_profile_id);
CREATE INDEX idx_learning_events_created_at ON learning_events(created_at);
CREATE INDEX idx_learning_events_event_type ON learning_events(event_type);
CREATE INDEX idx_learning_events_game_id ON learning_events(game_id);
CREATE INDEX idx_learning_events_session_id ON learning_events(session_id);
CREATE INDEX idx_game_sessions_child_profile_id ON game_sessions(child_profile_id);
CREATE INDEX idx_game_sessions_started_at ON game_sessions(started_at);
CREATE INDEX idx_game_sessions_game_id ON game_sessions(game_id);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers
CREATE TRIGGER update_parent_profiles_updated_at 
  BEFORE UPDATE ON parent_profiles 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_child_profiles_updated_at 
  BEFORE UPDATE ON child_profiles 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments for documentation
COMMENT ON TABLE parent_profiles IS 'Parent user profiles linked to Supabase auth and Apple Sign-In';
COMMENT ON TABLE child_profiles IS 'Individual child profiles belonging to authenticated parents';
COMMENT ON TABLE learning_events IS 'All learning activities and achievements for analytics tracking';
COMMENT ON TABLE game_sessions IS 'Gaming sessions for time-based analytics and progress tracking';

COMMENT ON COLUMN child_profiles.preferences IS 'JSONB field storing user preferences matching iOS UserPreferences model';
COMMENT ON COLUMN learning_events.event_data IS 'Flexible JSONB storage for game-specific metrics and context';
COMMENT ON COLUMN learning_events.session_id IS 'Groups events within the same gaming session for analytics';