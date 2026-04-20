-- Room-specific notes (private per user) and room chat for WebRTC rooms

create table if not exists public.webrtc_room_notes (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.webrtc_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (room_id, user_id)
);

create index if not exists idx_webrtc_room_notes_room_id on public.webrtc_room_notes(room_id);
create index if not exists idx_webrtc_room_notes_user_id on public.webrtc_room_notes(user_id);
create index if not exists idx_webrtc_room_notes_updated_at on public.webrtc_room_notes(updated_at desc);

create table if not exists public.webrtc_room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.webrtc_rooms(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  message text not null check (char_length(message) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists idx_webrtc_room_messages_room_id_created_at
  on public.webrtc_room_messages(room_id, created_at desc);
create index if not exists idx_webrtc_room_messages_sender on public.webrtc_room_messages(sender_user_id);

alter table if exists public.webrtc_room_notes enable row level security;
alter table if exists public.webrtc_room_messages enable row level security;

drop policy if exists "webrtc_room_notes_select_own" on public.webrtc_room_notes;
create policy "webrtc_room_notes_select_own"
on public.webrtc_room_notes
for select
using (auth.uid() = user_id);

drop policy if exists "webrtc_room_notes_insert_own" on public.webrtc_room_notes;
create policy "webrtc_room_notes_insert_own"
on public.webrtc_room_notes
for insert
with check (auth.uid() = user_id);

drop policy if exists "webrtc_room_notes_update_own" on public.webrtc_room_notes;
create policy "webrtc_room_notes_update_own"
on public.webrtc_room_notes
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "webrtc_room_messages_select_participant" on public.webrtc_room_messages;
create policy "webrtc_room_messages_select_participant"
on public.webrtc_room_messages
for select
using (
  exists (
    select 1
    from public.webrtc_participants p
    where p.room_id = webrtc_room_messages.room_id
      and p.user_id = auth.uid()
      and p.disconnected_at is null
  )
);

drop policy if exists "webrtc_room_messages_insert_participant" on public.webrtc_room_messages;
create policy "webrtc_room_messages_insert_participant"
on public.webrtc_room_messages
for insert
with check (
  sender_user_id = auth.uid()
  and exists (
    select 1
    from public.webrtc_participants p
    where p.room_id = webrtc_room_messages.room_id
      and p.user_id = auth.uid()
      and p.disconnected_at is null
  )
);

do $$
begin
  execute 'alter publication supabase_realtime add table public.webrtc_room_messages';
exception when duplicate_object then
  null;
end $$;
