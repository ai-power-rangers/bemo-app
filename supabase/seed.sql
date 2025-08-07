-- This file contains SQL statements that will be executed after the migrations.
-- Use this to insert sample data for development and testing.
-- 
-- ⚠️  WARNING: This file should ONLY be used in development environments!
-- ⚠️  Do NOT run this in production as it creates test data with known UUIDs!

-- Only insert test data if we're in a development environment
-- Check if this is development by looking for absence of production constraints
DO $$
BEGIN
    -- Only proceed if the test constraints don't exist (meaning we're in dev)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'no_test_uuids' 
        AND table_name = 'parent_profiles'
    ) THEN
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
        
        RAISE NOTICE 'Development seed data inserted';
    ELSE
        RAISE NOTICE 'Production environment detected - skipping test data insertion';
    END IF;
END $$;

-- Insert sample learning events for testing analytics (development only)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'no_test_uuids' 
        AND table_name = 'parent_profiles'
    ) THEN
        INSERT INTO learning_events (child_profile_id, event_type, game_id, xp_awarded, event_data) 
        SELECT 
          cp.id,
          'level_completed',
          'tangram',
          50,
          '{"level": 1, "time_spent": 120, "hints_used": 0}'
        FROM child_profiles cp 
        WHERE cp.name = 'Emma' AND cp.parent_user_id = '00000000-0000-0000-0000-000000000000'
        LIMIT 1;

        INSERT INTO learning_events (child_profile_id, event_type, game_id, xp_awarded, event_data) 
        SELECT 
          cp.id,
          'game_started',
          'tangram',
          0,
          '{"difficulty": "normal"}'
        FROM child_profiles cp 
        WHERE cp.name = 'Lucas' AND cp.parent_user_id = '00000000-0000-0000-0000-000000000000'
        LIMIT 1;
    END IF;
END $$;