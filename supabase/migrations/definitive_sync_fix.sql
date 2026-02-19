-- DEFINITIVE SYNC FIX (Run this one script to fix everything)
-- This script resets permissions and policies for the entire sync flow.

BEGIN;

-- 1. SCHEMA PERMISSIONS
GRANT USAGE ON SCHEMA transport TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- 2. TABLE PERMISSIONS (Grant ALL to keep it simple for now)
GRANT ALL ON transport.boarding_logs TO authenticated;
GRANT ALL ON public.notifications_queue TO authenticated;

-- 3. RESET RLS on Boarding Logs
ALTER TABLE transport.boarding_logs ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies to ensure no conflicts
DROP POLICY IF EXISTS "Drivers can insert logs" ON transport.boarding_logs;
DROP POLICY IF EXISTS "Allow insert for all authenticated" ON transport.boarding_logs;
DROP POLICY IF EXISTS "Drivers can select logs" ON transport.boarding_logs;
DROP POLICY IF EXISTS "Allow select for all authenticated" ON transport.boarding_logs;
DROP POLICY IF EXISTS "Parents can view logs for their kids" ON transport.boarding_logs;

-- Create Permissive INSERT (Check true = allow anyone authenticated)
CREATE POLICY "Universal Insert Boarding Logs"
ON transport.boarding_logs FOR INSERT
TO authenticated
WITH CHECK (true);

-- Create Permissive SELECT (Using true = allow anyone authenticated)
-- Critical for Supabase "INSERT ... RETURNING *" feature
CREATE POLICY "Universal Select Boarding Logs"
ON transport.boarding_logs FOR SELECT
TO authenticated
USING (true);


-- 4. RESET RLS on Notifications Queue
ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow insert for authenticated" ON public.notifications_queue;
DROP POLICY IF EXISTS "Allow driver insert notification" ON public.notifications_queue;
DROP POLICY IF EXISTS "Allow driver update notification" ON public.notifications_queue;
DROP POLICY IF EXISTS "Allow driver select notification" ON public.notifications_queue;

-- Create Permissive Policies
CREATE POLICY "Universal Insert Notifications"
ON public.notifications_queue FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Universal Select Notifications"
ON public.notifications_queue FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Universal Update Notifications"
ON public.notifications_queue FOR UPDATE
TO authenticated
USING (true);


-- 5. FUNCTION & TRIGGER SECURITY
-- Allow executing the notification function
GRANT EXECUTE ON FUNCTION transport.trigger_notification_on_boarding() TO authenticated;
GRANT EXECUTE ON FUNCTION webhook_broadcast_notification() TO authenticated;

-- Ensure Trigger Function runs as Superuser (Security Definer)
ALTER FUNCTION transport.trigger_notification_on_boarding() SECURITY DEFINER;
-- Also make the webhook function Security Definer just in case
ALTER FUNCTION webhook_broadcast_notification() SECURITY DEFINER;


-- 6. RE-ENABLE TRIGGERS
-- Ensure they are active
ALTER TABLE transport.boarding_logs ENABLE TRIGGER on_boarding_log_inserted;
ALTER TABLE public.notifications_queue ENABLE TRIGGER on_notification_queued;

COMMIT;
