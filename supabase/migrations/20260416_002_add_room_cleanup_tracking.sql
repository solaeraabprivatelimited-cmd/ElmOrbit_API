-- Add room cleanup tracking for automatic deletion of empty rooms
-- Tracks when a room became empty, enabling automatic cleanup after 24 hours

-- Add tracking column for when room became empty
ALTER TABLE public.webrtc_rooms
ADD COLUMN IF NOT EXISTS emptied_at TIMESTAMP WITH TIME ZONE;

-- Add comment for clarity
COMMENT ON COLUMN public.webrtc_rooms.emptied_at IS 
'Timestamp when the room became empty (no participants). Set when last participant leaves, used for automatic cleanup after 24 hours.';

-- Create index for efficient cleanup queries
CREATE INDEX IF NOT EXISTS idx_webrtc_rooms_emptied_at 
ON public.webrtc_rooms(emptied_at) 
WHERE emptied_at IS NOT NULL AND is_active = true;

-- Create a function to safely delete old empty rooms
CREATE OR REPLACE FUNCTION public.cleanup_empty_rooms()
RETURNS TABLE(deleted_count INTEGER) AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  -- Delete rooms that have been empty for more than 24 hours
  DELETE FROM public.webrtc_rooms
  WHERE 
    emptied_at IS NOT NULL 
    AND is_active = true
    AND (now() - emptied_at) > INTERVAL '24 hours'
    AND id NOT IN (
      SELECT DISTINCT room_id FROM public.webrtc_participants 
      WHERE left_at IS NULL
    );
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RETURN QUERY SELECT v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users and service role
GRANT EXECUTE ON FUNCTION public.cleanup_empty_rooms() TO authenticated, service_role;
