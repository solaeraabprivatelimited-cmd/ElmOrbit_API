-- ============================================================================
-- MENTOR SESSION ROOMS
-- ============================================================================
-- Tracks study rooms linked to mentor bookings
-- Only mentor + student can access (enforced via RLS)

CREATE TABLE IF NOT EXISTS public.mentor_session_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.mentor_bookings(id) ON DELETE CASCADE,
  mentor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  
  -- Room metadata
  room_name VARCHAR(255) NOT NULL,
  room_password VARCHAR(255),           -- Optional password for extra security
  
  -- Session timing
  scheduled_start TIMESTAMP NOT NULL,
  scheduled_end TIMESTAMP NOT NULL,
  actual_start TIMESTAMP,               -- When mentor joined
  actual_end TIMESTAMP,                 -- When session ended
  
  -- Status tracking
  status VARCHAR(50) NOT NULL DEFAULT 'pending' 
    CHECK (status IN ('pending', 'active', 'completed', 'cancelled')),
  
  -- Recording & analytics (optional)
  recording_url VARCHAR(500),
  duration_mins DECIMAL(10, 2),
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_mentor_session_rooms_booking_id 
  ON public.mentor_session_rooms(booking_id);
CREATE INDEX IF NOT EXISTS idx_mentor_session_rooms_mentor_id 
  ON public.mentor_session_rooms(mentor_id);
CREATE INDEX IF NOT EXISTS idx_mentor_session_rooms_student_id 
  ON public.mentor_session_rooms(student_id);
CREATE INDEX IF NOT EXISTS idx_mentor_session_rooms_status 
  ON public.mentor_session_rooms(status);
CREATE INDEX IF NOT EXISTS idx_mentor_session_rooms_scheduled_start 
  ON public.mentor_session_rooms(scheduled_start);

-- ============================================================================
-- Row Level Security (RLS)
-- ============================================================================

ALTER TABLE public.mentor_session_rooms ENABLE ROW LEVEL SECURITY;

-- Only mentor and student can view their session rooms
DROP POLICY IF EXISTS "mentor_session_rooms_select_own" ON public.mentor_session_rooms;
CREATE POLICY "mentor_session_rooms_select_own"
  ON public.mentor_session_rooms
  FOR SELECT
  USING (mentor_id = auth.uid() OR student_id = auth.uid());

-- Only mentor and student can update their own rooms (status, timestamps, etc)
DROP POLICY IF EXISTS "mentor_session_rooms_update_own" ON public.mentor_session_rooms;
CREATE POLICY "mentor_session_rooms_update_own"
  ON public.mentor_session_rooms
  FOR UPDATE
  USING (mentor_id = auth.uid() OR student_id = auth.uid())
  WITH CHECK (mentor_id = auth.uid() OR student_id = auth.uid());

-- Allow deletion on cancellation
DROP POLICY IF EXISTS "mentor_session_rooms_delete_own" ON public.mentor_session_rooms;
CREATE POLICY "mentor_session_rooms_delete_own"
  ON public.mentor_session_rooms
  FOR DELETE
  USING (mentor_id = auth.uid() OR student_id = auth.uid());

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.mentor_session_rooms;
ALTER TABLE public.mentor_session_rooms REPLICA IDENTITY FULL;
