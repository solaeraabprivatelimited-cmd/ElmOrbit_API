create table if not exists public.planner_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title varchar(255) not null,
  frequency varchar(100) default 'Daily',
  reminder_date date,
  reminder_time time,
  status varchar(50) not null default 'active' check (status in ('active', 'completed', 'cancelled')),
  completed_at timestamp,
  created_at timestamp default current_timestamp,
  updated_at timestamp default current_timestamp
);

create index if not exists idx_planner_reminders_user_id
  on public.planner_reminders(user_id);

create index if not exists idx_planner_reminders_status
  on public.planner_reminders(status);

create index if not exists idx_planner_reminders_reminder_date
  on public.planner_reminders(reminder_date);

alter table if exists public.planner_reminders enable row level security;

drop policy if exists "planner_reminders_select_own" on public.planner_reminders;
create policy "planner_reminders_select_own"
on public.planner_reminders
for select
using (auth.uid() = user_id);

drop policy if exists "planner_reminders_insert_own" on public.planner_reminders;
create policy "planner_reminders_insert_own"
on public.planner_reminders
for insert
with check (auth.uid() = user_id);

drop policy if exists "planner_reminders_update_own" on public.planner_reminders;
create policy "planner_reminders_update_own"
on public.planner_reminders
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "planner_reminders_delete_own" on public.planner_reminders;
create policy "planner_reminders_delete_own"
on public.planner_reminders
for delete
using (auth.uid() = user_id);
