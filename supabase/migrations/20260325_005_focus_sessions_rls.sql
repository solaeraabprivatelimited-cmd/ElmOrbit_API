-- Enable direct DB persistence for completed focus sessions.

alter table if exists public.focus_sessions enable row level security;

-- Idempotent policy recreation.
drop policy if exists "focus_sessions_select_own" on public.focus_sessions;
drop policy if exists "focus_sessions_insert_own" on public.focus_sessions;
drop policy if exists "focus_sessions_update_own" on public.focus_sessions;
drop policy if exists "focus_sessions_delete_own" on public.focus_sessions;

create policy "focus_sessions_select_own"
on public.focus_sessions
for select
using (user_id = auth.uid());

create policy "focus_sessions_insert_own"
on public.focus_sessions
for insert
with check (user_id = auth.uid());

create policy "focus_sessions_update_own"
on public.focus_sessions
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "focus_sessions_delete_own"
on public.focus_sessions
for delete
using (user_id = auth.uid());
