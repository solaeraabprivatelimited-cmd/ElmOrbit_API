create or replace function public.book_mentor_availability_slot(
  p_session_id uuid,
  p_duration_mins integer,
  p_payment_method text,
  p_booking_price numeric default null,
  p_mentor_subject text default null,
  p_payment_app text default null,
  p_upi_id text default null,
  p_bank_account_holder text default null,
  p_bank_name text default null,
  p_bank_account_number text default null,
  p_bank_ifsc_code text default null
)
returns public.mentor_bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid := auth.uid();
  v_session public.mentor_sessions%rowtype;
  v_mentor_name text;
  v_booking public.mentor_bookings%rowtype;
  v_duration_label text;
  v_remaining_mins integer;
begin
  if v_student_id is null then
    raise exception 'Authentication required';
  end if;

  if p_duration_mins is null or p_duration_mins < 60 then
    raise exception 'Minimum booking duration is 60 minutes';
  end if;

  if p_payment_method not in ('UPI', 'Bank') then
    raise exception 'Unsupported payment method';
  end if;

  select *
  into v_session
  from public.mentor_sessions
  where id = p_session_id
    and student_id is null
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Selected mentor slot is no longer available';
  end if;

  if p_duration_mins > v_session.duration_mins then
    raise exception 'Requested duration exceeds available mentor time';
  end if;

  select name
  into v_mentor_name
  from public.users
  where id = v_session.mentor_id;

  v_duration_label := case
    when p_duration_mins % 60 = 0 then
      concat((p_duration_mins / 60)::text, ' hour', case when p_duration_mins = 60 then '' else 's' end)
    else
      concat(p_duration_mins::text, ' mins')
  end;

  insert into public.mentor_bookings (
    student_id,
    mentor_id,
    mentor_name,
    mentor_subject,
    selected_date_time,
    duration,
    payment_method,
    payment_app,
    upi_id,
    bank_account_holder,
    bank_name,
    bank_account_number,
    bank_ifsc_code,
    booking_price,
    status
  )
  values (
    v_student_id,
    v_session.mentor_id,
    coalesce(v_mentor_name, 'Mentor'),
    coalesce(nullif(trim(p_mentor_subject), ''), 'General Mentoring'),
    to_char(v_session.scheduled_at, 'YYYY-MM-DD HH24:MI:SS'),
    v_duration_label,
    p_payment_method,
    nullif(trim(p_payment_app), ''),
    nullif(trim(p_upi_id), ''),
    nullif(trim(p_bank_account_holder), ''),
    nullif(trim(p_bank_name), ''),
    nullif(trim(p_bank_account_number), ''),
    nullif(trim(p_bank_ifsc_code), ''),
    coalesce(p_booking_price, 500.00),
    'pending'
  )
  returning *
  into v_booking;

  v_remaining_mins := v_session.duration_mins - p_duration_mins;

  if v_remaining_mins >= 60 then
    update public.mentor_sessions
    set
      scheduled_at = v_session.scheduled_at + make_interval(mins => p_duration_mins),
      duration_mins = v_remaining_mins,
      updated_at = now()
    where id = v_session.id;
  else
    delete from public.mentor_sessions
    where id = v_session.id;
  end if;

  return v_booking;
end;
$$;

grant execute on function public.book_mentor_availability_slot(
  uuid,
  integer,
  text,
  numeric,
  text,
  text,
  text,
  text,
  text,
  text,
  text
) to authenticated;
