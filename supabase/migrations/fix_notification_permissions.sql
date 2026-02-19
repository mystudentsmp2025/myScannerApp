-- Fix permissions for notifications_queue
-- Even if the table exists, we MUST grant permissions to the 'authenticated' role
-- so drivers can insert notifications for parents.

-- 1. Grant INSERT permission
GRANT INSERT ON public.notifications_queue TO authenticated;

-- 2. Ensure RLS is enabled
ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;

-- 3. Create a Policy that allows drivers to insert ANY notification
-- (Crucial: Driver's ID != Parent's User ID, so we need CHECK(true))
DROP POLICY IF EXISTS "Allow insert for authenticated" ON public.notifications_queue;

CREATE POLICY "Allow insert for authenticated"
ON public.notifications_queue FOR INSERT
TO authenticated
WITH CHECK (true);
