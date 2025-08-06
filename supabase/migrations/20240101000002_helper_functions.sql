-- Helper functions and views for Bemo app analytics and data management

-- =============================================
-- ANALYTICS HELPER FUNCTIONS
-- =============================================

-- Function to get learning progress summary for a child
CREATE OR REPLACE FUNCTION get_child_learning_summary(child_id UUID)
RETURNS TABLE (
  total_xp INTEGER,
  games_played INTEGER,
  total_sessions INTEGER,
  total_play_time_minutes INTEGER,
  levels_completed INTEGER,
  favorite_game TEXT
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    cp.total_xp,
    COUNT(DISTINCT le.game_id) as games_played,
    COUNT(DISTINCT gs.id) as total_sessions,
    COALESCE(
      EXTRACT(EPOCH FROM SUM(gs.ended_at - gs.started_at))::INTEGER / 60, 
      0
    ) as total_play_time_minutes,
    SUM(gs.levels_completed) as levels_completed,
    (
      SELECT le_inner.game_id 
      FROM learning_events le_inner 
      WHERE le_inner.child_profile_id = child_id 
      GROUP BY le_inner.game_id 
      ORDER BY COUNT(*) DESC 
      LIMIT 1
    ) as favorite_game
  FROM child_profiles cp
  LEFT JOIN learning_events le ON cp.id = le.child_profile_id
  LEFT JOIN game_sessions gs ON cp.id = gs.child_profile_id AND gs.ended_at IS NOT NULL
  WHERE cp.id = child_id
  GROUP BY cp.id, cp.total_xp;
$$;

-- Function to get recent learning events for a child
CREATE OR REPLACE FUNCTION get_recent_learning_events(child_id UUID, limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
  event_id UUID,
  event_type TEXT,
  game_id TEXT,
  xp_awarded INTEGER,
  event_data JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    le.id as event_id,
    le.event_type,
    le.game_id,
    le.xp_awarded,
    le.event_data,
    le.created_at
  FROM learning_events le
  WHERE le.child_profile_id = child_id
  ORDER BY le.created_at DESC
  LIMIT limit_count;
$$;

-- Function to get daily learning stats for a date range
CREATE OR REPLACE FUNCTION get_daily_learning_stats(
  child_id UUID, 
  start_date DATE DEFAULT CURRENT_DATE - INTERVAL '7 days',
  end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  play_date DATE,
  total_xp_earned INTEGER,
  sessions_count INTEGER,
  play_time_minutes INTEGER,
  games_played TEXT[]
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    DATE(le.created_at) as play_date,
    SUM(le.xp_awarded) as total_xp_earned,
    COUNT(DISTINCT le.session_id) as sessions_count,
    COALESCE(
      EXTRACT(EPOCH FROM SUM(gs.ended_at - gs.started_at))::INTEGER / 60, 
      0
    ) as play_time_minutes,
    ARRAY_AGG(DISTINCT le.game_id) as games_played
  FROM learning_events le
  LEFT JOIN game_sessions gs ON le.session_id = gs.id
  WHERE le.child_profile_id = child_id
    AND DATE(le.created_at) BETWEEN start_date AND end_date
  GROUP BY DATE(le.created_at)
  ORDER BY play_date DESC;
$$;

-- =============================================
-- PROFILE MANAGEMENT FUNCTIONS
-- =============================================

-- Function to safely update child XP (prevents negative values)
CREATE OR REPLACE FUNCTION update_child_xp(child_id UUID, xp_change INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_xp INTEGER;
BEGIN
  UPDATE child_profiles 
  SET total_xp = GREATEST(0, total_xp + xp_change)
  WHERE id = child_id 
    AND parent_user_id = auth.uid()
  RETURNING total_xp INTO new_xp;
  
  IF new_xp IS NULL THEN
    RAISE EXCEPTION 'Child profile not found or unauthorized access';
  END IF;
  
  RETURN new_xp;
END;
$$;

-- Function to create a complete learning event with XP update
CREATE OR REPLACE FUNCTION record_learning_event(
  child_id UUID,
  event_type_param TEXT,
  game_id_param TEXT,
  xp_awarded_param INTEGER DEFAULT 0,
  event_data_param JSONB DEFAULT '{}',
  session_id_param UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  event_id UUID;
BEGIN
  -- Verify the child belongs to the authenticated user
  IF NOT is_parent_of_child(child_id) THEN
    RAISE EXCEPTION 'Unauthorized: Child profile does not belong to authenticated user';
  END IF;
  
  -- Insert the learning event
  INSERT INTO learning_events (
    child_profile_id, 
    event_type, 
    game_id, 
    xp_awarded, 
    event_data, 
    session_id
  ) VALUES (
    child_id,
    event_type_param,
    game_id_param,
    xp_awarded_param,
    event_data_param,
    session_id_param
  ) RETURNING id INTO event_id;
  
  -- Update child's total XP if XP was awarded
  IF xp_awarded_param > 0 THEN
    PERFORM update_child_xp(child_id, xp_awarded_param);
  END IF;
  
  RETURN event_id;
END;
$$;

-- =============================================
-- SESSION MANAGEMENT FUNCTIONS
-- =============================================

-- Function to start a new game session
CREATE OR REPLACE FUNCTION start_game_session(
  child_id UUID,
  game_id_param TEXT,
  session_data_param JSONB DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  session_id UUID;
BEGIN
  -- Verify the child belongs to the authenticated user
  IF NOT is_parent_of_child(child_id) THEN
    RAISE EXCEPTION 'Unauthorized: Child profile does not belong to authenticated user';
  END IF;
  
  -- Insert new game session
  INSERT INTO game_sessions (
    child_profile_id,
    game_id,
    session_data
  ) VALUES (
    child_id,
    game_id_param,
    session_data_param
  ) RETURNING id INTO session_id;
  
  -- Record session start event
  PERFORM record_learning_event(
    child_id,
    'game_started',
    game_id_param,
    0,
    jsonb_build_object('session_started', true),
    session_id
  );
  
  RETURN session_id;
END;
$$;

-- Function to end a game session
CREATE OR REPLACE FUNCTION end_game_session(
  session_id_param UUID,
  final_xp_earned INTEGER DEFAULT 0,
  final_levels_completed INTEGER DEFAULT 0,
  final_session_data JSONB DEFAULT '{}'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  child_id UUID;
  game_id_var TEXT;
BEGIN
  -- Get session details and verify ownership
  SELECT gs.child_profile_id, gs.game_id 
  INTO child_id, game_id_var
  FROM game_sessions gs
  JOIN child_profiles cp ON gs.child_profile_id = cp.id
  WHERE gs.id = session_id_param 
    AND cp.parent_user_id = auth.uid()
    AND gs.ended_at IS NULL;
  
  IF child_id IS NULL THEN
    RAISE EXCEPTION 'Session not found, already ended, or unauthorized access';
  END IF;
  
  -- Update session with end data
  UPDATE game_sessions 
  SET 
    ended_at = NOW(),
    total_xp_earned = final_xp_earned,
    levels_completed = final_levels_completed,
    session_data = session_data || final_session_data
  WHERE id = session_id_param;
  
  -- Record session end event
  PERFORM record_learning_event(
    child_id,
    'game_ended',
    game_id_var,
    0,
    jsonb_build_object(
      'session_ended', true,
      'total_xp_earned', final_xp_earned,
      'levels_completed', final_levels_completed
    ),
    session_id_param
  );
  
  RETURN TRUE;
END;
$$;

-- =============================================
-- VIEWS FOR COMMON QUERIES
-- =============================================

-- View for child profiles with aggregated stats
CREATE VIEW child_profiles_with_stats AS
SELECT 
  cp.*,
  COALESCE(stats.total_events, 0) as total_events,
  COALESCE(stats.total_sessions, 0) as total_sessions,
  COALESCE(stats.games_played, 0) as games_played,
  stats.last_played,
  stats.favorite_game
FROM child_profiles cp
LEFT JOIN (
  SELECT 
    cp_inner.id,
    COUNT(le.id) as total_events,
    COUNT(DISTINCT gs.id) as total_sessions,
    COUNT(DISTINCT le.game_id) as games_played,
    MAX(le.created_at) as last_played,
    (
      SELECT le_fav.game_id 
      FROM learning_events le_fav 
      WHERE le_fav.child_profile_id = cp_inner.id 
      GROUP BY le_fav.game_id 
      ORDER BY COUNT(*) DESC 
      LIMIT 1
    ) as favorite_game
  FROM child_profiles cp_inner
  LEFT JOIN learning_events le ON cp_inner.id = le.child_profile_id
  LEFT JOIN game_sessions gs ON cp_inner.id = gs.child_profile_id
  GROUP BY cp_inner.id
) stats ON cp.id = stats.id;

-- Apply RLS to the view
ALTER VIEW child_profiles_with_stats SET (security_barrier = true);

-- Comments for documentation
COMMENT ON FUNCTION get_child_learning_summary(UUID) IS 
'Returns comprehensive learning statistics for a specific child profile';

COMMENT ON FUNCTION record_learning_event(UUID, TEXT, TEXT, INTEGER, JSONB, UUID) IS 
'Creates a learning event and updates child XP in a single transaction';

COMMENT ON FUNCTION start_game_session(UUID, TEXT, JSONB) IS 
'Starts a new game session and records the session start event';

COMMENT ON FUNCTION end_game_session(UUID, INTEGER, INTEGER, JSONB) IS 
'Ends a game session and records final statistics';

COMMENT ON VIEW child_profiles_with_stats IS 
'Child profiles enriched with aggregated learning statistics for dashboard display';