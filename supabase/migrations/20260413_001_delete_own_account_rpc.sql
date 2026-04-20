-- RPC function to delete the currently authenticated user's own account.
-- Uses SECURITY DEFINER so it runs with elevated privileges to delete from auth.users.
-- The auth.uid() check ensures a user can only delete their own account.
-- Deleting from auth.users cascades to:
--   profiles → payment_methods, withdrawal_requests, session_ratings,
--              notes, planner_tasks, planner_reminders, study_plans,
--              mood_checkins, focus_sessions, notifications, subjects
--   users (separate table) → mentor_bookings, room_participants, etc.

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  -- Clean up the public.users table row (no FK to auth.users, must be manual)
  delete from public.users where id = v_user_id;

  -- Delete from auth.users — cascades to profiles and all child tables
  delete from auth.users where id = v_user_id;
end;
$$;

-- Only authenticated users can call this function
revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
