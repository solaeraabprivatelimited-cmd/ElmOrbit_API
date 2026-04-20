-- ============================================================================
-- AI MENTOR CHAT SESSIONS - Dynamic Chat Naming & Per-Account Storage
-- ============================================================================
-- Created: April 14, 2026
-- Purpose: Store AI mentor chat sessions with custom names, history, and metadata

-- ============================================================================
-- AI CHAT SESSIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_chat_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL DEFAULT 'New Chat',
  description TEXT,
  chat_type VARCHAR(50) NOT NULL DEFAULT 'text' CHECK (chat_type IN ('text', 'voice')),
  -- Metadata
  total_messages INT DEFAULT 0,
  total_tokens INT DEFAULT 0,
  is_pinned BOOLEAN DEFAULT FALSE,
  is_archived BOOLEAN DEFAULT FALSE,
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_message_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_ai_chat_sessions_user_id ON public.ai_chat_sessions(user_id);
CREATE INDEX idx_ai_chat_sessions_created_at ON public.ai_chat_sessions(created_at DESC);
CREATE INDEX idx_ai_chat_sessions_updated_at ON public.ai_chat_sessions(updated_at DESC);
CREATE INDEX idx_ai_chat_sessions_user_created ON public.ai_chat_sessions(user_id, created_at DESC);
CREATE INDEX idx_ai_chat_sessions_is_pinned ON public.ai_chat_sessions(is_pinned) WHERE is_pinned = TRUE;
CREATE INDEX idx_ai_chat_sessions_is_archived ON public.ai_chat_sessions(is_archived) WHERE is_archived = FALSE;

-- ============================================================================
-- AI CHAT MESSAGES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.ai_chat_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('user', 'ai')),
  content TEXT NOT NULL CHECK (char_length(content) > 0 AND char_length(content) <= 10000),
  -- Attachments (if any)
  attachment_type VARCHAR(50) CHECK (attachment_type IN ('image', 'file', NULL)),
  attachment_url TEXT,
  attachment_name VARCHAR(255),
  -- Metadata
  tokens_used INT DEFAULT 0,
  reaction VARCHAR(20), -- e.g., "👍", "👎", NULL
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  edited_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_ai_chat_messages_session_id ON public.ai_chat_messages(session_id);
CREATE INDEX idx_ai_chat_messages_user_id ON public.ai_chat_messages(user_id);
CREATE INDEX idx_ai_chat_messages_role ON public.ai_chat_messages(role);
CREATE INDEX idx_ai_chat_messages_created_at ON public.ai_chat_messages(created_at DESC);
CREATE INDEX idx_ai_chat_messages_session_created ON public.ai_chat_messages(session_id, created_at DESC);

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE IF EXISTS public.ai_chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ai_chat_messages ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES - AI CHAT SESSIONS
-- ============================================================================
DROP POLICY IF EXISTS "ai_chat_sessions_select_own" ON public.ai_chat_sessions;
CREATE POLICY "ai_chat_sessions_select_own"
  ON public.ai_chat_sessions
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "ai_chat_sessions_insert_own" ON public.ai_chat_sessions;
CREATE POLICY "ai_chat_sessions_insert_own"
  ON public.ai_chat_sessions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "ai_chat_sessions_update_own" ON public.ai_chat_sessions;
CREATE POLICY "ai_chat_sessions_update_own"
  ON public.ai_chat_sessions
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "ai_chat_sessions_delete_own" ON public.ai_chat_sessions;
CREATE POLICY "ai_chat_sessions_delete_own"
  ON public.ai_chat_sessions
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES - AI CHAT MESSAGES
-- ============================================================================
DROP POLICY IF EXISTS "ai_chat_messages_select_own_session" ON public.ai_chat_messages;
CREATE POLICY "ai_chat_messages_select_own_session"
  ON public.ai_chat_messages
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.ai_chat_sessions
      WHERE ai_chat_sessions.id = ai_chat_messages.session_id
      AND ai_chat_sessions.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "ai_chat_messages_insert_own_session" ON public.ai_chat_messages;
CREATE POLICY "ai_chat_messages_insert_own_session"
  ON public.ai_chat_messages
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.ai_chat_sessions
      WHERE ai_chat_sessions.id = ai_chat_messages.session_id
      AND ai_chat_sessions.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "ai_chat_messages_update_own_session" ON public.ai_chat_messages;
CREATE POLICY "ai_chat_messages_update_own_session"
  ON public.ai_chat_messages
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.ai_chat_sessions
      WHERE ai_chat_sessions.id = ai_chat_messages.session_id
      AND ai_chat_sessions.user_id = auth.uid()
    )
  );

-- ============================================================================
-- HELPER FUNCTION: Update session metadata on message insert
-- ============================================================================
DROP FUNCTION IF EXISTS public.update_ai_chat_session_metadata CASCADE;
CREATE OR REPLACE FUNCTION public.update_ai_chat_session_metadata()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.ai_chat_sessions
  SET
    total_messages = total_messages + 1,
    last_message_at = NEW.created_at,
    updated_at = NOW()
  WHERE id = NEW.session_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_ai_chat_session_metadata ON public.ai_chat_messages;
CREATE TRIGGER trigger_update_ai_chat_session_metadata
  AFTER INSERT ON public.ai_chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.update_ai_chat_session_metadata();

-- ============================================================================
-- HELPER FUNCTION: Auto-generate chat name from first message
-- ============================================================================
DROP FUNCTION IF EXISTS public.generate_chat_session_name CASCADE;
CREATE OR REPLACE FUNCTION public.generate_chat_session_name()
RETURNS TRIGGER AS $$
DECLARE
  first_message TEXT;
BEGIN
  -- Only generate name if it's still the default "New Chat"
  IF NEW.name = 'New Chat' THEN
    -- Get the first user message in this session
    SELECT content INTO first_message
    FROM public.ai_chat_messages
    WHERE session_id = NEW.id AND role = 'user'
    ORDER BY created_at ASC
    LIMIT 1;
    
    -- Generate name from first 50 characters of first message
    IF first_message IS NOT NULL THEN
      NEW.name := SUBSTRING(first_message, 1, 50);
      IF CHAR_LENGTH(first_message) > 50 THEN
        NEW.name := NEW.name || '...';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON public.ai_chat_sessions TO authenticated;
GRANT ALL ON public.ai_chat_messages TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_ai_chat_session_metadata TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_chat_session_name TO authenticated;
