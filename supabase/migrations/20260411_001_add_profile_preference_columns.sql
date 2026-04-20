-- Add missing columns to profiles table for session notes and notification preferences

-- Add session_notes column if it doesn't exist
alter table if exists public.profiles
add column if not exists session_notes jsonb default '{}';

-- Add notification_preferences column if it doesn't exist
alter table if exists public.profiles
add column if not exists notification_preferences jsonb default '{
  "sessionAlerts": true,
  "mentorMessages": true,
  "studyReminders": true,
  "moodCheckins": false,
  "communityEvents": false,
  "systemUpdates": false
}'::jsonb;

-- Create index on session_notes for faster queries
create index if not exists idx_profiles_session_notes on public.profiles using gin(session_notes);

-- Create index on notification_preferences for faster queries
create index if not exists idx_profiles_notification_preferences on public.profiles using gin(notification_preferences);

-- Update updated_at trigger to capture these changes
-- (The existing trigger should already handle this)
