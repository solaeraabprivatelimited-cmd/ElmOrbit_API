alter table if exists public.notifications enable row level security;

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
on public.notifications
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.postpone_mentor_booking_and_notify(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor public.users%rowtype;
  v_booking public.mentor_bookings%rowtype;
  v_actor_id uuid := auth.uid();
  v_is_allowed boolean := false;
begin
  if v_actor_id is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_booking
  from public.mentor_bookings
  where id = p_booking_id;

  if not found then
    raise exception 'Booking not found';
  end if;

  select *
  into v_actor
  from public.users
  where id = v_actor_id;

  if not found then
    raise exception 'User not found';
  end if;

  v_is_allowed := v_booking.mentor_id = v_actor_id
    or (
      v_actor.role = 'mentor'
      and v_actor.name is not null
      and v_actor.name = v_booking.mentor_name
    );

  if not v_is_allowed then
    raise exception 'You are not allowed to postpone this booking';
  end if;

  insert into public.notifications (
    user_id,
    type,
    title,
    content,
    related_id,
    action_url
  )
  values (
    v_booking.student_id,
    'mentor_session_postponed',
    'Session Postponed',
    format(
      'Your session with %s scheduled for %s has been postponed. Please book a new slot.',
      coalesce(v_booking.mentor_name, 'your mentor'),
      coalesce(v_booking.selected_date_time, 'the selected time')
    ),
    v_booking.id,
    '/dashboard'
  );

  delete from public.mentor_bookings
  where id = v_booking.id;
end;
$$;

grant execute on function public.postpone_mentor_booking_and_notify(uuid) to authenticated;
