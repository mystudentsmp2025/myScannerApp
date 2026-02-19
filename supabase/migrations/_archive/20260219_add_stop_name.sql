BEGIN;

-- 1. Modify Table Structure
ALTER TABLE transport.boarding_logs DROP COLUMN IF EXISTS location;
ALTER TABLE transport.boarding_logs ADD COLUMN IF NOT EXISTS stop_name TEXT;

-- 2. Create Enrichment Function (Generic)
-- This function calculates the stop name BEFORE the row is inserted.
CREATE OR REPLACE FUNCTION transport.enrich_boarding_log()
RETURNS TRIGGER AS $$
DECLARE
    v_route_id UUID;
    v_stop_name TEXT;
BEGIN
    -- Get Route ID from Roster View (using student_id)
    -- Explicit casting to UUID to avoid type errors
    SELECT route_id INTO v_route_id
    FROM transport.roster_view
    WHERE student_id = NEW.student_id::uuid
    LIMIT 1;

    -- Calculate Stop Name if we have coordinates & route
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL AND v_route_id IS NOT NULL THEN
       v_stop_name := transport.get_closest_stop(v_route_id, NEW.latitude, NEW.longitude);
    ELSE
       v_stop_name := 'Unknown Stop';
    END IF;

    -- Set the field on the NEW row
    NEW.stop_name := v_stop_name;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Attach BEFORE INSERT Trigger
DROP TRIGGER IF EXISTS trigger_enrich_boarding_log ON transport.boarding_logs;
CREATE TRIGGER trigger_enrich_boarding_log
BEFORE INSERT ON transport.boarding_logs
FOR EACH ROW
EXECUTE FUNCTION transport.enrich_boarding_log();


-- 4. Simplify Notification Trigger (Remove calculation logic)
CREATE OR REPLACE FUNCTION transport.trigger_notification_on_boarding()
RETURNS TRIGGER AS $$
DECLARE
    v_student_name TEXT;
    v_parent_id UUID;
    v_bus_id UUID;
    v_event_type TEXT;
    v_title TEXT;
    v_body TEXT;
BEGIN
    -- 1. Fetch Info from ROSTER VIEW
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

    -- 2. Insert into BOARDING_EVENTS (History)
    -- Note: We can reuse NEW.stop_name here if we added it to boarding_events too, 
    -- but for now we keep existing logic or use lat/long. 
    -- The user didn't ask to change boarding_events schema, only boarding_logs.
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

    -- Format Title & Body using the PRE-CALCULATED stop_name
    IF NEW.status = 'onboarded' THEN
        v_title := 'Bus Alert: ' || v_student_name || ' Boarded 🚌';
        v_body := v_student_name || ' has boarded the bus at ' || COALESCE(NEW.stop_name, 'Unknown Stop') || '.'; 
    ELSE
        v_title := 'Bus Alert: ' || v_student_name || ' Offboarded 🏫';
        v_body := v_student_name || ' has reached ' || COALESCE(NEW.stop_name, 'Unknown Stop') || '.';
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
                'stop_name', NEW.stop_name, -- Use the field directly
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
