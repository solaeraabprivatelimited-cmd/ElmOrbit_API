-- Mentor dashboard client reads for own profile, sessions, and payments.

alter table if exists public.mentor_profiles enable row level security;
alter table if exists public.mentor_sessions enable row level security;
alter table if exists public.payments enable row level security;

drop policy if exists "mentor_profiles_select_own" on public.mentor_profiles;
create policy "mentor_profiles_select_own"
on public.mentor_profiles
for select
using (auth.uid() = user_id);

drop policy if exists "mentor_sessions_select_related" on public.mentor_sessions;
create policy "mentor_sessions_select_related"
on public.mentor_sessions
for select
using (auth.uid() = mentor_id or auth.uid() = student_id);

drop policy if exists "payments_select_related" on public.payments;
create policy "payments_select_related"
on public.payments
for select
using (auth.uid() = mentor_id or auth.uid() = student_id);
