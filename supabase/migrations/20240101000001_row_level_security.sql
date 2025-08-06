-- Row Level Security (RLS) policies for Bemo app
-- Ensures parents can only access their own data and their children's data

-- Enable Row Level Security on all tables
ALTER TABLE parent_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE child_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_sessions ENABLE ROW LEVEL SECURITY;

-- =============================================
-- PARENT PROFILES RLS POLICIES
-- =============================================

-- Allow authenticated users to view their own parent profile
CREATE POLICY "Users can view own parent profile" 
ON parent_profiles FOR SELECT 
USING (auth.uid() = user_id);

-- Allow authenticated users to update their own parent profile
CREATE POLICY "Users can update own parent profile" 
ON parent_profiles FOR UPDATE 
USING (auth.uid() = user_id);

-- Allow authenticated users to insert their own parent profile  
CREATE POLICY "Users can insert own parent profile" 
ON parent_profiles FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Users cannot delete their parent profile (data retention)
-- DELETE policy intentionally omitted

-- =============================================
-- CHILD PROFILES RLS POLICIES  
-- =============================================

-- Parents can view all their children's profiles
CREATE POLICY "Parents can view own children" 
ON child_profiles FOR SELECT 
USING (auth.uid() = parent_user_id);

-- Parents can insert new child profiles
CREATE POLICY "Parents can insert own children" 
ON child_profiles FOR INSERT 
WITH CHECK (auth.uid() = parent_user_id);

-- Parents can update their children's profiles
CREATE POLICY "Parents can update own children" 
ON child_profiles FOR UPDATE 
USING (auth.uid() = parent_user_id);

-- Parents can delete their children's profiles
CREATE POLICY "Parents can delete own children" 
ON child_profiles FOR DELETE 
USING (auth.uid() = parent_user_id);

-- =============================================
-- LEARNING EVENTS RLS POLICIES
-- =============================================

-- Parents can view learning events for their children only
CREATE POLICY "Parents can view children learning events" 
ON learning_events FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM child_profiles 
    WHERE child_profiles.id = learning_events.child_profile_id 
    AND child_profiles.parent_user_id = auth.uid()
  )
);

-- System/app can insert learning events for children of authenticated parent
-- This allows the iOS app to record events on behalf of the child
CREATE POLICY "System can insert learning events for own children" 
ON learning_events FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM child_profiles 
    WHERE child_profiles.id = learning_events.child_profile_id 
    AND child_profiles.parent_user_id = auth.uid()
  )
);

-- Allow updates to learning events (for corrections or additional data)
CREATE POLICY "Parents can update children learning events" 
ON learning_events FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM child_profiles 
    WHERE child_profiles.id = learning_events.child_profile_id 
    AND child_profiles.parent_user_id = auth.uid()
  )
);

-- Learning events are generally not deleted (data retention for analytics)
-- DELETE policy intentionally omitted for audit trail

-- =============================================
-- GAME SESSIONS RLS POLICIES
-- =============================================

-- Parents can view game sessions for their children
CREATE POLICY "Parents can view children game sessions" 
ON game_sessions FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM child_profiles 
    WHERE child_profiles.id = game_sessions.child_profile_id 
    AND child_profiles.parent_user_id = auth.uid()
  )
);

-- System can insert game sessions for children of authenticated parent
CREATE POLICY "System can insert game sessions for own children" 
ON game_sessions FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM child_profiles 
    WHERE child_profiles.id = game_sessions.child_profile_id 
    AND child_profiles.parent_user_id = auth.uid()
  )
);

-- Allow updates to game sessions (to record end time, final stats, etc.)
CREATE POLICY "Parents can update children game sessions" 
ON game_sessions FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM child_profiles 
    WHERE child_profiles.id = game_sessions.child_profile_id 
    AND child_profiles.parent_user_id = auth.uid()
  )
);

-- Game sessions are generally not deleted (data retention for analytics)
-- DELETE policy intentionally omitted for audit trail

-- =============================================
-- HELPER FUNCTIONS FOR RLS
-- =============================================

-- Function to check if a user is the parent of a specific child
CREATE OR REPLACE FUNCTION is_parent_of_child(child_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM child_profiles 
    WHERE id = child_id 
    AND parent_user_id = auth.uid()
  );
$$;

-- Function to get all child IDs for the current authenticated user
CREATE OR REPLACE FUNCTION get_user_child_ids()
RETURNS UUID[]
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT ARRAY_AGG(id) FROM child_profiles 
  WHERE parent_user_id = auth.uid();
$$;

-- Comments for documentation
COMMENT ON POLICY "Users can view own parent profile" ON parent_profiles IS 
'Allows authenticated users to view only their own parent profile data';

COMMENT ON POLICY "Parents can view own children" ON child_profiles IS 
'Ensures parents can only access profiles of their own children';

COMMENT ON POLICY "Parents can view children learning events" ON learning_events IS 
'Restricts learning event access to events belonging to the authenticated parent''s children';

COMMENT ON POLICY "Parents can view children game sessions" ON game_sessions IS 
'Limits game session visibility to sessions of the authenticated parent''s children';

COMMENT ON FUNCTION is_parent_of_child(UUID) IS 
'Helper function to verify parent-child relationship for RLS policies';

COMMENT ON FUNCTION get_user_child_ids() IS 
'Returns array of child profile IDs belonging to the authenticated user';