-- ================================================================================
-- MASTER MIGRATION - myScannerApp Transport Module
-- This file consolidates all previous migrations into a single, runnable script.
-- It is fully idempotent (safe to run multiple times).
-- ================================================================================

BEGIN;

-- ============================================================
-- SECTION 1: EXTENSIONS & SCHEMAS
-- ============================================================

CREATE SCHEMA IF NOT EXISTS transport;
GRANT USAGE ON SCHEMA transport TO authenticated, anon;

-- PostGIS for geographic calculations (if needed externally)
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;


-- ============================================================
-- SECTION 2: ENUM TYPES
-- ============================================================

DO $$ BEGIN
    CREATE TYPE transport.boarding_status AS ENUM ('onboarded', 'offboarded');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;


-- ============================================================
-- SECTION 3: TABLES
-- ============================================================

-- 3a. public.notifications_queue
CREATE TABLE IF NOT EXISTS public.notifications_queue (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id    UUID REFERENCES auth.users(id) NOT NULL,
    title      TEXT NOT NULL,
    body       TEXT NOT NULL,
    data       JSONB DEFAULT '{}'::jsonb,
    status     TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3b. transport.boarding_logs (final schema)
CREATE TABLE IF NOT EXISTS transport.boarding_logs (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id     TEXT NOT NULL,
    parent_user_id UUID REFERENCES auth.users(id),
    status         transport.boarding_status NOT NULL,
    -- Separate lat/long columns (location GEOGRAPHY column removed)
    latitude       NUMERIC(10, 8),
    longitude      NUMERIC(11, 8),
    stop_name      TEXT,          -- Auto-populated by trigger
    scanned_at     TIMESTAMPTZ DEFAULT NOW(),
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- DROP old location column if it still exists from original migration
ALTER TABLE transport.boarding_logs DROP COLUMN IF EXISTS location;


-- ============================================================
-- SECTION 4: PERMISSIONS & RLS
-- ============================================================

-- notifications_queue: open (trigger uses SECURITY DEFINER, driver inserts directly)
GRANT ALL ON public.notifications_queue TO authenticated, service_role, anon;
ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow insert for authenticated"        ON public.notifications_queue;
DROP POLICY IF EXISTS "Allow select own notifications"        ON public.notifications_queue;
CREATE POLICY "Allow insert for authenticated"  ON public.notifications_queue FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow select own notifications"  ON public.notifications_queue FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- boarding_logs: open (RLS disabled; application-level auth handles security)
ALTER TABLE transport.boarding_logs DISABLE ROW LEVEL SECURITY;
GRANT ALL ON transport.boarding_logs TO authenticated, service_role;

-- boarding_events (school_shared schema - already exists)
GRANT ALL ON school_shared.boarding_events TO authenticated;
ALTER TABLE school_shared.boarding_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Drivers can insert events" ON school_shared.boarding_events;
CREATE POLICY "Drivers can insert events" ON school_shared.boarding_events FOR INSERT TO authenticated WITH CHECK (true);


-- ============================================================
-- SECTION 5: VIEWS
-- ============================================================

-- roster_view: Consolidates student + transport + parent data for the trigger and app
DROP VIEW IF EXISTS transport.roster_view;

CREATE OR REPLACE VIEW transport.roster_view AS
SELECT
    s.id                AS student_id,
    s.student_custom_id,
    s.first_name,
    s.last_name,

    -- Grade & Section
    c.name              AS grade,
    cs.section_name     AS section,

    -- Photo
    'https://jqpahjeymfukkzwiapog.supabase.co/storage/v1/object/public/profile_pictures/' || s.id AS photo_url,

    -- Transport
    ba.route_id         AS route_id,
    br.route_name       AS route_name,
    ba.bus_id           AS bus_id,
    b.bus_number        AS bus_number,

    -- Driver
    (e.first_name || ' ' || e.last_name) AS driver_name,
    dp.mobile_number    AS driver_mobile,

    -- Pickup Stop
    ba.pickup_stop      AS pickup_stop_id,
    COALESCE(pickup_stop.name, ba.pickup_stop) AS pickup_stop_name,
    CASE
        WHEN pickup_stop.lat IS NOT NULL AND pickup_stop.lng IS NOT NULL
        THEN ('POINT(' || pickup_stop.lng || ' ' || pickup_stop.lat || ')')::GEOGRAPHY
        ELSE NULL
    END AS pickup_location,
    pickup_stop.scheduled_time AS pickup_time,

    -- Drop Stop
    ba.dropoff_stop     AS drop_stop_id,
    COALESCE(drop_stop.name, ba.dropoff_stop) AS drop_stop_name,
    CASE
        WHEN drop_stop.lat IS NOT NULL AND drop_stop.lng IS NOT NULL
        THEN ('POINT(' || drop_stop.lng || ' ' || drop_stop.lat || ')')::GEOGRAPHY
        ELSE NULL
    END AS drop_location,
    drop_stop.scheduled_time AS drop_time,

    -- Parent Info
    p.id                AS parent_user_id,
    p.mobile_number     AS parent_mobile

FROM school_shared.students s
LEFT JOIN school_shared.class_sections cs      ON s.section_id = cs.id
LEFT JOIN school_shared.classes c              ON cs.class_id = c.id
LEFT JOIN school_shared.bus_assignments ba     ON s.id = ba.student_id
LEFT JOIN school_shared.bus_routes br          ON ba.route_id = br.id
LEFT JOIN school_shared.buses b                ON ba.bus_id = b.id
LEFT JOIN school_shared.employees e            ON b.driver_id = e.id AND e.role = 'driver'
LEFT JOIN mystudentapp.profiles dp             ON e.email = dp.email
LEFT JOIN LATERAL (
    SELECT
        el ->> 'name'            AS name,
        (el ->> 'latitude')::numeric  AS lat,
        (el ->> 'longitude')::numeric AS lng,
        el ->> 'scheduled_time'  AS scheduled_time
    FROM jsonb_array_elements(br.stops::jsonb) el
    WHERE (el ->> 'name') = ba.pickup_stop
) pickup_stop ON true
LEFT JOIN LATERAL (
    SELECT
        el ->> 'name'            AS name,
        (el ->> 'latitude')::numeric  AS lat,
        (el ->> 'longitude')::numeric AS lng,
        el ->> 'scheduled_time'  AS scheduled_time
    FROM jsonb_array_elements(br.stops::jsonb) el
    WHERE (el ->> 'name') = ba.dropoff_stop
) drop_stop ON true
LEFT JOIN school_shared.parent_student ps      ON s.id = ps.student_id AND ps.relation = 'Father'
LEFT JOIN mystudentapp.profiles p              ON ps.user_id = p.id
WHERE ba.route_id IS NOT NULL;

GRANT SELECT ON transport.roster_view TO authenticated;


-- ============================================================
-- SECTION 6: HELPER FUNCTIONS
-- ============================================================

-- Finds the closest bus stop for a given route and GPS coordinate
CREATE OR REPLACE FUNCTION transport.get_closest_stop(p_route_id UUID, p_lat NUMERIC, p_lng NUMERIC)
RETURNS TEXT AS $$
DECLARE
    v_stops     JSONB;
    v_stop_name TEXT;
    v_min_dist  FLOAT := 1000000;
    v_dist      FLOAT;
    v_stop      RECORD;
BEGIN
    SELECT stops INTO v_stops
    FROM school_shared.bus_routes
    WHERE id = p_route_id;

    IF v_stops IS NULL OR p_lat IS NULL OR p_lng IS NULL THEN
        RETURN 'Unknown Stop';
    END IF;

    FOR v_stop IN
        SELECT * FROM jsonb_to_recordset(v_stops) AS x(name TEXT, latitude NUMERIC, longitude NUMERIC)
    LOOP
        v_dist := sqrt(power(v_stop.latitude - p_lat, 2) + power(v_stop.longitude - p_lng, 2));
        IF v_dist < v_min_dist THEN
            v_min_dist  := v_dist;
            v_stop_name := v_stop.name;
        END IF;
    END LOOP;

    RETURN COALESCE(v_stop_name, 'Unknown Stop');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- SECTION 7: TRIGGER FUNCTIONS
-- ============================================================

-- 7a. BEFORE INSERT: Enriches the log row with the calculated stop_name
CREATE OR REPLACE FUNCTION transport.enrich_boarding_log()
RETURNS TRIGGER AS $$
DECLARE
    v_route_id  UUID;
    v_stop_name TEXT;
BEGIN
    SELECT route_id INTO v_route_id
    FROM transport.roster_view
    WHERE student_id = NEW.student_id::uuid
    LIMIT 1;

    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL AND v_route_id IS NOT NULL THEN
        v_stop_name := transport.get_closest_stop(v_route_id, NEW.latitude, NEW.longitude);
    ELSE
        v_stop_name := 'Unknown Stop';
    END IF;

    NEW.stop_name := v_stop_name;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7b. AFTER INSERT: Sends notification + inserts boarding_event
CREATE OR REPLACE FUNCTION transport.trigger_notification_on_boarding()
RETURNS TRIGGER AS $$
DECLARE
    v_student_name TEXT;
    v_parent_id    UUID;
    v_bus_id       UUID;
    v_event_type   TEXT;
    v_title        TEXT;
    v_body         TEXT;
BEGIN
    -- Fetch student info from roster view
    SELECT
        first_name || ' ' || last_name,
        parent_user_id,
        bus_id
    INTO
        v_student_name,
        v_parent_id,
        v_bus_id
    FROM transport.roster_view
    WHERE student_id = NEW.student_id::uuid
    LIMIT 1;

    -- Fallback: use embedded parent_user_id from the log row
    IF v_parent_id IS NULL AND NEW.parent_user_id IS NOT NULL THEN
        v_parent_id := NEW.parent_user_id;
    END IF;

    -- Determine event type
    IF NEW.status = 'onboarded' THEN
        v_event_type := 'board';
    ELSE
        v_event_type := 'deboard';
    END IF;

    -- Write to school_shared.boarding_events (for parent app)
    IF v_bus_id IS NOT NULL THEN
        INSERT INTO school_shared.boarding_events (
            student_id, bus_id, event_type, location_lat, location_lng, timestamp
        ) VALUES (
            NEW.student_id::uuid,
            v_bus_id,
            v_event_type,
            NEW.latitude,
            NEW.longitude,
            NEW.scanned_at
        );
    END IF;

    -- Skip notification if no parent found
    IF v_parent_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Format notification using the pre-calculated stop_name
    IF NEW.status = 'onboarded' THEN
        v_title := 'Bus Alert: ' || v_student_name || ' Boarded 🚌';
        v_body  := v_student_name || ' has boarded the bus at ' || COALESCE(NEW.stop_name, 'Unknown Stop') || '.';
    ELSE
        v_title := 'Bus Alert: ' || v_student_name || ' Offboarded 🏫';
        v_body  := v_student_name || ' has reached ' || COALESCE(NEW.stop_name, 'Unknown Stop') || '.';
    END IF;

    -- Queue notification (wrapped in sub-transaction so failures don't abort the insert)
    BEGIN
        INSERT INTO public.notifications_queue (user_id, title, body, data)
        VALUES (
            v_parent_id,
            v_title,
            v_body,
            jsonb_build_object(
                'student_id', NEW.student_id,
                'log_id',     NEW.id,
                'status',     NEW.status,
                'stop_name',  NEW.stop_name,
                'type',       'transport_update'
            )
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to queue notification: %', SQLERRM;
    END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- SECTION 8: TRIGGERS
-- ============================================================

-- 8a. BEFORE INSERT — populate stop_name
DROP TRIGGER IF EXISTS trigger_enrich_boarding_log         ON transport.boarding_logs;
CREATE TRIGGER trigger_enrich_boarding_log
BEFORE INSERT ON transport.boarding_logs
FOR EACH ROW
EXECUTE FUNCTION transport.enrich_boarding_log();

-- 8b. AFTER INSERT — notify parent + write boarding event
DROP TRIGGER IF EXISTS on_boarding_log_inserted             ON transport.boarding_logs;
CREATE TRIGGER on_boarding_log_inserted
AFTER INSERT ON transport.boarding_logs
FOR EACH ROW
EXECUTE FUNCTION transport.trigger_notification_on_boarding();

COMMIT;
