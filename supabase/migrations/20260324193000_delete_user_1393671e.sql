-- Remove a specific user and related app data.
-- Deleting from auth.users cascades to public.profiles via FK.

DELETE FROM auth.users
WHERE id = '1393671e-5f2d-4e7d-8f13-d1af4292c846';

-- Clean up KV keys for this user if the KV table exists.
DO $$
BEGIN
  IF to_regclass('public.kv_store_a0923c49') IS NOT NULL THEN
    DELETE FROM public.kv_store_a0923c49
    WHERE key = 'user:1393671e-5f2d-4e7d-8f13-d1af4292c846:profile'
       OR key = 'user:1393671e-5f2d-4e7d-8f13-d1af4292c846:notes'
       OR key = 'user:1393671e-5f2d-4e7d-8f13-d1af4292c846:tasks'
       OR key = 'user:1393671e-5f2d-4e7d-8f13-d1af4292c846:reminders'
       OR key = 'user:1393671e-5f2d-4e7d-8f13-d1af4292c846:study_plans'
       OR key = 'user:1393671e-5f2d-4e7d-8f13-d1af4292c846:notifications'
       OR key = 'user:1393671e-5f2d-4e7d-8f13-d1af4292c846:mood_checkins'
       OR key = 'user:1393671e-5f2d-4e7d-8f13-d1af4292c846:study_sessions';
  END IF;
END
$$;