-- ============================================================================
-- ELM ORBIT DATABASE SCHEMA
-- ============================================================================
-- Created: March 2026
-- This migration creates all core tables for the Elm Orbit learning platform

-- ============================================================================
-- USERS & AUTHENTICATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  avatar_url TEXT,
  role VARCHAR(50) NOT NULL CHECK (role IN ('student', 'mentor')), -- student | mentor
  bio TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,
  last_login_at TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_is_active ON users(is_active);

-- ============================================================================
-- STUDY ROOMS & COLLABORATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS study_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(20) NOT NULL UNIQUE, -- Shareable room code (e.g., "STUDY-ABC123")
  name VARCHAR(255) NOT NULL,
  mode VARCHAR(50) NOT NULL CHECK (mode IN ('focus', 'silent', 'collaborative', 'live')),
  host_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ends_at TIMESTAMP, -- Optional end time for scheduled sessions
  description TEXT,
  max_participants INT DEFAULT 50,
  password_protected BOOLEAN DEFAULT FALSE,
  password_hash VARCHAR(255) -- If password_protected = true
);

CREATE INDEX idx_study_rooms_code ON study_rooms(code);
CREATE INDEX idx_study_rooms_host_id ON study_rooms(host_id);
CREATE INDEX idx_study_rooms_is_active ON study_rooms(is_active);
CREATE INDEX idx_study_rooms_mode ON study_rooms(mode);
CREATE INDEX idx_study_rooms_created_at ON study_rooms(created_at DESC);

-- ============================================================================
-- ROOM PARTICIPANTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS room_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  left_at TIMESTAMP, -- NULL if still in room
  is_pinned BOOLEAN DEFAULT FALSE, -- Pinned participants highlighted in UI
  is_muted BOOLEAN DEFAULT FALSE,
  is_video_off BOOLEAN DEFAULT FALSE,
  permissions VARCHAR(50) DEFAULT 'member' CHECK (permissions IN ('host', 'moderator', 'member'))
);

CREATE INDEX idx_room_participants_room_id ON room_participants(room_id);
CREATE INDEX idx_room_participants_user_id ON room_participants(user_id);
CREATE INDEX idx_room_participants_joined_at ON room_participants(joined_at DESC);
CREATE UNIQUE INDEX idx_room_participants_active ON room_participants(room_id, user_id) WHERE left_at IS NULL;

-- ============================================================================
-- ROOM CHAT & MESSAGING
-- ============================================================================

CREATE TABLE IF NOT EXISTS room_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_edited BOOLEAN DEFAULT FALSE,
  message_type VARCHAR(50) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'system'))
);

CREATE INDEX idx_room_messages_room_id ON room_messages(room_id);
CREATE INDEX idx_room_messages_user_id ON room_messages(user_id);
CREATE INDEX idx_room_messages_created_at ON room_messages(created_at DESC);

-- ============================================================================
-- ROOM REACTIONS (EMOJIS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS room_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji VARCHAR(10) NOT NULL, -- e.g., "👍", "🎉", "💪"
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_room_reactions_room_id ON room_reactions(room_id);
CREATE INDEX idx_room_reactions_user_id ON room_reactions(user_id);
CREATE UNIQUE INDEX idx_room_reactions_unique ON room_reactions(room_id, user_id, emoji);

-- ============================================================================
-- FOCUS SESSIONS (POMODORO TIMERS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS focus_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES study_rooms(id) ON DELETE SET NULL,
  duration_mins INT NOT NULL CHECK (duration_mins > 0),
  completed_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  breaks_taken INT DEFAULT 0,
  notes TEXT
);

CREATE INDEX idx_focus_sessions_user_id ON focus_sessions(user_id);
CREATE INDEX idx_focus_sessions_room_id ON focus_sessions(room_id);
CREATE INDEX idx_focus_sessions_completed_at ON focus_sessions(completed_at DESC);

-- ============================================================================
-- NOTES
-- ============================================================================

CREATE TABLE IF NOT EXISTS notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES study_rooms(id) ON DELETE SET NULL,
  title VARCHAR(255),
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_pinned BOOLEAN DEFAULT FALSE,
  is_shared BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_notes_user_id ON notes(user_id);
CREATE INDEX idx_notes_room_id ON notes(room_id);
CREATE INDEX idx_notes_updated_at ON notes(updated_at DESC);
CREATE INDEX idx_notes_is_pinned ON notes(is_pinned) WHERE is_pinned = TRUE;

-- ============================================================================
-- MENTOR PROFILES
-- ============================================================================

CREATE TABLE IF NOT EXISTS mentor_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  hourly_rate INT NOT NULL CHECK (hourly_rate > 0), -- In smallest currency unit (paise)
  rating DECIMAL(3, 2) DEFAULT 0.00 CHECK (rating >= 0 AND rating <= 5.00),
  session_count INT DEFAULT 0,
  total_hours INT DEFAULT 0,
  availability JSON, -- Stored as JSON: { "monday": [["09:00", "17:00"], ...], ...}
  specializations TEXT[], -- Array of subject specializations
  bio TEXT,
  verified BOOLEAN DEFAULT FALSE,
  verification_date TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_mentor_profiles_user_id ON mentor_profiles(user_id);
CREATE INDEX idx_mentor_profiles_verified ON mentor_profiles(verified) WHERE verified = TRUE;
CREATE INDEX idx_mentor_profiles_rating ON mentor_profiles(rating DESC);

-- ============================================================================
-- MENTOR SESSIONS (BOOKINGS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS mentor_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'ongoing', 'completed', 'cancelled')),
  topic VARCHAR(255),
  description TEXT,
  scheduled_at TIMESTAMP NOT NULL,
  duration_mins INT NOT NULL DEFAULT 60 CHECK (duration_mins > 0),
  completed_at TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  meeting_link VARCHAR(500), -- For video call URLs
  cancellation_reason TEXT,
  cancelled_by UUID REFERENCES users(id)
);

CREATE INDEX idx_mentor_sessions_mentor_id ON mentor_sessions(mentor_id);
CREATE INDEX idx_mentor_sessions_student_id ON mentor_sessions(student_id);
CREATE INDEX idx_mentor_sessions_status ON mentor_sessions(status);
CREATE INDEX idx_mentor_sessions_scheduled_at ON mentor_sessions(scheduled_at);

-- ============================================================================
-- PAYMENTS & RAZORPAY
-- ============================================================================

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES mentor_sessions(id) ON DELETE SET NULL,
  mentor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount INT NOT NULL CHECK (amount > 0), -- In smallest currency unit (paise)
  currency VARCHAR(3) DEFAULT 'INR',
  method VARCHAR(50) NOT NULL CHECK (method IN ('razorpay', 'upi', 'wallet', 'card')),
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  razorpay_order_id VARCHAR(100),
  razorpay_payment_id VARCHAR(100),
  razorpay_signature VARCHAR(256),
  refund_id VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  notes TEXT
);

CREATE INDEX idx_payments_session_id ON payments(session_id);
CREATE INDEX idx_payments_mentor_id ON payments(mentor_id);
CREATE INDEX idx_payments_student_id ON payments(student_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created_at ON payments(created_at DESC);
CREATE INDEX idx_payments_razorpay_order_id ON payments(razorpay_order_id);

-- ============================================================================
-- WELLNESS & MOOD TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS mood_checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mood VARCHAR(50) NOT NULL CHECK (mood IN ('excellent', 'good', 'okay', 'stressed', 'overwhelmed', 'tired')),
  note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_mood_checkins_user_id ON mood_checkins(user_id);
CREATE INDEX idx_mood_checkins_created_at ON mood_checkins(created_at DESC);

-- ============================================================================
-- WELLNESS ARTICLES & RESOURCES
-- ============================================================================

CREATE TABLE IF NOT EXISTS wellness_articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  excerpt TEXT,
  featured_image_url TEXT,
  published_at TIMESTAMP,
  is_published BOOLEAN DEFAULT FALSE,
  category VARCHAR(100), -- e.g., 'mindfulness', 'stress-relief', 'time-management'
  tag TEXT[], -- Array of tags
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_wellness_articles_author_id ON wellness_articles(author_id);
CREATE INDEX idx_wellness_articles_published_at ON wellness_articles(published_at DESC) WHERE is_published = TRUE;
CREATE INDEX idx_wellness_articles_category ON wellness_articles(category);

-- ============================================================================
-- COMMUNITY & SOCIAL FEATURES
-- ============================================================================

CREATE TABLE IF NOT EXISTS world_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_pinned BOOLEAN DEFAULT FALSE,
  message_type VARCHAR(50) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file'))
);

CREATE INDEX idx_world_messages_user_id ON world_messages(user_id);
CREATE INDEX idx_world_messages_created_at ON world_messages(created_at DESC);
CREATE INDEX idx_world_messages_is_pinned ON world_messages(is_pinned) WHERE is_pinned = TRUE;

-- ============================================================================
-- MOTIVATION CORNER
-- ============================================================================

CREATE TABLE IF NOT EXISTS motivation_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL CHECK (type IN ('achievement', 'milestone', 'goal', 'reflection', 'encouragement')),
  content TEXT NOT NULL,
  image_url TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_motivation_posts_user_id ON motivation_posts(user_id);
CREATE INDEX idx_motivation_posts_created_at ON motivation_posts(created_at DESC);
CREATE INDEX idx_motivation_posts_type ON motivation_posts(type);

-- ============================================================================
-- COMMUNITY EVENTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS community_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  poster_url TEXT,
  starts_at TIMESTAMP NOT NULL,
  ends_at TIMESTAMP,
  location VARCHAR(255), -- Physical or virtual location
  event_url TEXT, -- Zoom/Meet/etc link
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  max_attendees INT,
  category VARCHAR(100), -- e.g., 'workshop', 'webinar', 'study-jam'
  status VARCHAR(50) DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'ongoing', 'completed', 'cancelled')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_community_events_created_by ON community_events(created_by);
CREATE INDEX idx_community_events_starts_at ON community_events(starts_at);
CREATE INDEX idx_community_events_status ON community_events(status);

CREATE TABLE IF NOT EXISTS event_attendees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES community_events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  attended BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_event_attendees_event_id ON event_attendees(event_id);
CREATE INDEX idx_event_attendees_user_id ON event_attendees(user_id);
CREATE UNIQUE INDEX idx_event_attendees_unique ON event_attendees(event_id, user_id);

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(100) NOT NULL, -- e.g., 'session_reminder', 'new_message', 'friend_request'
  title VARCHAR(255),
  content TEXT NOT NULL,
  related_id UUID, -- ID of related entity (session, room, etc.)
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  action_url TEXT
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- ============================================================================
-- PLANNER & TASK MANAGEMENT
-- ============================================================================

CREATE TABLE IF NOT EXISTS planner_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  due_date DATE,
  due_time TIME,
  priority VARCHAR(50) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  status VARCHAR(50) NOT NULL DEFAULT 'todo' CHECK (status IN ('todo', 'in_progress', 'completed', 'cancelled')),
  category VARCHAR(100), -- e.g., 'studies', 'personal', 'health'
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_planner_tasks_user_id ON planner_tasks(user_id);
CREATE INDEX idx_planner_tasks_due_date ON planner_tasks(due_date);
CREATE INDEX idx_planner_tasks_status ON planner_tasks(status);
CREATE INDEX idx_planner_tasks_priority ON planner_tasks(priority);

-- ============================================================================
-- STUDY PLANS
-- ============================================================================

CREATE TABLE IF NOT EXISTS study_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  goals TEXT[], -- Array of learning goals
  subjects TEXT[], -- Array of subjects to study
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'cancelled')),
  progress_percent INT DEFAULT 0 CHECK (progress_percent >= 0 AND progress_percent <= 100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_study_plans_user_id ON study_plans(user_id);
CREATE INDEX idx_study_plans_status ON study_plans(status);
CREATE INDEX idx_study_plans_start_date ON study_plans(start_date);

CREATE TABLE IF NOT EXISTS study_plan_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  study_plan_id UUID NOT NULL REFERENCES study_plans(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  target_date DATE,
  completed_at TIMESTAMP,
  description TEXT
);

CREATE INDEX idx_study_plan_milestones_study_plan_id ON study_plan_milestones(study_plan_id);

-- ============================================================================
-- REPORTS & MODERATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  reported_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  report_type VARCHAR(100) NOT NULL CHECK (report_type IN ('harassment', 'inappropriate', 'spam', 'harmful', 'other')),
  reason VARCHAR(255),
  context TEXT, -- Detailed explanation
  related_content_id UUID, -- ID of message/post being reported
  related_content_type VARCHAR(50), -- 'message', 'post', 'profile'
  status VARCHAR(50) DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'dismissed')),
  resolution TEXT,
  resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  resolved_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX idx_reports_reported_id ON reports(reported_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_created_at ON reports(created_at DESC);

-- ============================================================================
-- ACTIVITY AUDIT LOG (For tracking user actions)
-- ============================================================================

CREATE TABLE IF NOT EXISTS activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action VARCHAR(100) NOT NULL, -- e.g., 'room_created', 'session_booked'
  entity_type VARCHAR(50), -- e.g., 'study_room', 'mentor_session'
  entity_id UUID,
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_activity_log_user_id ON activity_log(user_id);
CREATE INDEX idx_activity_log_action ON activity_log(action);
CREATE INDEX idx_activity_log_created_at ON activity_log(created_at DESC);

-- ============================================================================
-- ENABLE RLS (Row Level Security) FOR SUPABASE
-- ============================================================================

-- Enable RLS on all tables (optional based on your Supabase setup)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentor_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE planner_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- BASIC RLS POLICIES (Examples - customize as needed)
-- ============================================================================

-- Users can view public user profiles
CREATE POLICY "Public user profiles" ON users
  FOR SELECT USING (true);

-- Users can only update their own profile
CREATE POLICY "Users update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Users can only see their own notifications
CREATE POLICY "Users view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

-- Users can only see messages in rooms they're part of
CREATE POLICY "View room messages" ON room_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM room_participants
      WHERE room_id = room_messages.room_id
      AND user_id = auth.uid()
    )
  );

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
