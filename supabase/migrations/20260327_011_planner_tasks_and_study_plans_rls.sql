alter table if exists public.study_plans
  add column if not exists start_time time,
  add column if not exists end_time time,
  add column if not exists reminder varchar(100),
  add column if not exists priority varchar(50) default 'low';

alter table if exists public.study_plans
  drop constraint if exists study_plans_priority_check;

alter table if exists public.study_plans
  add constraint study_plans_priority_check
  check (priority in ('low', 'medium', 'high'));

alter table if exists public.planner_tasks enable row level security;
alter table if exists public.study_plans enable row level security;

drop policy if exists "planner_tasks_select_own" on public.planner_tasks;
create policy "planner_tasks_select_own"
on public.planner_tasks
for select
using (auth.uid() = user_id);

drop policy if exists "planner_tasks_insert_own" on public.planner_tasks;
create policy "planner_tasks_insert_own"
on public.planner_tasks
for insert
with check (auth.uid() = user_id);

drop policy if exists "planner_tasks_update_own" on public.planner_tasks;
create policy "planner_tasks_update_own"
on public.planner_tasks
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "planner_tasks_delete_own" on public.planner_tasks;
create policy "planner_tasks_delete_own"
on public.planner_tasks
for delete
using (auth.uid() = user_id);

drop policy if exists "study_plans_select_own" on public.study_plans;
create policy "study_plans_select_own"
on public.study_plans
for select
using (auth.uid() = user_id);

drop policy if exists "study_plans_insert_own" on public.study_plans;
create policy "study_plans_insert_own"
on public.study_plans
for insert
with check (auth.uid() = user_id);

drop policy if exists "study_plans_update_own" on public.study_plans;
create policy "study_plans_update_own"
on public.study_plans
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "study_plans_delete_own" on public.study_plans;
create policy "study_plans_delete_own"
on public.study_plans
for delete
using (auth.uid() = user_id);
