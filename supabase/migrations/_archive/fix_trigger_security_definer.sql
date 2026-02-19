-- FIX: Make the Trigger Function SECURITY DEFINER
-- This ensures the function runs with the privileges of the creator (superuser)
-- rather than the driver. This prevents RLS checks on 'notifications_queue' 
-- from blocking the 'boarding_logs' insert.

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
    -- Because this function is SECURITY DEFINER, this INSERT will always succeed
    -- regardless of the driver's permissions on 'notifications_queue'.
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
