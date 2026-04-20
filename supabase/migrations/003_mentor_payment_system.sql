-- Create payment_methods table
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type VARCHAR(20) NOT NULL CHECK (type IN ('upi', 'bank')),
  upi_id VARCHAR(255),
  bank_name VARCHAR(100),
  account_number_encrypted TEXT,
  ifsc_code VARCHAR(15),
  holder_name VARCHAR(255),
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  CONSTRAINT upi_or_bank CHECK (
    (type = 'upi' AND upi_id IS NOT NULL) OR
    (type = 'bank' AND bank_name IS NOT NULL AND account_number_encrypted IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_payment_methods_mentor ON payment_methods(mentor_id);

-- Create withdrawal_requests table
CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  payment_method_id UUID NOT NULL REFERENCES payment_methods(id),
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  transaction_hash VARCHAR(255),
  failure_reason TEXT,
  requested_at TIMESTAMP DEFAULT NOW(),
  processed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_mentor ON withdrawal_requests(mentor_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status ON withdrawal_requests(status);

-- Create session_ratings table
CREATE TABLE IF NOT EXISTS session_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES mentor_sessions(id) ON DELETE CASCADE,
  mentor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_ratings_mentor ON session_ratings(mentor_id);
