-- Fix permissions for fetching routes
-- Run this in Supabase SQL Editor

-- 1. Grant USAGE on Schema (Critical if missed)
GRANT USAGE ON SCHEMA school_shared TO authenticated;

-- 2. Grant SELECT on the table
GRANT SELECT ON school_shared.bus_routes TO authenticated;

-- 2. Enable RLS (if not already)
ALTER TABLE school_shared.bus_routes ENABLE ROW LEVEL SECURITY;

-- 3. Create Policy to allow drivers to see ALL routes (or filter if needed)
-- For simplicity, let authenticated users read all routes for now.
DROP POLICY IF EXISTS "Allow read all routes" ON school_shared.bus_routes;

CREATE POLICY "Allow read all routes"
ON school_shared.bus_routes FOR SELECT
TO authenticated
USING (true);
