-- Add columns to profiles table for mentor profile support

-- Add mentor-specific columns if they don't exist
alter table if exists public.profiles
add column if not exists mentor_grade text default '5-10 years',
add column if not exists expertise text default '',
add column if not exists languages jsonb default '[]'::jsonb,
add column if not exists mentor_documents jsonb default '[]'::jsonb;

-- Create index on languages for faster queries
create index if not exists idx_profiles_languages on public.profiles using gin(languages);

-- Create index on mentor_documents for faster queries  
create index if not exists idx_profiles_mentor_documents on public.profiles using gin(mentor_documents);
