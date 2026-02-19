-- ENHANCEMENT: Notifications & Boarding Events (Revised v2)

BEGIN;

-- 1. Modify transport.boarding_logs
-- Add separate lat/long columns.
ALTER TABLE transport.boarding_logs ADD COLUMN IF NOT EXISTS latitude numeric(10, 8);
ALTER TABLE transport.boarding_logs ADD COLUMN IF NOT EXISTS longitude numeric(11, 8);


-- 2. UPDATE VIEW: transport.roster_view
-- relevant changes: Added 'bus_id' so the trigger can use it.
-- DROP first to avoid "cannot change name of view column" error
DROP VIEW IF EXISTS transport.roster_view;

CREATE OR REPLACE VIEW transport.roster_view AS
SELECT
    s.id AS student_id,
    s.student_custom_id,
    s.first_name,
    s.last_name,
    
    -- Grade & Section
    c.name AS grade,
    cs.section_name AS section,
    
    -- Photo
    'https://jqpahjeymfukkzwiapog.supabase.co/storage/v1/object/public/profile_pictures/' || s.id AS photo_url,
    
    -- Transport
    ba.route_id AS route_id,
    br.route_name AS route_name,
    ba.bus_id AS bus_id,        -- [ADDED] For Boarding Events
    b.bus_number AS bus_number,
    
    -- Driver
    (e.first_name || ' ' || e.last_name) AS driver_name,
    dp.mobile_number AS driver_mobile,
    
    -- Pickup
    ba.pickup_stop AS pickup_stop_id,
    COALESCE(pickup_stop.name, ba.pickup_stop) AS pickup_stop_name,
    CASE 
        WHEN pickup_stop.lat IS NOT NULL AND pickup_stop.lng IS NOT NULL 
        THEN ('POINT(' || pickup_stop.lng || ' ' || pickup_stop.lat || ')')::GEOGRAPHY
        ELSE NULL 
    END AS pickup_location,
    pickup_stop.scheduled_time AS pickup_time,
    
    -- Drop
    ba.dropoff_stop AS drop_stop_id,
    COALESCE(drop_stop.name, ba.dropoff_stop) AS drop_stop_name,
    CASE 
        WHEN drop_stop.lat IS NOT NULL AND drop_stop.lng IS NOT NULL 
        THEN ('POINT(' || drop_stop.lng || ' ' || drop_stop.lat || ')')::GEOGRAPHY
        ELSE NULL 
    END AS drop_location,
    drop_stop.scheduled_time AS drop_time,
    
    -- Parent
    p.id AS parent_user_id,
    p.mobile_number AS parent_mobile

FROM school_shared.students s
LEFT JOIN school_shared.class_sections cs ON s.section_id = cs.id
LEFT JOIN school_shared.classes c ON cs.class_id = c.id
LEFT JOIN school_shared.bus_assignments ba ON s.id = ba.student_id
LEFT JOIN school_shared.bus_routes br ON ba.route_id = br.id
LEFT JOIN school_shared.buses b ON ba.bus_id = b.id
LEFT JOIN school_shared.employees e ON b.driver_id = e.id AND e.role = 'driver'
LEFT JOIN mystudentapp.profiles dp ON e.email = dp.email
LEFT JOIN LATERAL (
    SELECT 
        el ->> 'name' AS name,
        (el ->> 'latitude')::numeric AS lat,
        (el ->> 'longitude')::numeric AS lng,
        el ->> 'scheduled_time' AS scheduled_time
    FROM jsonb_array_elements(br.stops::jsonb) el
    WHERE (el ->> 'name') = ba.pickup_stop
) pickup_stop ON true
LEFT JOIN LATERAL (
    SELECT 
        el ->> 'name' AS name,
        (el ->> 'latitude')::numeric AS lat,
        (el ->> 'longitude')::numeric AS lng,
        el ->> 'scheduled_time' AS scheduled_time
    FROM jsonb_array_elements(br.stops::jsonb) el
    WHERE (el ->> 'name') = ba.dropoff_stop
) drop_stop ON true
LEFT JOIN school_shared.parent_student ps ON s.id = ps.student_id AND ps.relation = 'Father'
LEFT JOIN mystudentapp.profiles p ON ps.user_id = p.id
WHERE ba.route_id IS NOT NULL;

GRANT SELECT ON transport.roster_view TO authenticated;


-- 3. Permissions for school_shared.boarding_events
GRANT ALL ON school_shared.boarding_events TO authenticated;
ALTER TABLE school_shared.boarding_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Drivers can insert events" ON school_shared.boarding_events;
CREATE POLICY "Drivers can insert events"
ON school_shared.boarding_events FOR INSERT
TO authenticated
WITH CHECK (true);


-- 4. Helper: Find Closest Stop
CREATE OR REPLACE FUNCTION transport.get_closest_stop(p_route_id UUID, p_lat numeric, p_lng numeric)
RETURNS TEXT AS $$
DECLARE
    v_stops JSONB;
    v_stop_name TEXT;
    v_min_dist FLOAT := 1000000;
    v_dist FLOAT;
    v_stop RECORD;
BEGIN
    SELECT stops INTO v_stops FROM school_shared.bus_routes WHERE id::text = p_route_id::text;
    
    IF v_stops IS NULL OR p_lat IS NULL OR p_lng IS NULL THEN
        RETURN 'Unknown Stop';
    END IF;

    FOR v_stop IN SELECT * FROM jsonb_to_recordset(v_stops) AS x(name text, latitude numeric, longitude numeric)
    LOOP
        v_dist := sqrt(power(v_stop.latitude - p_lat, 2) + power(v_stop.longitude - p_lng, 2));
        IF v_dist < v_min_dist THEN
            v_min_dist := v_dist;
            v_stop_name := v_stop.name;
        END IF;
    END LOOP;

    RETURN COALESCE(v_stop_name, 'Unknown Stop');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. TRIGGER FUNCTION (Using Roster View)
CREATE OR REPLACE FUNCTION transport.trigger_notification_on_boarding()
RETURNS TRIGGER AS $$
DECLARE
    v_student_name TEXT;
    v_parent_id UUID;
    v_bus_id UUID;
    v_route_id UUID;
    v_stop_name TEXT;
    v_title TEXT;
    v_body TEXT;
    v_event_type TEXT;
BEGIN
    -- 1. Fetch Info from ROSTER VIEW
    SELECT 
        first_name || ' ' || last_name,
        parent_user_id,
        bus_id,
        route_id
    INTO 
        v_student_name,
        v_parent_id,
        v_bus_id,
        v_route_id
    FROM transport.roster_view
    WHERE student_id = NEW.student_id::uuid
    LIMIT 1;

    -- Fallback for Parent ID
    IF v_parent_id IS NULL AND NEW.parent_user_id IS NOT NULL THEN
        v_parent_id := NEW.parent_user_id;
    END IF;

    -- Determine Event Type
    IF NEW.status = 'onboarded' THEN
        v_event_type := 'board';
    ELSE
        v_event_type := 'deboard';
    END IF;

    -- 2. Insert into BOARDING_EVENTS
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

    -- 3. Prepare Notification
    IF v_parent_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Find smart stop name
    IF NEW.latitude IS NOT NULL THEN
        v_stop_name := transport.get_closest_stop(v_route_id, NEW.latitude, NEW.longitude);
    ELSE
        v_stop_name := 'their stop';
    END IF;

    -- Format Title & Body
    IF NEW.status = 'onboarded' THEN
        v_title := 'Bus Alert: ' || v_student_name || ' Boarded 🚌';
        v_body := v_student_name || ' has boarded the bus at ' || v_stop_name || '.'; 
    ELSE
        v_title := 'Bus Alert: ' || v_student_name || ' Offboarded 🏫';
        v_body := v_student_name || ' has reached ' || v_stop_name || '.';
    END IF;

    -- 4. Queue Notification
    BEGIN
        INSERT INTO public.notifications_queue (user_id, title, body, data)
        VALUES (
            v_parent_id,
            v_title,
            v_body,
            jsonb_build_object(
                'student_id', NEW.student_id, 
                'log_id', NEW.id, 
                'status', NEW.status,
                'stop_name', v_stop_name,
                'type', 'transport_update'
            )
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to queue notification: %', SQLERRM;
    END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
