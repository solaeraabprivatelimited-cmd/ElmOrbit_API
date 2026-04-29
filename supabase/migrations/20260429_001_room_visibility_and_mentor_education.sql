-- Persist room visibility and mentor education details.

alter table if exists public.webrtc_rooms
add column if not exists is_private boolean not null default false;

create index if not exists idx_webrtc_rooms_public_active
on public.webrtc_rooms (is_active, is_private, created_at desc);

alter table if exists public.profiles
add column if not exists education_details text not null default '',
add column if not exists qualifications text[] not null default '{}'::text[];

alter table if exists public.mentor_profiles
add column if not exists education_details text not null default '',
add column if not exists qualifications text[] not null default '{}'::text[];

create index if not exists idx_profiles_qualifications
on public.profiles using gin(qualifications);

create index if not exists idx_mentor_profiles_qualifications
on public.mentor_profiles using gin(qualifications);
