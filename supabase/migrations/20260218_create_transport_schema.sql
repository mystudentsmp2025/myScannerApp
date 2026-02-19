-- Create Schema
CREATE SCHEMA IF NOT EXISTS transport;

-- Grant usage (Critical for 42501 error)
GRANT USAGE ON SCHEMA transport TO authenticated, anon;

-- Enable PostGIS for location support
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;

-- Create Enum
DO $$ BEGIN
    CREATE TYPE transport.boarding_status AS ENUM ('onboarded', 'offboarded');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create Table
CREATE TABLE IF NOT EXISTS transport.boarding_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id TEXT NOT NULL,
    parent_user_id UUID REFERENCES auth.users(id),
    status transport.boarding_status NOT NULL,
    location GEOGRAPHY(POINT),
    scanned_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS (Enable but keep open for service role/authenticated drivers for now - refine later)
ALTER TABLE transport.boarding_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Drivers can insert logs"
ON transport.boarding_logs FOR INSERT
TO authenticated
WITH CHECK (true); -- Refine to specific driver role later

CREATE POLICY "Parents can view logs for their kids"
ON transport.boarding_logs FOR SELECT
TO authenticated
USING (auth.uid() = parent_user_id);

-- Trigger Function to notify parent
CREATE OR REPLACE FUNCTION transport.trigger_notification_on_boarding()
RETURNS TRIGGER AS $$
DECLARE
    notification_title TEXT;
    notification_body TEXT;
BEGIN
    -- If no parent linked, skip notification
    IF NEW.parent_user_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.status = 'onboarded' THEN
        notification_title := 'Student Boarded 🚌';
        notification_body := 'Your student (' || NEW.student_id || ') has boarded the bus.'; 
    ELSE
        notification_title := 'Student Offboarded 🏫';
        notification_body := 'Your student (' || NEW.student_id || ') has reached the destination.';
    END IF;

    -- Insert into existing notification queue
    INSERT INTO public.notifications_queue (user_id, title, body, data)
    VALUES (
        NEW.parent_user_id,
        notification_title,
        notification_body,
        jsonb_build_object(
            'student_id', NEW.student_id, 
            'log_id', NEW.id, 
            'status', NEW.status,
            'type', 'transport_update'
        )
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create Trigger
DROP TRIGGER IF EXISTS on_boarding_log_inserted ON transport.boarding_logs;

CREATE TRIGGER on_boarding_log_inserted
AFTER INSERT ON transport.boarding_logs
FOR EACH ROW
EXECUTE FUNCTION transport.trigger_notification_on_boarding();
