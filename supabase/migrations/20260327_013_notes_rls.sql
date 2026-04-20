alter table if exists public.notes enable row level security;

drop policy if exists "notes_select_own" on public.notes;
create policy "notes_select_own"
on public.notes
for select
using (auth.uid() = user_id);

drop policy if exists "notes_insert_own" on public.no/tes;
create policy "notes_insert_own"
on public.notes
for insert
with check (auth.uid() = user_id);

drop policy if exists "notes_update_own" on public.notes;
create policy "notes_update_own"
on public.notes
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "notes_delete_own" on public.notes;
create policy "notes_delete_own"
on public.notes
for delete
using (auth.uid() = user_id);
