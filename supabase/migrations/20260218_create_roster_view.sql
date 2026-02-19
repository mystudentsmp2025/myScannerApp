-- Create a view to consolidate student transport details
-- NOTE: Table and column names are assumed based on description. 
-- Please verify against your actual schema.

CREATE OR REPLACE VIEW transport.roster_view AS
SELECT
    s.id AS student_id,
    s.student_custom_id,
    s.first_name,
    s.last_name,
    
    -- Grade & Section from Joins
    c.name AS grade,
    cs.section_name AS section,
    
    -- Dynamic Photo URL
    'https://jqpahjeymfukkzwiapog.supabase.co/storage/v1/object/public/profile_pictures/' || s.id AS photo_url,
    
    -- Transport Details
    ba.route_id AS route_id,
    br.route_name AS route_name,
    b.bus_number AS bus_number,
    
    -- Driver Details
    (e.first_name || ' ' || e.last_name) AS driver_name,
    dp.mobile_number AS driver_mobile,
    
    -- Pickup Stop (Extracted from br.stops JSON)
    -- ba.pickup_stop is the name of the stop
    ba.pickup_stop AS pickup_stop_id, -- Treating name as ID for local consistency
    COALESCE(pickup_stop.name, ba.pickup_stop) AS pickup_stop_name,
    
    CASE 
        WHEN pickup_stop.lat IS NOT NULL AND pickup_stop.lng IS NOT NULL 
        THEN ('POINT(' || pickup_stop.lng || ' ' || pickup_stop.lat || ')')::GEOGRAPHY
        ELSE NULL 
    END AS pickup_location,
    pickup_stop.scheduled_time AS pickup_time,
    
    -- Drop Stop (Extracted from br.stops JSON)
    -- ba.dropoff_stop is the name of the stop
    ba.dropoff_stop AS drop_stop_id,
    COALESCE(drop_stop.name, ba.dropoff_stop) AS drop_stop_name,
    
    CASE 
        WHEN drop_stop.lat IS NOT NULL AND drop_stop.lng IS NOT NULL 
        THEN ('POINT(' || drop_stop.lng || ' ' || drop_stop.lat || ')')::GEOGRAPHY
        ELSE NULL 
    END AS drop_location,
    drop_stop.scheduled_time AS drop_time,
    
    -- Parent Info for Notification (Primary Parent)
    p.id AS parent_user_id,
    p.mobile_number AS parent_mobile

FROM school_shared.students s
-- Join Class & Section
LEFT JOIN school_shared.class_sections cs ON s.section_id = cs.id
LEFT JOIN school_shared.classes c ON cs.class_id = c.id

-- Join Student Transport Assignment
LEFT JOIN school_shared.bus_assignments ba ON s.id = ba.student_id

-- Join Bus Route
LEFT JOIN school_shared.bus_routes br ON ba.route_id = br.id

-- Join Bus
LEFT JOIN school_shared.buses b ON ba.bus_id = b.id

-- Join Driver
LEFT JOIN school_shared.employees e ON b.driver_id = e.id AND e.role = 'driver'
LEFT JOIN mystudentapp.profiles dp ON e.email = dp.email

-- Extract Pickup Stop details from JSON Array in bus_routes.stops
LEFT JOIN LATERAL (
    SELECT 
        el ->> 'name' AS name,
        (el ->> 'latitude')::numeric AS lat,
        (el ->> 'longitude')::numeric AS lng,
        el ->> 'scheduled_time' AS scheduled_time
    FROM jsonb_array_elements(br.stops::jsonb) el
    WHERE (el ->> 'name') = ba.pickup_stop -- Linking match
) pickup_stop ON true

-- Extract Drop Stop details
LEFT JOIN LATERAL (
    SELECT 
        el ->> 'name' AS name,
        (el ->> 'latitude')::numeric AS lat,
        (el ->> 'longitude')::numeric AS lng,
        el ->> 'scheduled_time' AS scheduled_time
    FROM jsonb_array_elements(br.stops::jsonb) el
    WHERE (el ->> 'name') = ba.dropoff_stop -- Linking match
) drop_stop ON true

-- Join Parent
LEFT JOIN school_shared.parent_student ps ON s.id = ps.student_id AND ps.relation = 'Father'
LEFT JOIN mystudentapp.profiles p ON ps.user_id = p.id

WHERE ba.route_id IS NOT NULL;

-- Grant access
GRANT SELECT ON transport.roster_view TO authenticated;
