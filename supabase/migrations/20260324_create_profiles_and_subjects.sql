create extension if not exists pgcrypto;

-- Main profile table linked 1:1 with auth.users
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  avatar_url text,
  role text not null default 'student' check (role in ('student', 'mentor')),
  bio text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Subjects table for per-user subjects (students + mentors)
create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null,
  created_at timestamptz not null default now(),
  unique (profile_id, subject)
);

create index if not exists subjects_profile_id_idx on public.subjects(profile_id);

-- Keep updated_at fresh on profile updates
create or replace function public.set_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_profiles_updated_at();

-- Auto-create profile row on auth sign-up
create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _name text;
  _role text;
begin
  _name := coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1), 'User');
  _role := coalesce(new.raw_user_meta_data->>'role', 'student');

  if _role not in ('student', 'mentor') then
    _role := 'student';
  end if;

  insert into public.profiles (id, name, role, bio)
  values (new.id, _name, _role, '')
  on conflict (id) do update set
    name = excluded.name,
    role = excluded.role;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.handle_new_user_profile();

-- Enable Row Level Security
alter table public.profiles enable row level security;
alter table public.subjects enable row level security;

-- Drop policies if they exist (for re-runs)
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "subjects_select_own" on public.subjects;
drop policy if exists "subjects_insert_own" on public.subjects;
drop policy if exists "subjects_update_own" on public.subjects;
drop policy if exists "subjects_delete_own" on public.subjects;

-- Profiles policies
create policy "profiles_select_own"
on public.profiles
for select
using (auth.uid() = id);

create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- User can create own profile row (rare; mostly handled by trigger)
create policy "profiles_insert_own"
on public.profiles
for insert
with check (auth.uid() = id);

-- Subjects policies (owned through profile_id)
create policy "subjects_select_own"
on public.subjects
for select
using (auth.uid() = profile_id);

create policy "subjects_insert_own"
on public.subjects
for insert
with check (auth.uid() = profile_id);

create policy "subjects_update_own"
on public.subjects
for update
using (auth.uid() = profile_id)
with check (auth.uid() = profile_id);

create policy "subjects_delete_own"
on public.subjects
for delete
using (auth.uid() = profile_id);
