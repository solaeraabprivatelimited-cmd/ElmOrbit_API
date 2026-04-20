-- ============================================================================
-- ROOM CLEANUP & AUTO-DELETE POLICY
-- ============================================================================

-- 1) DELETE ALL ROOMS (careful - removes all study rooms and related data)
-- WARNING: This will cascade delete all related data (participants, messages, reactions, etc)
DELETE FROM public.study_rooms;

-- 2) DELETE UNUSED ROOMS (inactive for 24+ hours)
-- Run this periodically or as a cron job
DELETE FROM public.study_rooms
WHERE 
  -- Room hasn't been updated in last 24 hours
  updated_at < NOW() - INTERVAL '24 hours'
  -- AND room is no longer active
  AND is_active = false;

-- 3) MARK ROOMS AS INACTIVE if no activity in 24 hours
-- Run this before the deletion above to mark stale rooms
UPDATE public.study_rooms
SET is_active = false, updated_at = NOW()
WHERE 
  is_active = true
  AND updated_at < NOW() - INTERVAL '24 hours'
  AND id NOT IN (
    -- Don't deactivate rooms that still have active participants
    SELECT DISTINCT room_id 
    FROM public.room_participants 
    WHERE left_at IS NULL
  );

-- 4) ALTERNATIVE: Delete rooms with no participants for 24+ hours
DELETE FROM public.study_rooms
WHERE id NOT IN (
  SELECT DISTINCT room_id FROM public.room_participants 
  WHERE joined_at > NOW() - INTERVAL '24 hours'
)
AND created_at < NOW() - INTERVAL '24 hours'
AND is_active = false;

-- 5) Auto-cleanup function (call via Edge Function or cron)
CREATE OR REPLACE FUNCTION public.cleanup_inactive_rooms()
RETURNS TABLE(deleted_count integer) AS $$
DECLARE
  _deleted_count integer;
BEGIN
  -- Mark rooms as inactive if no activity in 24 hours
  UPDATE public.study_rooms
  SET is_active = false, updated_at = NOW()
  WHERE 
    is_active = true
    AND updated_at < NOW() - INTERVAL '24 hours'
    AND id NOT IN (
      SELECT DISTINCT room_id 
      FROM public.room_participants 
      WHERE left_at IS NULL
    );

  -- Delete inactive rooms older than 24 hours
  DELETE FROM public.study_rooms
  WHERE 
    is_active = false
    AND updated_at < NOW() - INTERVAL '24 hours';

  GET DIAGNOSTICS _deleted_count = ROW_COUNT;
  
  RETURN QUERY SELECT _deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6) Grant permission to call cleanup function
GRANT EXECUTE ON FUNCTION public.cleanup_inactive_rooms() TO authenticated, anon;
