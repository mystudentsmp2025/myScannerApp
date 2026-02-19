-- RESTORE SECURITY (Safe Version)
-- Now that we confirmed the "Data" is fine (insert worked locally),
-- we apply the correct policies so it works SECURELY.

-- 1. Re-enable RLS on boarding_logs
ALTER TABLE transport.boarding_logs ENABLE ROW LEVEL SECURITY;

-- 2. Drop the old conflicting policies again (just in case)
DROP POLICY IF EXISTS "Allow insert for all authenticated" ON transport.boarding_logs;
DROP POLICY IF EXISTS "Drivers can insert logs" ON transport.boarding_logs;

-- 3. Create the working Policy
CREATE POLICY "Drivers can insert logs"
ON transport.boarding_logs FOR INSERT
TO authenticated
WITH CHECK (true);

-- 4. Re-create the Trigger (but check permissions first)
-- Ensure 'authenticated' has permission to execute the function
GRANT EXECUTE ON FUNCTION transport.trigger_notification_on_boarding() TO authenticated;

-- Re-attach trigger
DROP TRIGGER IF EXISTS on_boarding_log_inserted ON transport.boarding_logs;
CREATE TRIGGER on_boarding_log_inserted
AFTER INSERT ON transport.boarding_logs
FOR EACH ROW
EXECUTE FUNCTION transport.trigger_notification_on_boarding();

-- 5. Ensure notifications_queue is writable (The Trigger writes here!)
GRANT INSERT ON public.notifications_queue TO authenticated;
ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow driver insert notification" ON public.notifications_queue;
CREATE POLICY "Allow driver insert notification"
ON public.notifications_queue FOR INSERT
TO authenticated
WITH CHECK (true);

-- 6. CRITICAL: Re-enable the Webhook Trigger
ALTER TABLE public.notifications_queue ENABLE TRIGGER on_notification_queued;