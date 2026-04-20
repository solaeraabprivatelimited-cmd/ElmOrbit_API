-- Store mentor_id on bookings so mentor pages can resolve purchases reliably.

alter table if exists public.mentor_bookings
  add column if not exists mentor_id uuid references public.users(id) on delete set null;

create index if not exists idx_mentor_bookings_mentor_id
  on public.mentor_bookings(mentor_id);

-- Backfill mentor_id for existing rows by matching mentor_name to users.name for mentor accounts.
update public.mentor_bookings mb
set mentor_id = u.id
from public.users u
where mb.mentor_id is null
  and u.role = 'mentor'
  and u.name = mb.mentor_name;

drop policy if exists "mentor_bookings_select_mentor_match" on public.mentor_bookings;
create policy "mentor_bookings_select_mentor_match"
on public.mentor_bookings
for select
using (
  mentor_id = auth.uid()
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role = 'mentor'
      and u.name = mentor_bookings.mentor_name
  )
);
