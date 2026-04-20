alter table if exists public.mentor_sessions enable row level security;

drop policy if exists "mentor_sessions_select_open_availability" on public.mentor_sessions;
create policy "mentor_sessions_select_open_availability"
on public.mentor_sessions
for select
using (
  status = 'pending'
  and scheduled_at >= now()
  and auth.role() = 'authenticated'
);
