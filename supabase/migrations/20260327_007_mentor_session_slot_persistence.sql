alter table if exists public.mentor_sessions
  alter column student_id drop not null;

alter table if exists public.mentor_sessions enable row level security;

drop policy if exists "mentor_sessions_insert_own_open_slot" on public.mentor_sessions;
create policy "mentor_sessions_insert_own_open_slot"
on public.mentor_sessions
for insert
with check (
  auth.uid() = mentor_id
  and student_id is null
  and status = 'pending'
);

drop policy if exists "mentor_sessions_update_own_open_slot" on public.mentor_sessions;
create policy "mentor_sessions_update_own_open_slot"
on public.mentor_sessions
for update
using (
  auth.uid() = mentor_id
  and student_id is null
  and status = 'pending'
)
with check (
  auth.uid() = mentor_id
  and student_id is null
  and status = 'pending'
);

drop policy if exists "mentor_sessions_delete_own_open_slot" on public.mentor_sessions;
create policy "mentor_sessions_delete_own_open_slot"
on public.mentor_sessions
for delete
using (
  auth.uid() = mentor_id
  and student_id is null
  and status = 'pending'
);
