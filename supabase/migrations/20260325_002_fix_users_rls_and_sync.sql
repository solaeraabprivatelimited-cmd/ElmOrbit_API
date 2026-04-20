-- Ensure public.users stays in sync with auth.users and has usable RLS for app flows.

-- 1) Enable RLS on users table.
alter table if exists public.users enable row level security;

-- 2) Recreate users policies (idempotent).
drop policy if exists "users_select_authenticated" on public.users;
drop policy if exists "users_insert_own" on public.users;
drop policy if exists "users_update_own" on public.users;

-- Allow authenticated users to read basic user identity fields for room lists/chat joins.
create policy "users_select_authenticated"
on public.users
for select
using (auth.role() = 'authenticated');

-- Allow users to insert their own row only.
create policy "users_insert_own"
on public.users
for insert
with check (auth.uid() = id);

-- Allow users to update their own row only.
create policy "users_update_own"
on public.users
for update
using (auth.uid() = id)
with check (auth.uid() = id);
  
-- 3) Auto-sync auth.users -> public.users on sign-up.
create or replace function public.handle_new_auth_user_public_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _name text;
  _role text;
  _avatar text;
begin
  _name := coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1), 'User');
  _role := coalesce(new.raw_user_meta_data->>'role', 'student');
  _avatar := coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'avatar');

  if _role not in ('student', 'mentor') then
    _role := 'student';
  end if;

  insert into public.users (id, email, name, avatar_url, role, is_active, last_login_at)
  values (new.id, new.email, _name, _avatar, _role, true, now())
  on conflict (id) do update
    set email = excluded.email,
        name = excluded.name,
        avatar_url = excluded.avatar_url,
        role = excluded.role,
        is_active = true,
        last_login_at = now(),
        updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_public_user on auth.users;
create trigger on_auth_user_created_public_user
after insert on auth.users
for each row execute function public.handle_new_auth_user_public_user();

-- 4) Backfill any missing public.users rows for existing auth users.
insert into public.users (id, email, name, avatar_url, role, is_active, last_login_at)
select
  au.id,
  au.email,
  coalesce(au.raw_user_meta_data->>'name', split_part(au.email, '@', 1), 'User') as name,
  coalesce(au.raw_user_meta_data->>'avatar_url', au.raw_user_meta_data->>'avatar') as avatar_url,
  case
    when coalesce(au.raw_user_meta_data->>'role', 'student') in ('student', 'mentor')
      then au.raw_user_meta_data->>'role'
    else 'student'
  end as role,
  true,
  now()
from auth.users au
left join public.users pu on pu.id = au.id
where pu.id is null;
