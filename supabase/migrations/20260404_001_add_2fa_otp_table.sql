-- 2FA Email OTP Table
CREATE TABLE IF NOT EXISTS public.user_2fa_otps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  otp_code TEXT NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  verified_at TIMESTAMP WITH TIME ZONE,
  attempts INT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_user_2fa_otps_user_id ON public.user_2fa_otps(user_id);
CREATE INDEX IF NOT EXISTS idx_user_2fa_otps_expires_at ON public.user_2fa_otps(expires_at);

-- 2FA Settings Table
CREATE TABLE IF NOT EXISTS public.user_2fa_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  is_enabled BOOLEAN DEFAULT false,
  email TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_user_2fa_settings_user_id ON public.user_2fa_settings(user_id);

-- Enable RLS
ALTER TABLE public.user_2fa_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_2fa_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for 2FA OTPs
CREATE POLICY "user_can_view_own_2fa_otps" ON public.user_2fa_otps
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "authenticated_can_insert_2fa_otps" ON public.user_2fa_otps
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- RLS Policies for 2FA Settings
CREATE POLICY "user_can_view_own_2fa_settings" ON public.user_2fa_settings
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "user_can_update_own_2fa_settings" ON public.user_2fa_settings
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "authenticated_can_insert_2fa_settings" ON public.user_2fa_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);
