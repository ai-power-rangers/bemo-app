-- Migration: Add Avatar Fields to Child Profiles
-- Description: Adds avatar_symbol and avatar_color columns to child_profiles table for personalized child avatars
-- Author: Bemo Team  
-- Date: 2025-08-11

BEGIN;

-- Add avatar columns to child_profiles table
ALTER TABLE child_profiles
ADD COLUMN IF NOT EXISTS avatar_symbol TEXT DEFAULT 'star.fill',
ADD COLUMN IF NOT EXISTS avatar_color TEXT DEFAULT 'blue';

-- Add comment to document the columns
COMMENT ON COLUMN child_profiles.avatar_symbol IS 'SF Symbol name for the child avatar (e.g., star.fill, heart.fill)';
COMMENT ON COLUMN child_profiles.avatar_color IS 'Color name for the avatar (e.g., blue, red, green)';

-- Update existing profiles with random avatars from a curated list
-- This ensures existing profiles have valid avatars
UPDATE child_profiles
SET 
  avatar_symbol = CASE RIGHT(id::text, 1)
    WHEN '0' THEN 'star.fill'
    WHEN '1' THEN 'heart.fill'
    WHEN '2' THEN 'sun.max.fill'
    WHEN '3' THEN 'moon.fill'
    WHEN '4' THEN 'cloud.fill'
    WHEN '5' THEN 'sparkles'
    WHEN '6' THEN 'hare.fill'
    WHEN '7' THEN 'tortoise.fill'
    WHEN '8' THEN 'bird.fill'
    WHEN '9' THEN 'fish.fill'
    WHEN 'a' THEN 'star.fill'
    WHEN 'b' THEN 'heart.fill'
    WHEN 'c' THEN 'sun.max.fill'
    WHEN 'd' THEN 'moon.fill'
    WHEN 'e' THEN 'cloud.fill'
    WHEN 'f' THEN 'sparkles'
    ELSE 'star.fill'
  END,
  avatar_color = CASE RIGHT(id::text, 1)
    WHEN '0' THEN 'blue'
    WHEN '1' THEN 'red'
    WHEN '2' THEN 'green'
    WHEN '3' THEN 'yellow'
    WHEN '4' THEN 'purple'
    WHEN '5' THEN 'orange'
    WHEN '6' THEN 'blue'
    WHEN '7' THEN 'red'
    WHEN '8' THEN 'green'
    WHEN '9' THEN 'yellow'
    WHEN 'a' THEN 'purple'
    WHEN 'b' THEN 'orange'
    WHEN 'c' THEN 'blue'
    WHEN 'd' THEN 'red'
    WHEN 'e' THEN 'green'
    WHEN 'f' THEN 'yellow'
    ELSE 'blue'
  END
WHERE avatar_symbol IS NULL OR avatar_color IS NULL;

-- Create indexes for potential filtering/searching by avatar
CREATE INDEX IF NOT EXISTS idx_child_profiles_avatar_symbol ON child_profiles(avatar_symbol);
CREATE INDEX IF NOT EXISTS idx_child_profiles_avatar_color ON child_profiles(avatar_color);

COMMIT;