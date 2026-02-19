-- Fix RLS for transport.boarding_logs
-- The error "new row violates row-level security policy for table boarding_logs" 
-- means the driver doesn't have permission to INSERT.

-- 1. Ensure Schema Usage
GRANT USAGE ON SCHEMA transport TO authenticated;

-- 2. Grant Table Permissions
GRANT ALL ON transport.boarding_logs TO authenticated;

-- 3. Reset RLS Policies
ALTER TABLE transport.boarding_logs ENABLE ROW LEVEL SECURITY;

-- Remove existing policies to avoid conflicts
DROP POLICY IF EXISTS "Drivers can insert logs" ON transport.boarding_logs;
DROP POLICY IF EXISTS "Allow insert for all authenticated" ON transport.boarding_logs;
DROP POLICY IF EXISTS "Parents can view logs for their kids" ON transport.boarding_logs;

-- 4. Create Permissive INSERT Policy (Critical for Sync)
CREATE POLICY "Allow insert for all authenticated"
ON transport.boarding_logs FOR INSERT
TO authenticated
WITH CHECK (true);

-- 5. Create Permissive SELECT Policy (so they can see what they just inserted)
CREATE POLICY "Allow select for all authenticated"
ON transport.boarding_logs FOR SELECT
TO authenticated
USING (true);
