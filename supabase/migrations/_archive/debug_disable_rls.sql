-- DEBUG: Temporarily disable RLS to confirm if it's the blocker
ALTER TABLE school_shared.bus_routes DISABLE ROW LEVEL SECURITY;

-- If this fixes the "No routes found" error in the app, 
-- we know the Policy was wrong or not applied correctly.
-- You can re-enable it later with: ALTER TABLE ... ENABLE ROW LEVEL SECURITY;
