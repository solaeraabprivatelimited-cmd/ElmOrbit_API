-- Allow mentors to read mentor_bookings rows that match their public.users name.

alter table if exists public.mentor_bookings enable row level security;

drop policy if exists "mentor_bookings_select_mentor_match" on public.mentor_bookings;
create policy "mentor_bookings_select_mentor_match"
on public.mentor_bookings
for select
using (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role = 'mentor'
      and u.name = mentor_bookings.mentor_name
  )
);
