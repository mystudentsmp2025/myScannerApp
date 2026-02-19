-- Fix permissions for webhook_broadcast_notification
-- The driver (authenticated user) triggers this via INSERT on notifications_queue.
-- If they don't have permission to execute it or perform the network call inside, the INSERT fails.

-- 1. Grant EXECUTE to authenticated users
GRANT EXECUTE ON FUNCTION webhook_broadcast_notification() TO authenticated;
GRANT EXECUTE ON FUNCTION webhook_broadcast_notification() TO service_role;
GRANT EXECUTE ON FUNCTION webhook_broadcast_notification() TO anon;

-- 2. Ideally, make the function SECURITY DEFINER (runs as superuser) 
-- causing it to ignore RLS/permissions of the caller for its internal logic.
-- Since we don't have the original definition to alter, 
-- we will try ALTER FUNCTION ... SECURITY DEFINER.
-- Note: This might fail if the function signature or owner prevents it, 
-- but it's worth trying.
ALTER FUNCTION webhook_broadcast_notification() SECURITY DEFINER;

-- 3. Also grant usage on net schema if it uses pg_net (common for webhooks)
-- GRANT USAGE ON SCHEMA net TO authenticated; -- Often needed but risky if exposing raw net calls.
-- Usually SECURITY DEFINER handles this.
