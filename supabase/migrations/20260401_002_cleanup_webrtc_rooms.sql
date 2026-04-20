-- ============================================================================
-- WebRTC Room Cleanup Function (replaces legacy study_rooms cleanup)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.cleanup_inactive_rooms()
RETURNS TABLE(deleted_count integer) AS $$
DECLARE
  _deleted_count integer;
BEGIN
  -- Mark rooms inactive if no active participants for 24+ hours.
  UPDATE public.webrtc_rooms wr
  SET is_active = false,
      updated_at = NOW(),
      closed_at = COALESCE(closed_at, NOW())
  WHERE wr.is_active = true
    AND wr.updated_at < NOW() - INTERVAL '24 hours'
    AND NOT EXISTS (
      SELECT 1
      FROM public.webrtc_participants wp
      WHERE wp.room_id = wr.id
        AND wp.disconnected_at IS NULL
    );

  -- Delete old inactive rooms that have been stale for 24+ hours.
  DELETE FROM public.webrtc_rooms wr
  WHERE wr.is_active = false
    AND wr.updated_at < NOW() - INTERVAL '24 hours';

  GET DIAGNOSTICS _deleted_count = ROW_COUNT;

  RETURN QUERY SELECT _deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.cleanup_inactive_rooms() TO authenticated, anon;
