-- Local Roster Table (Updated to match transport.roster_view)
CREATE TABLE local_roster (
    student_id TEXT PRIMARY KEY, -- UUID from Supabase
    student_custom_id TEXT,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    grade TEXT,
    section TEXT,
    photo_url TEXT, -- Remote URL
    local_image_path TEXT, -- Local path after download
    
    -- Transport Info
    route_id TEXT,
    route_name TEXT,
    bus_number TEXT,
    driver_name TEXT,
    driver_mobile TEXT,
    
    -- Stop Info
    pickup_stop_id TEXT,
    pickup_stop_name TEXT,
    pickup_time TEXT,
    drop_stop_id TEXT,
    drop_stop_name TEXT,
    drop_time TEXT,
    
    -- Parent Info
    parent_user_id TEXT, -- UUID
    parent_mobile TEXT,
    
    last_updated INTEGER -- Epoch timestamp
);

-- Pending Sync Table (Outbox Pattern)
CREATE TABLE pending_sync (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id TEXT NOT NULL,
    parent_user_id TEXT,
    status TEXT NOT NULL, -- 'onboarded' or 'offboarded'
    latitude REAL,
    longitude REAL,
    scanned_at TEXT NOT NULL, -- ISO8601 string
    sync_status TEXT DEFAULT 'pending', -- pending, syncing, failed
    retry_count INTEGER DEFAULT 0
);
