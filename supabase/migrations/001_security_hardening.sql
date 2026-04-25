-- ============================================================================
-- SECURITY UPGRADE MIGRATIONS
-- For: Elm Origin Security Hardening Implementation
-- Run in Supabase SQL Editor or via migration tool
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- 1. AUDIT LOGS TABLE
-- Purpose: Track all security events and user actions for compliance
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- User identification
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  
  -- Event details
  event_type TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
  action TEXT NOT NULL,
  description TEXT NOT NULL,
  
  -- Request details
  ip_address INET NOT NULL,
  user_agent TEXT,
  
  -- Resource affected
  resource_type TEXT,
  resource_id TEXT,
  
  -- Operation status
  success BOOLEAN NOT NULL DEFAULT FALSE,
  status_code INTEGER,
  error_details TEXT,
  
  -- Additional context (JSON)
  metadata JSONB DEFAULT '{}'::jsonb,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Indexes for fast queries
  CONSTRAINT audit_logs_timestamp_check CHECK (timestamp <= NOW() + INTERVAL '1 minute')
);

-- Create indexes for common queries
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_email ON audit_logs(email);
CREATE INDEX idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX idx_audit_logs_severity ON audit_logs(severity);
CREATE INDEX idx_audit_logs_ip_address ON audit_logs(ip_address);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);

-- Enable Row Level Security
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Only authenticated users can select audit logs (for their own events)
CREATE POLICY "Users can view their own audit logs"
  ON audit_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: System (service role) can insert audit logs
CREATE POLICY "Service role can insert audit logs"
  ON audit_logs
  FOR INSERT
  WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────
-- 2. FAILED LOGIN ATTEMPTS TRACKING
-- Purpose: Prevent brute force attacks with progressive delays
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS failed_login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Identity (email or IP)
  email TEXT,
  ip_address INET,
  
  -- Attempt tracking
  attempt_count INTEGER NOT NULL DEFAULT 1,
  last_attempt_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Lockout information
  locked_until TIMESTAMP WITH TIME ZONE,
  reason TEXT,
  
  -- Metadata
  user_agent TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_failed_login_email ON failed_login_attempts(email);
CREATE INDEX idx_failed_login_ip ON failed_login_attempts(ip_address);
CREATE INDEX idx_failed_login_locked_until ON failed_login_attempts(locked_until);
CREATE INDEX idx_failed_login_updated ON failed_login_attempts(updated_at DESC);

-- ─────────────────────────────────────────────────────────────────────────
-- 3. RATE LIMIT TRACKING
-- Purpose: Client-side rate limiting enforcement
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS rate_limit_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Identifier (email, IP, user ID, or session ID)
  identifier TEXT NOT NULL UNIQUE,
  limit_type TEXT NOT NULL, -- otp_send, otp_verify, login, etc
  
  -- Counter state
  request_count INTEGER NOT NULL DEFAULT 0,
  last_reset TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  window_end TIMESTAMP WITH TIME ZONE NOT NULL,
  
  -- Metadata
  metadata JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rate_limit_identifier ON rate_limit_state(identifier);
CREATE INDEX idx_rate_limit_type ON rate_limit_state(limit_type);
CREATE INDEX idx_rate_limit_window_end ON rate_limit_state(window_end);

-- Auto-cleanup old rate limit records (optional)
CREATE OR REPLACE FUNCTION cleanup_expired_rate_limits()
RETURNS void AS $$
BEGIN
  DELETE FROM rate_limit_state 
  WHERE window_end < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────
-- 4. SESSION SECURITY ENHANCEMENTS
-- Purpose: Secure session management with tokens and expiry
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Session token info
  session_hash TEXT NOT NULL UNIQUE, -- SHA256 hash of session token
  refresh_token_hash TEXT UNIQUE,
  
  -- Session details
  ip_address INET,
  user_agent TEXT,
  device_info JSONB DEFAULT '{}'::jsonb,
  
  -- Session lifecycle
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  last_activity_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW() + INTERVAL '24 hours',
  revoked_at TIMESTAMP WITH TIME ZONE,
  
  -- Status
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  CONSTRAINT valid_expiry CHECK (expires_at > created_at)
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_active ON user_sessions(id) WHERE is_active = TRUE;
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_session_hash ON user_sessions(session_hash);

-- Policy: Users can only view their own sessions
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own sessions"
  ON user_sessions
  FOR SELECT
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────
-- 5. SECURITY TOKENS TABLE
-- Purpose: Manage security tokens (password reset, email verification, etc)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS security_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Token details
  token_hash TEXT NOT NULL UNIQUE, -- SHA256 hash
  token_type TEXT NOT NULL CHECK (token_type IN ('password_reset', 'email_verification', 'mfa_setup', 'device_verification')),
  
  -- Token lifecycle
  issued_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used_at TIMESTAMP WITH TIME ZONE,
  
  -- Metadata
  ip_address INET,
  user_agent TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  
  is_used BOOLEAN NOT NULL DEFAULT FALSE,
  
  CONSTRAINT valid_expiry CHECK (expires_at > issued_at)
);

CREATE INDEX idx_security_tokens_user_id ON security_tokens(user_id);
CREATE INDEX idx_security_tokens_type ON security_tokens(token_type);
CREATE INDEX idx_security_tokens_expires_at ON security_tokens(expires_at);
CREATE INDEX idx_security_tokens_token_hash ON security_tokens(token_hash);
CREATE INDEX idx_security_tokens_used ON security_tokens(is_used);

-- Auto-cleanup expired tokens
CREATE OR REPLACE FUNCTION cleanup_expired_tokens()
RETURNS void AS $$
BEGIN
  DELETE FROM security_tokens 
  WHERE expires_at < NOW() AND is_used = FALSE;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────
-- 6. SECURITY ALERTS
-- Purpose: Track and manage security alerts and suspicious activities
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS security_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Target
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  
  -- Alert details
  alert_type TEXT NOT NULL CHECK (alert_type IN ('brute_force', 'unusual_location', 'device_change', 'mass_export', 'permission_escalation', 'multiple_failures')),
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  
  -- Context
  ip_address INET,
  location_data JSONB DEFAULT '{}'::jsonb,
  
  -- Status
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'acknowledged', 'resolved')),
  acknowledged_at TIMESTAMP WITH TIME ZONE,
  acknowledged_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_security_alerts_user_id ON security_alerts(user_id);
CREATE INDEX idx_security_alerts_status ON security_alerts(status);
CREATE INDEX idx_security_alerts_severity ON security_alerts(severity);
CREATE INDEX idx_security_alerts_created_at ON security_alerts(created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────
-- 7. HELPER FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────

-- Function to get the user's session count
CREATE OR REPLACE FUNCTION get_user_active_sessions(user_uuid UUID)
RETURNS INTEGER AS $$
SELECT COUNT(*) FROM user_sessions
WHERE user_id = user_uuid AND is_active = TRUE AND expires_at > NOW();
$$ LANGUAGE SQL STABLE;

-- Function to revoke all user sessions
CREATE OR REPLACE FUNCTION revoke_all_user_sessions(user_uuid UUID)
RETURNS void AS $$
BEGIN
  UPDATE user_sessions 
  SET is_active = FALSE, revoked_at = NOW()
  WHERE user_id = user_uuid AND is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to check if IP has too many failed attempts
CREATE OR REPLACE FUNCTION check_ip_lockout(ip_addr INET)
RETURNS TABLE(locked_out BOOLEAN, locked_until TIMESTAMP WITH TIME ZONE, remaining_minutes INTEGER) AS $$
SELECT 
  (locked_until IS NOT NULL AND locked_until > NOW()) as locked_out,
  locked_until,
  EXTRACT(EPOCH FROM (locked_until - NOW()))/60::INTEGER as remaining_minutes
FROM failed_login_attempts
WHERE ip_address = ip_addr
ORDER BY updated_at DESC
LIMIT 1;
$$ LANGUAGE SQL STABLE;

-- ─────────────────────────────────────────────────────────────────────────
-- 8. GRANT PERMISSIONS
-- ─────────────────────────────────────────────────────────────────────────

-- Grant select on audit_logs to authenticated users (for their own records)
GRANT SELECT ON audit_logs TO authenticated;

-- Grant select/update on user_sessions to authenticated users
GRANT SELECT, UPDATE ON user_sessions TO authenticated;

-- Grant all on security tables to service role (for server operations)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- ─────────────────────────────────────────────────────────────────────────
-- 9. COMMENTS & DOCUMENTATION
-- ─────────────────────────────────────────────────────────────────────────

COMMENT ON TABLE audit_logs IS 'Security audit trail for compliance and investigation';
COMMENT ON TABLE failed_login_attempts IS 'Tracks failed login attempts for brute force protection';
COMMENT ON TABLE rate_limit_state IS 'Stores rate limiting state for API endpoints';
COMMENT ON TABLE user_sessions IS 'Manages user sessions with security tokens';
COMMENT ON TABLE security_tokens IS 'Manages time-limited security tokens (password reset, etc)';
COMMENT ON TABLE security_alerts IS 'Tracks and manages security alerts and suspicious activities';
