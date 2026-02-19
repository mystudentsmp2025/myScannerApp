-- EMERGENCY UNBLOCK SCRIPT
-- This will disable security checks to confirm if the Insert works at all.

-- 1. Disable RLS on the table (Allows ANY insert by authenticated user)
ALTER TABLE transport.boarding_logs DISABLE ROW LEVEL SECURITY;

-- 2. Drop the trigger that sends notifications (Eliminates side-effects)
DROP TRIGGER IF EXISTS on_boarding_log_inserted ON transport.boarding_logs;

-- 3. Verify Schema Permissions again
GRANT USAGE ON SCHEMA transport TO authenticated;
GRANT ALL ON transport.boarding_logs TO authenticated;
