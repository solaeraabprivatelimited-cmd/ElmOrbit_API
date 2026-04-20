-- ============================================================================
-- RPC: Create Mentor Session Room
-- ============================================================================
-- Called when booking is confirmed
-- Generates a private room accessible only to mentor and student

create or replace function public.create_mentor_session_room(
  p_booking_id uuid
)
returns public.mentor_session_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.mentor_bookings%rowtype;
  v_room public.mentor_session_rooms%rowtype;
  v_scheduled_start timestamp;
  v_scheduled_end timestamp;
  v_room_name text;
  v_mentor_name text;
  v_duration_mins integer;
begin
  -- Fetch the booking
  select *
  into v_booking
  from public.mentor_bookings
  where id = p_booking_id
  for update;

  if not found then
    raise exception 'Booking not found';
  end if;

  if v_booking.status != 'confirmed' then
    raise exception 'Booking must be confirmed to create a room (current: %)', v_booking.status;
  end if;

  -- Check if room already exists for this booking
  if exists (
    select 1 from public.mentor_session_rooms
    where booking_id = p_booking_id
  ) then
    raise exception 'Room already exists for this booking';
  end if;

  -- Parse scheduled date/time from booking
  -- Format: "YYYY-MM-DD HH:MM:SS"
  begin
    v_scheduled_start := to_timestamp(v_booking.selected_date_time, 'YYYY-MM-DD HH24:MI:SS');
  exception when others then
    raise exception 'Invalid date/time format: %', v_booking.selected_date_time;
  end;
  
  -- Parse duration from booking.duration (e.g., "1 hour", "2 hours", "90 mins")
  v_duration_mins := case
    when v_booking.duration ilike '%hour%' then
      (regexp_matches(v_booking.duration, '(\d+)', 'g'))[1]::integer * 60
    when v_booking.duration ilike '%min%' then
      (regexp_matches(v_booking.duration, '(\d+)', 'g'))[1]::integer
    else 60  -- default 1 hour
  end;

  v_scheduled_end := v_scheduled_start + make_interval(mins => v_duration_mins);

  -- Get mentor name
  select name
  into v_mentor_name
  from public.users
  where id = v_booking.mentor_id;

  if v_mentor_name is null then
    v_mentor_name := 'Mentor';
  end if;

  -- Generate room name: "Mentor Session - [MentorName]"
  v_room_name := format('Mentor Session - %s', v_mentor_name);

  -- Create the room
  insert into public.mentor_session_rooms (
    booking_id,
    mentor_id,
    student_id,
    room_name,
    scheduled_start,
    scheduled_end,
    status
  )
  values (
    v_booking.id,
    v_booking.mentor_id,
    v_booking.student_id,
    v_room_name,
    v_scheduled_start,
    v_scheduled_end,
    'pending'
  )
  returning *
  into v_room;

  return v_room;
end;
$$;

grant execute on function public.create_mentor_session_room(uuid) to authenticated;

-- ============================================================================
-- RPC: Mark Room as Active
-- ============================================================================
-- Called when mentor joins the room

create or replace function public.start_mentor_session_room(
  p_room_id uuid
)
returns public.mentor_session_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.mentor_session_rooms%rowtype;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_room
  from public.mentor_session_rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  -- Only mentor or student can start the room
  if v_room.mentor_id != v_user_id and v_room.student_id != v_user_id then
    raise exception 'You are not authorized to access this room';
  end if;

  update public.mentor_session_rooms
  set
    status = 'active',
    actual_start = coalesce(actual_start, now()),
    updated_at = now()
  where id = p_room_id
  returning *
  into v_room;

  return v_room;
end;
$$;

grant execute on function public.start_mentor_session_room(uuid) to authenticated;

-- ============================================================================
-- RPC: End Mentor Session Room
-- ============================================================================
-- Called when mentor leaves / session ends

create or replace function public.end_mentor_session_room(
  p_room_id uuid
)
returns public.mentor_session_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.mentor_session_rooms%rowtype;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_room
  from public.mentor_session_rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  -- Only mentor or student can end the room
  if v_room.mentor_id != v_user_id and v_room.student_id != v_user_id then
    raise exception 'You are not authorized to access this room';
  end if;

  update public.mentor_session_rooms
  set
    status = 'completed',
    actual_end = now(),
    duration_mins = extract(epoch from (now() - coalesce(actual_start, scheduled_start))) / 60,
    updated_at = now()
  where id = p_room_id
  returning *
  into v_room;

  return v_room;
end;
$$;

grant execute on function public.end_mentor_session_room(uuid) to authenticated;

-- ============================================================================
-- RPC: Cancel Mentor Session Room
-- ============================================================================
-- Called when booking is cancelled

create or replace function public.cancel_mentor_session_room(
  p_room_id uuid
)
returns public.mentor_session_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.mentor_session_rooms%rowtype;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_room
  from public.mentor_session_rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  -- Only mentor or student can cancel the room
  if v_room.mentor_id != v_user_id and v_room.student_id != v_user_id then
    raise exception 'You are not authorized to cancel this room';
  end if;

  update public.mentor_session_rooms
  set
    status = 'cancelled',
    updated_at = now()
  where id = p_room_id
  returning *
  into v_room;

  return v_room;
end;
$$;

grant execute on function public.cancel_mentor_session_room(uuid) to authenticated;
