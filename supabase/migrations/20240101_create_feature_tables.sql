-- Migration: Create tables for Mentor Booking, Community Events, Room Configuration, and Participant State Management
-- Generated: 2024
-- Purpose: Support new backend endpoints for features 1-5

-- ─────────────────────────────────────────────────────────────────────────────────
-- 1. MENTOR_PROFILES - Store mentor information and qualifications
-- ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE mentor_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    bio TEXT,
    qualifications TEXT[], -- Array of qualification strings
    hourly_rate DECIMAL(10, 2) NOT NULL DEFAULT 0,
    subjects TEXT[], -- Array of subject specializations
    avg_rating DECIMAL(3, 2) DEFAULT 0,
    total_sessions INT DEFAULT 0,
    response_time_hours INT DEFAULT 24,
    availability_pattern TEXT DEFAULT 'flexible', -- 'flexible', 'weekends_only', 'evenings_only'
    is_verified BOOLEAN DEFAULT FALSE,
    verification_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mentor_profiles_user_id ON mentor_profiles(user_id);
CREATE INDEX idx_mentor_profiles_subjects ON mentor_profiles USING GIN(subjects);
CREATE INDEX idx_mentor_profiles_rating ON mentor_profiles(avg_rating DESC);

-- ─────────────────────────────────────────────────────────────────────────────────
-- 2. MENTOR_AVAILABILITY - Time slots when mentor is available for sessions
-- ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE mentor_availability (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mentor_id UUID NOT NULL REFERENCES mentor_profiles(id) ON DELETE CASCADE,
    date_from DATE NOT NULL,
    date_to DATE NOT NULL,
    time_start TIME NOT NULL,
    time_end TIME NOT NULL,
    max_sessions_per_day INT DEFAULT 5,
    booked_sessions INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mentor_availability_mentor_id ON mentor_availability(mentor_id);
CREATE INDEX idx_mentor_availability_dates ON mentor_availability(date_from, date_to);

-- ─────────────────────────────────────────────────────────────────────────────────
-- 3. MENTOR_SESSIONS - Actual booked sessions between mentors and students
-- ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE mentor_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mentor_id UUID NOT NULL REFERENCES mentor_profiles(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    availability_id UUID REFERENCES mentor_availability(id) ON DELETE SET NULL,
    session_date DATE NOT NULL,
    session_time TIME NOT NULL,
    duration_mins INT NOT NULL DEFAULT 60,
    subject TEXT NOT NULL,
    status TEXT DEFAULT 'scheduled', -- scheduled, ongoing, completed, cancelled, no_show
    meeting_link VARCHAR(512),
    notes TEXT,
    student_rating INT, -- 1-5
    student_review TEXT,
    mentor_notes TEXT,
    payment_status TEXT DEFAULT 'pending', -- pending, completed, refunded
    amount_paid DECIMAL(10, 2),
    room_id UUID REFERENCES webrtc_rooms(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    scheduled_for TIMESTAMP NOT NULL
);

CREATE INDEX idx_mentor_sessions_mentor_id ON mentor_sessions(mentor_id);
CREATE INDEX idx_mentor_sessions_student_id ON mentor_sessions(student_id);
CREATE INDEX idx_mentor_sessions_status ON mentor_sessions(status);
CREATE INDEX idx_mentor_sessions_scheduled_for ON mentor_sessions(scheduled_for);

-- ─────────────────────────────────────────────────────────────────────────────────
-- 4. COMMUNITY_EVENTS - Community events that users can join
-- ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE community_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    author_name VARCHAR(255),
    avatar_url VARCHAR(512),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    details TEXT[], -- Array of event details/agenda items
    event_date TIMESTAMP NOT NULL,
    is_upcoming BOOLEAN DEFAULT TRUE,
    location VARCHAR(255),
    event_type TEXT DEFAULT 'general', -- study_group, competition, workshop, social
    max_attendees INT,
    room_id UUID REFERENCES webrtc_rooms(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_community_events_author ON community_events(author);
CREATE INDEX idx_community_events_event_date ON community_events(event_date DESC);
CREATE INDEX idx_community_events_upcoming ON community_events(is_upcoming);
CREATE INDEX idx_community_events_type ON community_events(event_type);

-- ─────────────────────────────────────────────────────────────────────────────────
-- 5. EVENT_ATTENDEES - Track attendees of community events
-- ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE event_attendees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES community_events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT NOW(),
    attended BOOLEAN DEFAULT FALSE,
    feedback_rating INT, -- 1-5
    feedback_text TEXT,
    UNIQUE(event_id, user_id)
);

CREATE INDEX idx_event_attendees_event_id ON event_attendees(event_id);
CREATE INDEX idx_event_attendees_user_id ON event_attendees(user_id);

-- ─────────────────────────────────────────────────────────────────────────────────
-- 6. ROOM_CONFIGURATIONS - Store customized room settings for each room
-- ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE room_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL UNIQUE REFERENCES webrtc_rooms(id) ON DELETE CASCADE,
    mode VARCHAR(50) DEFAULT 'collaborative', -- collaborative, lecture, breakout, focus
    ambient_sound VARCHAR(50), -- rain, coffee_shop, forest, ocean, silence
    notification_level VARCHAR(50) DEFAULT 'normal', -- silent, normal, active
    timer_duration_mins INT DEFAULT 25,
    break_duration_mins INT DEFAULT 5,
    auto_start_break BOOLEAN DEFAULT TRUE,
    show_timer BOOLEAN DEFAULT TRUE,
    show_participant_list BOOLEAN DEFAULT TRUE,
    enable_reactions BOOLEAN DEFAULT TRUE,
    enable_whiteboard BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    updated_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

CREATE INDEX idx_room_configurations_room_id ON room_configurations(room_id);

-- ─────────────────────────────────────────────────────────────────────────────────
-- 7. PRODUCTIVITY_TOOLS - Available productivity tools/integrations
-- ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE productivity_tools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    category VARCHAR(100), -- pomodoro, notes, task_management, music, timer, whiteboard
    tool_type VARCHAR(100) DEFAULT 'internal', -- internal, external, ai_powered
    is_active BOOLEAN DEFAULT TRUE,
    config JSONB, -- Tool-specific configuration options
    version VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_productivity_tools_category ON productivity_tools(category);
CREATE INDEX idx_productivity_tools_active ON productivity_tools(is_active);

-- ─────────────────────────────────────────────────────────────────────────────────
-- 8. TOOL_USAGE_LOGS - Track when users use productivity tools
-- ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE tool_usage_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    tool_id UUID NOT NULL REFERENCES productivity_tools(id) ON DELETE CASCADE,
    usage_duration_seconds INT NOT NULL DEFAULT 0,
    session_date DATE NOT NULL,
    logged_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tool_usage_logs_user_id ON tool_usage_logs(user_id);
CREATE INDEX idx_tool_usage_logs_tool_id ON tool_usage_logs(tool_id);
CREATE INDEX idx_tool_usage_logs_session_date ON tool_usage_logs(session_date DESC);

-- ─────────────────────────────────────────────────────────────────────────────────
-- 9. PARTICIPANT_REACTIONS - Track emoji reactions in study rooms
-- ─────────────────────────────────────────────────────────────────────────────────
CREATE TABLE participant_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES webrtc_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reaction_type VARCHAR(50), -- thumbsup, heart, laughing, thinking, cool, sad, fire, 100
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_participant_reactions_room_id ON participant_reactions(room_id);
CREATE INDEX idx_participant_reactions_user_id ON participant_reactions(user_id);
CREATE INDEX idx_participant_reactions_created_at ON participant_reactions(created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────────
-- 10. Seed default productivity tools
-- ─────────────────────────────────────────────────────────────────────────────────
INSERT INTO productivity_tools (name, description, category, tool_type, is_active, config) VALUES
    ('Pomodoro Timer', 'Classic 25-5 productivity timer', 'pomodoro', 'internal', TRUE, '{"default_work_mins": 25, "default_break_mins": 5}'),
    ('Quick Notes', 'Fast note-taking during study sessions', 'notes', 'internal', TRUE, '{"autosave": true}'),
    ('Task List', 'Simple task management for current session', 'task_management', 'internal', TRUE, '{}'),
    ('Ambient Music', 'Background music to aid concentration', 'music', 'external', TRUE, '{"default_genre": "lo-fi"}'),
    ('Focus Mode', 'Block distractions during study', 'focus', 'ai_powered', TRUE, '{"block_notifications": true}'),
    ('Whiteboard', 'Collaborative drawing and diagramming', 'whiteboard', 'internal', FALSE, '{}');

-- ─────────────────────────────────────────────────────────────────────────────────
-- Grant permissions to authenticated users
-- ─────────────────────────────────────────────────────────────────────────────────
ALTER TABLE mentor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentor_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentor_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_attendees ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE productivity_tools ENABLE ROW LEVEL SECURITY;
ALTER TABLE tool_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE participant_reactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies - Mentors can manage their own profile
CREATE POLICY mentor_profile_select ON mentor_profiles FOR SELECT USING (TRUE);
CREATE POLICY mentor_profile_update ON mentor_profiles FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policies - Students can see availability and book sessions
CREATE POLICY mentor_availability_select ON mentor_availability FOR SELECT USING (TRUE);
CREATE POLICY mentor_sessions_select ON mentor_sessions FOR SELECT USING (
    auth.uid() = student_id OR auth.uid() IN (
        SELECT user_id FROM mentor_profiles WHERE id = mentor_id
    )
);

-- RLS Policies - Community events
CREATE POLICY community_events_select ON community_events FOR SELECT USING (TRUE);
CREATE POLICY event_attendees_select ON event_attendees FOR SELECT USING (TRUE);

-- RLS Policies - Productivity tools
CREATE POLICY productivity_tools_select ON productivity_tools FOR SELECT USING (is_active = TRUE);
CREATE POLICY tool_usage_logs_insert ON tool_usage_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY tool_usage_logs_select ON tool_usage_logs FOR SELECT USING (auth.uid() = user_id);

-- RLS Policies - Participant reactions
CREATE POLICY participant_reactions_select ON participant_reactions FOR SELECT USING (TRUE);
