-- FIX: Grant UPDATE permission on notifications_queue
-- The webhook trigger likely updates the 'status' column (to 'processing'/'sent').
-- If the driver triggers it, they need UPDATE permission too!

GRANT ALL ON public.notifications_queue TO authenticated;

-- Ensure Update Policy exists
DROP POLICY IF EXISTS "Allow driver update notification" ON public.notifications_queue;

CREATE POLICY "Allow driver update notification"
ON public.notifications_queue FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
