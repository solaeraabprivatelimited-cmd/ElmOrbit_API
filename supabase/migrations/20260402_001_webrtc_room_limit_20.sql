ALTER TABLE public.webrtc_rooms
  DROP CONSTRAINT IF EXISTS webrtc_rooms_max_participants_check;

ALTER TABLE public.webrtc_rooms
  ALTER COLUMN max_participants SET DEFAULT 6;

ALTER TABLE public.webrtc_rooms
  ADD CONSTRAINT webrtc_rooms_max_participants_check
  CHECK (max_participants > 0 AND max_participants <= 20);

UPDATE public.webrtc_rooms
SET max_participants = 20
WHERE max_participants > 20;