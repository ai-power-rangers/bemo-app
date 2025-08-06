-- Enable realtime subscriptions for live updates in the iOS app
-- This allows the app to receive real-time notifications when data changes

-- =============================================
-- ENABLE REALTIME FOR TABLES
-- =============================================

-- Enable realtime for child profiles (for live profile updates)
ALTER PUBLICATION supabase_realtime ADD TABLE child_profiles;

-- Enable realtime for learning events (for live progress tracking) 
ALTER PUBLICATION supabase_realtime ADD TABLE learning_events;

-- Enable realtime for game sessions (for live session monitoring)
ALTER PUBLICATION supabase_realtime ADD TABLE game_sessions;

-- Note: parent_profiles typically don't need realtime updates as they change infrequently
-- Uncomment the following line if you need realtime updates for parent profiles:
-- ALTER PUBLICATION supabase_realtime ADD TABLE parent_profiles;

-- =============================================
-- REALTIME HELPER FUNCTIONS
-- =============================================

-- Function to broadcast custom events for complex updates
-- This allows the iOS app to listen for custom events beyond table changes
CREATE OR REPLACE FUNCTION broadcast_learning_milestone(
  child_id UUID,
  milestone_type TEXT,
  milestone_data JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify the child belongs to the authenticated user
  IF NOT is_parent_of_child(child_id) THEN
    RAISE EXCEPTION 'Unauthorized: Child profile does not belong to authenticated user';
  END IF;
  
  -- Broadcast the milestone event
  PERFORM pg_notify(
    'learning_milestone',
    json_build_object(
      'child_id', child_id,
      'milestone_type', milestone_type,
      'milestone_data', milestone_data,
      'timestamp', extract(epoch from now())
    )::text
  );
END;
$$;

-- Function to broadcast XP updates with additional context
CREATE OR REPLACE FUNCTION broadcast_xp_update(
  child_id UUID,
  old_xp INTEGER,
  new_xp INTEGER,
  xp_source TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify the child belongs to the authenticated user
  IF NOT is_parent_of_child(child_id) THEN
    RAISE EXCEPTION 'Unauthorized: Child profile does not belong to authenticated user';
  END IF;
  
  -- Only broadcast if XP actually changed
  IF old_xp != new_xp THEN
    PERFORM pg_notify(
      'xp_update',
      json_build_object(
        'child_id', child_id,
        'old_xp', old_xp,
        'new_xp', new_xp,
        'xp_gained', new_xp - old_xp,
        'source', xp_source,
        'timestamp', extract(epoch from now())
      )::text
    );
  END IF;
END;
$$;

-- =============================================
-- TRIGGERS FOR REALTIME EVENTS
-- =============================================

-- Trigger function to broadcast XP changes automatically
CREATE OR REPLACE FUNCTION notify_xp_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only notify if total_xp actually changed
  IF OLD.total_xp IS DISTINCT FROM NEW.total_xp THEN
    PERFORM broadcast_xp_update(
      NEW.id,
      COALESCE(OLD.total_xp, 0),
      NEW.total_xp,
      'profile_update'
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for XP changes on child_profiles
CREATE TRIGGER child_profile_xp_change_notify
  AFTER UPDATE ON child_profiles
  FOR EACH ROW
  EXECUTE FUNCTION notify_xp_change();

-- Trigger function to broadcast learning event creation
CREATE OR REPLACE FUNCTION notify_learning_event()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Broadcast significant learning events
  IF NEW.event_type IN ('level_completed', 'achievement_unlocked', 'milestone_reached') THEN
    PERFORM pg_notify(
      'learning_event',
      json_build_object(
        'event_id', NEW.id,
        'child_id', NEW.child_profile_id,
        'event_type', NEW.event_type,
        'game_id', NEW.game_id,
        'xp_awarded', NEW.xp_awarded,
        'timestamp', extract(epoch from NEW.created_at)
      )::text
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for learning events
CREATE TRIGGER learning_event_notify
  AFTER INSERT ON learning_events
  FOR EACH ROW
  EXECUTE FUNCTION notify_learning_event();

-- Trigger function to broadcast session completion
CREATE OR REPLACE FUNCTION notify_session_end()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only notify when a session is completed (ended_at is set)
  IF OLD.ended_at IS NULL AND NEW.ended_at IS NOT NULL THEN
    PERFORM pg_notify(
      'session_completed',
      json_build_object(
        'session_id', NEW.id,
        'child_id', NEW.child_profile_id,
        'game_id', NEW.game_id,
        'total_xp_earned', NEW.total_xp_earned,
        'levels_completed', NEW.levels_completed,
        'duration_minutes', extract(epoch from (NEW.ended_at - NEW.started_at))/60,
        'timestamp', extract(epoch from NEW.ended_at)
      )::text
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for session completion
CREATE TRIGGER game_session_end_notify
  AFTER UPDATE ON game_sessions
  FOR EACH ROW
  EXECUTE FUNCTION notify_session_end();

-- =============================================
-- REALTIME SECURITY
-- =============================================

-- Function to check if user can subscribe to realtime updates for a child
CREATE OR REPLACE FUNCTION can_subscribe_to_child_updates(child_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT is_parent_of_child(child_id);
$$;

-- =============================================
-- REALTIME SUBSCRIPTION HELPERS
-- =============================================

-- View for realtime child progress (combines multiple tables)
CREATE VIEW realtime_child_progress AS
SELECT 
  cp.id as child_id,
  cp.parent_user_id,
  cp.name,
  cp.total_xp,
  COALESCE(recent_session.game_id, 'none') as current_game,
  COALESCE(recent_session.started_at, cp.updated_at) as last_activity,
  CASE 
    WHEN recent_session.ended_at IS NULL THEN 'playing'
    ELSE 'idle'
  END as status
FROM child_profiles cp
LEFT JOIN LATERAL (
  SELECT game_id, started_at, ended_at
  FROM game_sessions gs
  WHERE gs.child_profile_id = cp.id
  ORDER BY gs.started_at DESC
  LIMIT 1
) recent_session ON true;

-- Apply RLS to the realtime view
ALTER VIEW realtime_child_progress SET (security_barrier = true);

-- Note: Views cannot be added directly to realtime publication
-- Clients should subscribe to child_profiles table changes instead
-- ALTER PUBLICATION supabase_realtime ADD TABLE realtime_child_progress;

-- Comments for documentation
COMMENT ON FUNCTION broadcast_learning_milestone(UUID, TEXT, JSONB) IS 
'Broadcasts custom learning milestone events for realtime updates in the iOS app';

COMMENT ON FUNCTION broadcast_xp_update(UUID, INTEGER, INTEGER, TEXT) IS 
'Broadcasts XP change events with context for realtime progress tracking';

COMMENT ON TRIGGER child_profile_xp_change_notify ON child_profiles IS 
'Automatically broadcasts XP changes for realtime updates';

COMMENT ON TRIGGER learning_event_notify ON learning_events IS 
'Broadcasts significant learning events for realtime notifications';

COMMENT ON TRIGGER game_session_end_notify ON game_sessions IS 
'Broadcasts session completion events for realtime progress tracking';

COMMENT ON VIEW realtime_child_progress IS 
'Realtime view combining child profile data with current activity status for live dashboard updates';