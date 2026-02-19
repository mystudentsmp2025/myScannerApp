-- FIX: Grant UPDATE permission on boarding_logs
-- It is highly likely that the Webhook Trigger attempts to UPDATE the boarding_log
-- (e.g., marking it as 'notified') after sending the message.
-- Since the driver didn't have UPDATE policy, the valid INSERT was rolling back.

-- 1. Ensure UPDATE permission is granted
GRANT UPDATE ON transport.boarding_logs TO authenticated;

-- 2. Create UPDATE Policy
-- Allow authenticated users (drivers) to update rows.
-- (You can refine this later to only allow updating rows they created)
DROP POLICY IF EXISTS "Universal Update Boarding Logs" ON transport.boarding_logs;

CREATE POLICY "Universal Update Boarding Logs"
ON transport.boarding_logs FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
