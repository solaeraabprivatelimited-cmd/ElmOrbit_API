-- RLS policies for session_ratings table
-- Required for MentorProfileSettings to read real avg ratings

alter table if exists public.session_ratings enable row level security;

-- Mentor can read all ratings for their own sessions
drop policy if exists "session_ratings_select_mentor" on public.session_ratings;
create policy "session_ratings_select_mentor"
on public.session_ratings
for select
using (auth.uid() = mentor_id);

-- Student can read ratings they submitted
drop policy if exists "session_ratings_select_student" on public.session_ratings;
create policy "session_ratings_select_student"
on public.session_ratings
for select
using (auth.uid() = student_id);

-- Student can insert a rating for a session they attended
drop policy if exists "session_ratings_insert_student" on public.session_ratings;
create policy "session_ratings_insert_student"
on public.session_ratings
for insert
with check (
  auth.uid() = student_id
  and exists (
    select 1
    from public.mentor_sessions ms
    where ms.id = session_ratings.session_id
      and ms.student_id = auth.uid()
      and ms.status = 'completed'
  )
);

-- Student can update their own rating
drop policy if exists "session_ratings_update_student" on public.session_ratings;
create policy "session_ratings_update_student"
on public.session_ratings
for update
using (auth.uid() = student_id)
with check (auth.uid() = student_id);
