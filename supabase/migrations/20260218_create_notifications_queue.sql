-- Create the missing notifications_queue table
CREATE TABLE IF NOT EXISTS public.notifications_queue (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Grant Permissions
GRANT ALL ON public.notifications_queue TO authenticated, service_role, anon;

-- Enable RLS
ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users (drivers) to insert notifications for parents
CREATE POLICY "Allow insert for authenticated"
ON public.notifications_queue FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow users to see their own notifications (optional, for parents)
CREATE POLICY "Allow select own notifications"
ON public.notifications_queue FOR SELECT
TO authenticated
USING (auth.uid() = user_id);
