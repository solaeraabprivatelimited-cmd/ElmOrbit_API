alter table if exists public.motivation_posts
  add column if not exists title varchar(255),
  add column if not exists ui_type varchar(50);

alter table if exists public.motivation_posts
  drop constraint if exists motivation_posts_ui_type_check;

alter table if exists public.motivation_posts
  add constraint motivation_posts_ui_type_check
  check (ui_type is null or ui_type in ('quote', 'story'));

alter table if exists public.motivation_posts enable row level security;

drop policy if exists "motivation_posts_select_authenticated" on public.motivation_posts;
create policy "motivation_posts_select_authenticated"
on public.motivation_posts
for select
using (auth.uid() is not null);

drop policy if exists "motivation_posts_insert_own" on public.motivation_posts;
create policy "motivation_posts_insert_own"
on public.motivation_posts
for insert
with check (auth.uid() = user_id);
