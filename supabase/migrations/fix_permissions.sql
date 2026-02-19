-- Run this script in Supabase SQL Editor to fix the 42501 Permission Denied error

-- 1. Grant USAGE on the schema
GRANT USAGE ON SCHEMA transport TO authenticated, anon;

-- 2. Grant SELECT on the view
GRANT SELECT ON transport.roster_view TO authenticated, anon;

-- 3. Grant ALL on the logs table (for inserting logs)
GRANT ALL ON transport.boarding_logs TO authenticated, anon;

-- 4. Ensure sequence (id) permissions if applicable (though logs use gen_random_uuid)
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA transport TO authenticated, anon;
