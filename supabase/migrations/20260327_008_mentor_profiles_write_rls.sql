alter table if exists public.mentor_profiles enable row level security;

drop policy if exists "mentor_profiles_insert_own" on public.mentor_profiles;
create policy "mentor_profiles_insert_own"
on public.mentor_profiles
for insert
with check (auth.uid() = user_id);

drop policy if exists "mentor_profiles_update_own" on public.mentor_profiles;
create policy "mentor_profiles_update_own"
on public.mentor_profiles
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
