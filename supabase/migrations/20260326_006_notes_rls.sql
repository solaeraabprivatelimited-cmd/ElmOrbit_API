-- Notes RLS policies for room-based note sharing

alter table if exists public.notes enable row level security;

-- Drop old policies for idempotency
drop policy if exists "notes_select_own" on public.notes;
drop policy if exists "notes_insert_own" on public.notes;
drop policy if exists "notes_update_own" on public.notes;
drop policy if exists "notes_delete_own" on public.notes;
drop policy if exists "notes_select_room_shared" on public.notes;

-- Allow users to read their own notes
create policy "notes_select_own"
on public.notes
for select
using (user_id = auth.uid());

-- Allow users to read shared notes in rooms they're in
create policy "notes_select_room_shared"
on public.notes
for select
using (
  is_shared = true
  and room_id is not null
  and exists (
    select 1 from public.room_participants rp
    where rp.room_id = notes.room_id
      and rp.user_id = auth.uid()
      and rp.left_at is null
  )
);

-- Allow users to insert their own notes
create policy "notes_insert_own"
on public.notes
for insert
with check (user_id = auth.uid());

-- Allow users to update their own notes
create policy "notes_update_own"
on public.notes
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Allow users to delete their own notes
create policy "notes_delete_own"
on public.notes
for delete
using (user_id = auth.uid());

-- Enable realtime for notes
do $$
begin
  begin
    execute 'alter publication supabase_realtime add table public.notes';
  exception when duplicate_object then
    null;
  end;
end
$$;

alter table if exists public.notes replica identity full;
