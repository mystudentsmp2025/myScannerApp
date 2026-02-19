-- FINAL PERMISSION FIX (Includes SELECT policies)
-- The missing link: Supabase SDK performs "INSERT ... RETURNING *".
-- If you can Insert but NOT Select the row you just inserted, it fails with 42501.

-- 1. Boarding Logs Permissions
ALTER TABLE transport.boarding_logs ENABLE ROW LEVEL SECURITY;
GRANT ALL ON transport.boarding_logs TO authenticated;

-- Ensure conflicting policies are gone
DROP POLICY IF EXISTS "Drivers can insert logs" ON transport.boarding_logs;
DROP POLICY IF EXISTS "Allow select for all authenticated" ON transport.boarding_logs;

-- CREATE INSERT POLICY
CREATE POLICY "Drivers can insert logs"
ON transport.boarding_logs FOR INSERT
TO authenticated
WITH CHECK (true);

-- CREATE SELECT POLICY (Critical for RETURNING clause)
CREATE POLICY "Drivers can select logs"
ON transport.boarding_logs FOR SELECT
TO authenticated
USING (true);


-- 2. Notifications Queue Permissions
ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.notifications_queue TO authenticated;

DROP POLICY IF EXISTS "Allow driver insert notification" ON public.notifications_queue;
DROP POLICY IF EXISTS "Allow driver select notification" ON public.notifications_queue;

-- CREATE INSERT POLICY
CREATE POLICY "Allow driver insert notification"
ON public.notifications_queue FOR INSERT
TO authenticated
WITH CHECK (true);

-- CREATE SELECT POLICY (If the trigger or something else needs it)
CREATE POLICY "Allow driver select notification"
ON public.notifications_queue FOR SELECT
TO authenticated
USING (true);


-- 3. Ensure Function Permissions
GRANT EXECUTE ON FUNCTION transport.trigger_notification_on_boarding() TO authenticated;
GRANT EXECUTE ON FUNCTION webhook_broadcast_notification() TO authenticated;

-- 4. Re-enable Triggers (just in case)
ALTER TABLE transport.boarding_logs ENABLE TRIGGER on_boarding_log_inserted;
ALTER TABLE public.notifications_queue ENABLE TRIGGER on_notification_queued;
