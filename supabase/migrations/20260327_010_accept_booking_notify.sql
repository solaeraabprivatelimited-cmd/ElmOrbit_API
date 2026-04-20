create or replace function public.accept_mentor_booking_and_notify(p_booking_id uuid)
returns public.mentor_bookings
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
  where id = p_booking_id
  for update;

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
    raise exception 'You are not allowed to accept this booking';
  end if;

  update public.mentor_bookings
  set
    status = 'confirmed',
    updated_at = now()
  where id = v_booking.id
  returning *
  into v_booking;

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
    'mentor_session_accepted',
    'Session Accepted',
    format(
      'Your session with %s on %s has been accepted.',
      coalesce(v_booking.mentor_name, 'your mentor'),
      coalesce(v_booking.selected_date_time, 'the selected time')
    ),
    v_booking.id,
    '/dashboard'
  );

  return v_booking;
end;
$$;

grant execute on function public.accept_mentor_booking_and_notify(uuid) to authenticated;
