alter table if exists public.notifications enable row level security;

drop policy if exists "notifications_insert_own" on public.notifications;
create policy "notifications_insert_own"
on public.notifications
for insert
with check (auth.uid() = user_id);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;

alter table public.notifications replica identity full;
