-- Clean up test and seed data that should not exist in production
-- This migration removes test profiles and ensures data isolation

-- Delete test child profiles with the test parent UUID
DELETE FROM child_profiles 
WHERE parent_user_id = '00000000-0000-0000-0000-000000000000';

-- Delete test parent profile
DELETE FROM parent_profiles 
WHERE user_id = '00000000-0000-0000-0000-000000000000';

-- Delete any learning events associated with test profiles
DELETE FROM learning_events 
WHERE child_profile_id IN (
    SELECT id FROM child_profiles 
    WHERE parent_user_id = '00000000-0000-0000-0000-000000000000'
);

-- Delete any game sessions associated with test profiles  
DELETE FROM game_sessions 
WHERE child_profile_id IN (
    SELECT id FROM child_profiles 
    WHERE parent_user_id = '00000000-0000-0000-0000-000000000000'
);

-- Add constraint to prevent test UUID from being used in future
ALTER TABLE parent_profiles 
ADD CONSTRAINT no_test_uuids 
CHECK (user_id != '00000000-0000-0000-0000-000000000000');

-- Add constraint to child profiles as well
ALTER TABLE child_profiles 
ADD CONSTRAINT no_test_parent_uuids 
CHECK (parent_user_id != '00000000-0000-0000-0000-000000000000');

-- Cleanup completed - constraints added to prevent future test data

COMMENT ON CONSTRAINT no_test_uuids ON parent_profiles IS 
'Prevents test UUID from being used in production';

COMMENT ON CONSTRAINT no_test_parent_uuids ON child_profiles IS 
'Prevents test parent UUID from being used in production';