-- Normalize existing role data and make role constraint deterministic.
DO $$
DECLARE
	_c record;
BEGIN
	FOR _c IN
		SELECT c.conname
		FROM pg_constraint c
		JOIN pg_class t ON t.oid = c.conrelid
		JOIN pg_namespace n ON n.oid = t.relnamespace
		WHERE n.nspname = 'public'
			AND t.relname = 'profiles'
			AND c.contype = 'c'
			AND pg_get_constraintdef(c.oid) ILIKE '%role%'
	LOOP
		EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS %I', _c.conname);
	END LOOP;
END
$$;

UPDATE public.profiles
SET role = 'student'
WHERE role IS NULL
	 OR role = 'user'
	 OR role NOT IN ('student', 'mentor');

ALTER TABLE public.profiles
	ADD CONSTRAINT profiles_role_check
	CHECK (role IN ('student', 'mentor'));

CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
	_name text;
	_role text;
BEGIN
	_name := coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1), 'User');
	_role := coalesce(new.raw_user_meta_data->>'role', 'student');

	IF _role NOT IN ('student', 'mentor') THEN
		_role := 'student';
	END IF;

	INSERT INTO public.profiles (id, name, role, bio)
	VALUES (new.id, _name, _role, '')
	ON CONFLICT (id) DO UPDATE
		SET name = EXCLUDED.name,
				role = EXCLUDED.role;

	RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_profile
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_profile();
