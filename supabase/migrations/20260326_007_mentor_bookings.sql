-- Create mentor_bookings table
CREATE TABLE IF NOT EXISTS public.mentor_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  mentor_name VARCHAR(255) NOT NULL,
  mentor_subject VARCHAR(255) NOT NULL,
  selected_date_time VARCHAR(255) NOT NULL,
  duration VARCHAR(50) NOT NULL,
  payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('UPI', 'Bank')),
  payment_app VARCHAR(100),
  upi_id VARCHAR(255),
  bank_account_holder VARCHAR(255),
  bank_name VARCHAR(255),
  bank_account_number VARCHAR(50),
  bank_ifsc_code VARCHAR(20),
  booking_price DECIMAL(10, 2) DEFAULT 500.00,
  status VARCHAR(50) DEFAULT 'confirmed' CHECK (status IN ('pending', 'confirmed', 'cancelled')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_mentor_bookings_student_id 
  ON public.mentor_bookings(student_id);

CREATE INDEX IF NOT EXISTS idx_mentor_bookings_status 
  ON public.mentor_bookings(status);

CREATE INDEX IF NOT EXISTS idx_mentor_bookings_created_at 
  ON public.mentor_bookings(created_at);

-- Enable RLS
ALTER TABLE public.mentor_bookings ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own bookings
CREATE POLICY "mentor_bookings_select_own"
  ON public.mentor_bookings
  FOR SELECT
  USING (student_id = auth.uid());

-- Users can insert their own bookings
CREATE POLICY "mentor_bookings_insert_own"
  ON public.mentor_bookings
  FOR INSERT
  WITH CHECK (student_id = auth.uid());

-- Users can update their own bookings
CREATE POLICY "mentor_bookings_update_own"
  ON public.mentor_bookings
  FOR UPDATE
  USING (student_id = auth.uid())
  WITH CHECK (student_id = auth.uid());

-- Users can delete their own bookings
CREATE POLICY "mentor_bookings_delete_own"
  ON public.mentor_bookings
  FOR DELETE
  USING (student_id = auth.uid());

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.mentor_bookings;
ALTER TABLE public.mentor_bookings REPLICA IDENTITY FULL;
