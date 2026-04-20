-- Fix WebRTC signal type constraint to accept 'candidate' instead of 'ice-candidate'
-- This aligns with WebRTC standard terminology and backend Pydantic validation

ALTER TABLE public.webrtc_signaling
DROP CONSTRAINT webrtc_signaling_signal_type_check;

ALTER TABLE public.webrtc_signaling
ADD CONSTRAINT webrtc_signaling_signal_type_check 
CHECK (signal_type IN ('offer', 'answer', 'candidate', 'renegotiate', 'reconnect', 'stats', 'error'));
