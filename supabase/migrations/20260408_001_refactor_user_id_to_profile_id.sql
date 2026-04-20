-- Refactor user_id to profile_id for tables that previously referenced public.users

-- Function to safely rename a column and its constraints if it exists
CREATE OR REPLACE FUNCTION safe_rename_user_id_to_profile_id(
  p_table_name TEXT,
  p_constraint_prefix TEXT
) RETURNS VOID AS $$
DECLARE
  fk_constraint_name TEXT;
  new_fk_constraint_name TEXT;
BEGIN
  -- Check if the user_id column exists
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = p_table_name
      AND column_name = 'user_id'
  ) THEN
    -- Find the foreign key constraint name
    SELECT tc.constraint_name
    INTO fk_constraint_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_name = p_table_name
      AND kcu.column_name = 'user_id'
      AND tc.table_schema = 'public';

    -- If a constraint is found, drop it
    IF fk_constraint_name IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I;', p_table_name, fk_constraint_name);
    END IF;

    -- Rename the column
    EXECUTE format('ALTER TABLE public.%I RENAME COLUMN user_id TO profile_id;', p_table_name);

    -- Add the new foreign key constraint referencing profiles(id)
    new_fk_constraint_name := p_constraint_prefix || '_profile_id_fkey';
    EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;', p_table_name, new_fk_constraint_name);

    -- Create an index on the new column
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_profile_id ON public.%I(profile_id);', p_table_name, p_table_name);
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Apply the refactoring to all relevant tables
SELECT safe_rename_user_id_to_profile_id('notes', 'notes');
SELECT safe_rename_user_id_to_profile_id('tasks', 'tasks');
SELECT safe_rename_user_id_to_profile_id('planner_reminders', 'planner_reminders');
SELECT safe_rename_user_id_to_profile_id('study_plans', 'study_plans');
SELECT safe_rename_user_id_to_profile_id('mood_checkins', 'mood_checkins');

-- Drop the helper function
DROP FUNCTION safe_rename_user_id_to_profile_id(TEXT, TEXT);
