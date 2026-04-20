alter table if exists public.mood_checkins enable row level security;

drop policy if exists "mood_checkins_select_own" on public.mood_checkins;
create policy "mood_checkins_select_own"
on public.mood_checkins
for select
using (auth.uid() = user_id);

drop policy if exists "mood_checkins_insert_own" on public.mood_checkins;
create policy "mood_checkins_insert_own"
on public.mood_checkins
for insert
with check (auth.uid() = user_id);
