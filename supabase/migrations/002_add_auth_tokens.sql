-- ============================================================================
-- OTP & PASSWORD RESET TOKENS
-- ============================================================================

-- OTP tokens for email verification during signup
CREATE TABLE IF NOT EXISTS otp_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL,
  otp_code VARCHAR(6) NOT NULL,
  type VARCHAR(50) NOT NULL CHECK (type IN ('signup', 'password_reset')),
  user_data JSONB, -- For signup: {name, role, password_hash}
  expires_at TIMESTAMP NOT NULL,
  verified_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_otp_tokens_email_type ON otp_tokens(email, type);
CREATE INDEX idx_otp_tokens_expires_at ON otp_tokens(expires_at);
CREATE INDEX idx_otp_tokens_created_at ON otp_tokens(created_at DESC);

-- Clean up expired OTP tokens (job runs periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS void AS $$
BEGIN
  DELETE FROM otp_tokens WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;
