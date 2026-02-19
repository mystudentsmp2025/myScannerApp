-- ROBUST TRIGGER FUNCTION
-- This version wraps the notification insert in an Exception Block.
-- If the downstream webhook fails (for ANY reason - permissions, network, logic),
-- this function will CATCH the error, Log it to the console (Postgres logs),
-- and ALLOW the original Boarding Log insert to succeed.

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

    -- Safe Block: Try to insert notification, but don't fail the transaction if it errors
    BEGIN
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
    EXCEPTION WHEN OTHERS THEN
        -- Log the error so we can see it in Supabase Dashboard -> Database -> Postgres Logs
        RAISE WARNING 'Failed to queue notification: %', SQLERRM;
        -- Do nothing else, just return NEW so the Boarding Log is saved
    END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
