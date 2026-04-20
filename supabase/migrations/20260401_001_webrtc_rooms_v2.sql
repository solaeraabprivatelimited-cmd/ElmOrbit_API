-- WebRTC Study Rooms v2 - Production-grade schema with reliability
-- This migration creates tables for peer-to-peer WebRTC study rooms

-- ============================================
-- Study Rooms Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.webrtc_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  mode TEXT NOT NULL CHECK (mode IN ('focus', 'silent', 'collaborative', 'live')),
  subject TEXT,
  host_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Constraints
  max_participants INTEGER DEFAULT 6 CHECK (max_participants > 0 AND max_participants <= 20),
  is_active BOOLEAN DEFAULT true,
  password_hash TEXT, -- Optional password protection
  
  -- Metadata for monitoring
  connection_quality_threshold TEXT DEFAULT 'medium' CHECK (connection_quality_threshold IN ('low', 'medium', 'high')),
  enable_screen_sharing BOOLEAN DEFAULT true,
  enable_recording BOOLEAN DEFAULT false,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  ends_at TIMESTAMP WITH TIME ZONE,
  closed_at TIMESTAMP WITH TIME ZONE,
  
  -- Audit trail
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

-- ============================================
-- Peer Participants Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.webrtc_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.webrtc_rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Connection state
  connection_state TEXT DEFAULT 'new' CHECK (connection_state IN ('new', 'connecting', 'connected', 'disconnected', 'failed')),
  signaling_state TEXT DEFAULT 'stable' CHECK (signaling_state IN ('stable', 'have-local-offer', 'have-remote-offer', 'have-local-pranswer', 'have-remote-pranswer')),
  ice_connection_state TEXT DEFAULT 'new' CHECK (ice_connection_state IN ('new', 'checking', 'connected', 'completed', 'failed', 'disconnected', 'closed')),
  
  -- Media state
  is_audio_enabled BOOLEAN DEFAULT true,
  is_video_enabled BOOLEAN DEFAULT true,
  is_screen_sharing BOOLEAN DEFAULT false,
  is_muted BOOLEAN DEFAULT false,
  
  -- Permissions
  permissions TEXT DEFAULT 'member' CHECK (permissions IN ('host', 'moderator', 'member')),
  is_pinned BOOLEAN DEFAULT false,
  
  -- Connection quality metrics
  last_received_audio TIMESTAMP WITH TIME ZONE,
  last_received_video TIMESTAMP WITH TIME ZONE,
  reported_connection_quality TEXT CHECK (reported_connection_quality IN ('excellent', 'good', 'fair', 'poor', 'unknown')),
  
  -- Timing
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  left_at TIMESTAMP WITH TIME ZONE,
  disconnected_at TIMESTAMP WITH TIME ZONE,
  last_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  UNIQUE(room_id, user_id)
);

-- ============================================
-- WebRTC Signaling Events (for P2P negotiation)
-- ============================================
CREATE TABLE IF NOT EXISTS public.webrtc_signaling (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.webrtc_rooms(id) ON DELETE CASCADE,
  from_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Signal type: offer, answer, ice-candidate, renegotiate, reconnect
  signal_type TEXT NOT NULL CHECK (signal_type IN ('offer', 'answer', 'ice-candidate', 'renegotiate', 'reconnect', 'stats', 'error')),
  
  -- Payload (SDP, ICE candidate, error details, etc)
  payload JSONB NOT NULL,
  
  -- Error info
  error_code TEXT,
  error_message TEXT,
  
  -- Delivery tracking
  was_processed BOOLEAN DEFAULT false,
  processing_error TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  processed_at TIMESTAMP WITH TIME ZONE
);

-- ============================================
-- Connection Monitoring & Diagnostics
-- ============================================
CREATE TABLE IF NOT EXISTS public.webrtc_diagnostics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.webrtc_rooms(id) ON DELETE CASCADE,
  participant_id UUID NOT NULL REFERENCES public.webrtc_participants(id) ON DELETE CASCADE,
  
  -- Network metrics
  rtt_ms DECIMAL(10, 2),
  packet_loss_percent DECIMAL(5, 2),
  bandwidth_mb_s DECIMAL(10, 2),
  jitter_ms DECIMAL(10, 2),
  
  -- Audio/Video quality
  audio_codec TEXT,
  audio_sample_rate INTEGER,
  video_codec TEXT,
  video_resolution TEXT,
  video_framerate INTEGER,
  
  -- Issues detected
  issues JSONB, -- Array of issues: {'type': 'audio_dropout', 'severity': 'high', 'timestamp': '...'}
  
  -- Report metadata
  reported_by_user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- ============================================
-- Connection Recovery Log
-- ============================================
CREATE TABLE IF NOT EXISTS public.webrtc_recovery_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.webrtc_rooms(id) ON DELETE CASCADE,
  participant_id UUID NOT NULL REFERENCES public.webrtc_participants(id) ON DELETE CASCADE,
  
  -- Recovery event
  event_type TEXT NOT NULL CHECK (event_type IN ('disconnect', 'reconnect', 'ice_restart', 'renegotiate', 'fallback_turn', 'failure')),
  reason TEXT,
  
  -- Details
  details JSONB,
  
  -- Recovery status
  recovery_attempted_at TIMESTAMP WITH TIME ZONE,
  recovery_successful BOOLEAN,
  recovery_duration_ms INTEGER,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- ============================================
-- Indexes for Performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_webrtc_rooms_host ON public.webrtc_rooms(host_id);
CREATE INDEX IF NOT EXISTS idx_webrtc_rooms_active ON public.webrtc_rooms(is_active);
CREATE INDEX IF NOT EXISTS idx_webrtc_rooms_code ON public.webrtc_rooms(code);
CREATE INDEX IF NOT EXISTS idx_webrtc_participants_room ON public.webrtc_participants(room_id);
CREATE INDEX IF NOT EXISTS idx_webrtc_participants_user ON public.webrtc_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_webrtc_participants_connection ON public.webrtc_participants(connection_state);
CREATE INDEX IF NOT EXISTS idx_webrtc_signaling_room ON public.webrtc_signaling(room_id);
CREATE INDEX IF NOT EXISTS idx_webrtc_signaling_users ON public.webrtc_signaling(from_user_id, to_user_id);
CREATE INDEX IF NOT EXISTS idx_webrtc_signaling_processed ON public.webrtc_signaling(was_processed);
CREATE INDEX IF NOT EXISTS idx_webrtc_diagnostics_room ON public.webrtc_diagnostics(room_id);
CREATE INDEX IF NOT EXISTS idx_webrtc_diagnostics_participant ON public.webrtc_diagnostics(participant_id);
CREATE INDEX IF NOT EXISTS idx_webrtc_recovery_room ON public.webrtc_recovery_log(room_id);

-- ============================================
-- Row Level Security (RLS)
-- ============================================
ALTER TABLE public.webrtc_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webrtc_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webrtc_signaling ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webrtc_diagnostics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webrtc_recovery_log ENABLE ROW LEVEL SECURITY;

-- Everyone can read active rooms
CREATE POLICY "webrtc_rooms_read_active"
ON public.webrtc_rooms
FOR SELECT
USING (is_active = true);

-- Host can create rooms
CREATE POLICY "webrtc_rooms_create"
ON public.webrtc_rooms
FOR INSERT
WITH CHECK (host_id = auth.uid());

-- Host can update their rooms
CREATE POLICY "webrtc_rooms_update_host"
ON public.webrtc_rooms
FOR UPDATE
USING (host_id = auth.uid())
WITH CHECK (host_id = auth.uid());

-- Authenticated users in a room can see participants
CREATE POLICY "webrtc_participants_read"
ON public.webrtc_participants
FOR SELECT
USING (auth.role() = 'authenticated');

-- Users can add themselves to a room
CREATE POLICY "webrtc_participants_self_insert"
ON public.webrtc_participants
FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Users can update their own participant record
CREATE POLICY "webrtc_participants_self_update"
ON public.webrtc_participants
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Signaling for authenticated users in room
CREATE POLICY "webrtc_signaling_read"
ON public.webrtc_signaling
FOR SELECT
USING (
  auth.uid() = from_user_id OR 
  auth.uid() = to_user_id OR
  auth.role() = 'service_role'
);

CREATE POLICY "webrtc_signaling_create"
ON public.webrtc_signaling
FOR INSERT
WITH CHECK (from_user_id = auth.uid());

-- Diagnostics
CREATE POLICY "webrtc_diagnostics_create"
ON public.webrtc_diagnostics
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "webrtc_diagnostics_read"
ON public.webrtc_diagnostics
FOR SELECT
USING (
  reported_by_user_id = auth.uid() OR
  auth.role() = 'service_role'
);

-- ============================================
-- Cleanup: Drop old study_rooms tables
-- ============================================
DROP TABLE IF EXISTS public.room_reactions CASCADE;
DROP TABLE IF EXISTS public.room_messages CASCADE;
DROP TABLE IF EXISTS public.room_participants CASCADE;
DROP TABLE IF EXISTS public.study_rooms CASCADE;

COMMENT ON TABLE public.webrtc_rooms IS 'Production WebRTC study rooms with reliability features';
COMMENT ON TABLE public.webrtc_participants IS 'Peer-to-peer participant connection states';
COMMENT ON TABLE public.webrtc_signaling IS 'SDP and ICE candidate signaling for WebRTC negotiation';
COMMENT ON TABLE public.webrtc_diagnostics IS 'Network and media quality metrics';
COMMENT ON TABLE public.webrtc_recovery_log IS 'Connection recovery and failure tracking for diagnostics';
