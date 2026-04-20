create table if not exists public.world_chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  content text not null,
  created_at timestamp default current_timestamp,
  updated_at timestamp default current_timestamp
);

create index if not exists idx_world_chat_messages_created_at
  on public.world_chat_messages(created_at desc);

create index if not exists idx_world_chat_messages_user_id
  on public.world_chat_messages(user_id); 

alter table if exists public.world_chat_messages enable row level security;
alter table if exists public.reports enable row level security;

drop policy if exists "world_chat_messages_select_authenticated" on public.world_chat_messages;
create policy "world_chat_messages_select_authenticated"
on public.world_chat_messages
for select
using (auth.uid() is not null);

drop policy if exists "world_chat_messages_insert_own" on public.world_chat_messages;
create policy "world_chat_messages_insert_own"
on public.world_chat_messages
for insert
with check (auth.uid() = user_id);

drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own"
on public.reports
for insert
with check (auth.uid() = reporter_id);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'world_chat_messages'
  ) then
    alter publication supabase_realtime add table public.world_chat_messages;
  end if;
end;
$$;

alter table public.world_chat_messages replica identity full;
