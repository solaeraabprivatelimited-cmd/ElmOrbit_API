-- Allow authenticated users to browse mentor profiles for the student mentor directory.

alter table if exists public.mentor_profiles enable row level security;

drop policy if exists "mentor_profiles_select_authenticated" on public.mentor_profiles;
create policy "mentor_profiles_select_authenticated"
on public.mentor_profiles
for select
using (auth.role() = 'authenticated');
