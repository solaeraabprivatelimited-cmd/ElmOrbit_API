-- Study Room Monitoring System (Privacy-First)
-- Stores only abstracted data (skeleton coordinates, events, behavior flags)
-- No raw video, no facial features

-- 1. Study Rooms Table
CREATE TABLE IF NOT EXISTS study_rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_name VARCHAR(255) NOT NULL UNIQUE,
  room_code VARCHAR(50) NOT NULL UNIQUE,
  capacity INT NOT NULL,
  location VARCHAR(255),
  camera_rtsp_url TEXT,
  is_active BOOLEAN DEFAULT true,
  monitoring_enabled BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Monitoring Events Table
CREATE TABLE IF NOT EXISTS monitoring_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL, -- 'occupancy_change', 'unusual_behavior', 'intrusion_alert', 'fall_detected', 'loitering'
  severity VARCHAR(20) NOT NULL, -- 'low', 'medium', 'high', 'critical'
  description TEXT,
  people_count INT,
  anomaly_score FLOAT DEFAULT 0.0, -- 0-1 confidence score
  event_data JSONB, -- Flexible storage for event specifics
  processed BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Skeleton Data (Pose Tracking - Abstracted)
CREATE TABLE IF NOT EXISTS room_skeleton_snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  person_index INT NOT NULL, -- Anonymous person ID within room
  keypoints JSONB NOT NULL, -- MediaPipe/OpenPose landmarks {id, x, y, confidence}
  pose_angle FLOAT, -- Aggregate angle (for posture detection)
  velocity FLOAT, -- Movement speed between frames
  is_standing BOOLEAN,
  is_idle BOOLEAN,
  frame_timestamp TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Behavior Rules Engine Table
CREATE TABLE IF NOT EXISTS behavior_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  rule_name VARCHAR(255) NOT NULL,
  rule_type VARCHAR(50) NOT NULL, -- 'occupancy', 'posture', 'motion', 'loitering', 'intrusion'
  condition_json JSONB NOT NULL, -- {threshold, operator, value, etc}
  alert_trigger_level VARCHAR(20), -- 'low', 'medium', 'high', 'critical'
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Alert Configuration
CREATE TABLE IF NOT EXISTS alert_configurations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  alert_type VARCHAR(50) NOT NULL,
  enabled BOOLEAN DEFAULT true,
  notification_channel VARCHAR(50), -- 'email', 'sms', 'in_app', 'webhook'
  recipient_user_ids UUID[] DEFAULT ARRAY[]::UUID[], -- Admin IDs
  cooldown_minutes INT DEFAULT 5, -- Prevent spam alerts
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. Monitoring Session Logs
CREATE TABLE IF NOT EXISTS monitoring_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  session_start TIMESTAMP NOT NULL,
  session_end TIMESTAMP,
  total_people_peak INT,
  total_events INT,
  anomalies_detected INT,
  status VARCHAR(50), -- 'active', 'completed', 'paused'
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. Room Occupancy History (Aggregated)
CREATE TABLE IF NOT EXISTS room_occupancy_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  timestamp TIMESTAMP NOT NULL,
  occupancy_count INT,
  confidence_score FLOAT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. System Health & Monitoring Status
CREATE TABLE IF NOT EXISTS monitoring_system_status (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES study_rooms(id) ON DELETE CASCADE,
  is_camera_online BOOLEAN DEFAULT false,
  last_frame_received_at TIMESTAMP,
  processing_fps FLOAT,
  gpu_memory_usage FLOAT,
  cpu_usage FLOAT,
  error_message TEXT,
  status VARCHAR(50), -- 'healthy', 'degraded', 'offline'
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_events_room_time ON monitoring_events(room_id, created_at DESC);
CREATE INDEX idx_events_severity ON monitoring_events(severity, created_at DESC);
CREATE INDEX idx_skeleton_room_person ON room_skeleton_snapshots(room_id, person_index);
CREATE INDEX idx_occupancy_room ON room_occupancy_history(room_id, timestamp DESC);
CREATE INDEX idx_sessions_room ON monitoring_sessions(room_id, session_start DESC);

-- Enable Row Level Security (per room admin)
ALTER TABLE study_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE monitoring_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_skeleton_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE behavior_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE monitoring_sessions ENABLE ROW LEVEL SECURITY;

-- Retention Policy: Delete old skeleton data after 7 days (privacy)
CREATE OR REPLACE FUNCTION delete_old_skeleton_data()
RETURNS void AS $$
BEGIN
  DELETE FROM room_skeleton_snapshots
  WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Retention Policy: Archive old events after 30 days
CREATE OR REPLACE FUNCTION archive_old_events()
RETURNS void AS $$
BEGIN
  DELETE FROM monitoring_events
  WHERE created_at < NOW() - INTERVAL '30 days'
  AND severity = 'low';
END;
$$ LANGUAGE plpgsql;

-- Grant permissions (adjust based on user roles)
GRANT SELECT, INSERT ON study_rooms TO authenticated;
GRANT SELECT, INSERT, UPDATE ON monitoring_events TO authenticated;
GRANT SELECT ON monitoring_sessions TO authenticated;
