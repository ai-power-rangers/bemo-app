-- This file contains SQL statements that will be executed after the migrations.
-- Use this to insert sample data for development and testing.

-- Insert sample parent profile for testing
-- Note: This would typically be created through the app's authentication flow
INSERT INTO parent_profiles (user_id, apple_user_id, full_name, email) 
VALUES 
  ('00000000-0000-0000-0000-000000000000', 'sample_apple_user_id', 'Test Parent', 'test@example.com')
ON CONFLICT (apple_user_id) DO NOTHING;

-- Insert sample child profiles for testing
-- Note: In production, these would be created through the ProfileService
INSERT INTO child_profiles (parent_user_id, name, age, gender, total_xp, preferences) 
VALUES 
  ('00000000-0000-0000-0000-000000000000', 'Emma', 6, 'female', 250, '{"soundEnabled": true, "musicEnabled": true, "difficultySetting": "normal"}'),
  ('00000000-0000-0000-0000-000000000000', 'Lucas', 8, 'male', 450, '{"soundEnabled": true, "musicEnabled": false, "difficultySetting": "hard"}')
ON CONFLICT (parent_user_id, name) DO NOTHING;

-- Insert sample learning events for testing analytics
INSERT INTO learning_events (child_profile_id, event_type, game_id, xp_awarded, event_data) 
SELECT 
  cp.id,
  'level_completed',
  'tangram',
  50,
  '{"level": 1, "time_spent": 120, "hints_used": 0}'
FROM child_profiles cp 
WHERE cp.name = 'Emma'
LIMIT 1;

INSERT INTO learning_events (child_profile_id, event_type, game_id, xp_awarded, event_data) 
SELECT 
  cp.id,
  'game_started',
  'tangram',
  0,
  '{"difficulty": "normal"}'
FROM child_profiles cp 
WHERE cp.name = 'Lucas'
LIMIT 1;