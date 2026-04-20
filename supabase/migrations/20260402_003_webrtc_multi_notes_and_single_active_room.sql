-- Multi-note support per room/user + stricter one-active-room semantics at API level

create table if not exists public.webrtc_room_note_entries (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.webrtc_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  heading text not null default 'Untitled note' check (char_length(heading) between 1 and 160),
  body text not null default '' check (char_length(body) <= 20000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_webrtc_room_note_entries_room_user
  on public.webrtc_room_note_entries(room_id, user_id);

create index if not exists idx_webrtc_room_note_entries_updated_at
  on public.webrtc_room_note_entries(updated_at desc);

alter table if exists public.webrtc_room_note_entries enable row level security;

drop policy if exists "webrtc_room_note_entries_select_own" on public.webrtc_room_note_entries;
create policy "webrtc_room_note_entries_select_own"
on public.webrtc_room_note_entries
for select
using (auth.uid() = user_id);

drop policy if exists "webrtc_room_note_entries_insert_own" on public.webrtc_room_note_entries;
create policy "webrtc_room_note_entries_insert_own"
on public.webrtc_room_note_entries
for insert
with check (auth.uid() = user_id);

drop policy if exists "webrtc_room_note_entries_update_own" on public.webrtc_room_note_entries;
create policy "webrtc_room_note_entries_update_own"
on public.webrtc_room_note_entries
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "webrtc_room_note_entries_delete_own" on public.webrtc_room_note_entries;
create policy "webrtc_room_note_entries_delete_own"
on public.webrtc_room_note_entries
for delete
using (auth.uid() = user_id);

-- Optional one-time backfill from legacy single-note table to first structured note.
insert into public.webrtc_room_note_entries (room_id, user_id, heading, body, created_at, updated_at)
select n.room_id, n.user_id, 'Room note', n.content, n.created_at, n.updated_at
from public.webrtc_room_notes n
where coalesce(trim(n.content), '') <> ''
  and not exists (
    select 1
    from public.webrtc_room_note_entries e
    where e.room_id = n.room_id
      and e.user_id = n.user_id
      and e.heading = 'Room note'
      and e.body = n.content
  );

-- Keep at most one active participant row per user.
with ranked as (
  select
    id,
    row_number() over (
      partition by user_id
      order by
        coalesce(last_heartbeat, joined_at) desc nulls last,
        joined_at desc nulls last
    ) as rn
  from public.webrtc_participants
  where disconnected_at is null
)
update public.webrtc_participants p
set disconnected_at = now(),
    connection_state = 'disconnected'
from ranked r
where p.id = r.id
  and r.rn > 1;

create unique index if not exists ux_webrtc_participants_active_user
  on public.webrtc_participants(user_id)
  where disconnected_at is null;
