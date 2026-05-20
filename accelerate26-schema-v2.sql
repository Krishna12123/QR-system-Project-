-- ============================================================
-- ACCelerate'26 — Supabase SQL Schema v2
-- Run this in your Supabase SQL Editor
-- ============================================================

-- ============================================================
-- TABLE: participants
-- (If you already have this table, use the ALTER section below)
-- ============================================================
CREATE TABLE IF NOT EXISTS participants (
  id                BIGSERIAL PRIMARY KEY,
  participant_id    TEXT UNIQUE NOT NULL,         -- Display ID: ACC-XXXX

  -- Personal info
  name              TEXT NOT NULL,
  email             TEXT UNIQUE NOT NULL,
  mobile            TEXT,
  affiliation       TEXT,
  designation       TEXT,
  address           TEXT,
  gender            TEXT,
  category          TEXT,
  category_type     TEXT,                         -- Student | Faculty / Staff
  amity_associated  TEXT,                         -- Yes | No

  -- Fee info
  amount            TEXT,
  gst_amount        TEXT,
  payable_amount    TEXT,

  -- ✨ NEW: Secure QR Token System
  qr_token          TEXT UNIQUE,                  -- Cryptographically secure random token (in QR)
  qr_type           TEXT DEFAULT 'reusable',      -- 'one-time' | 'reusable'
  qr_status         TEXT DEFAULT 'active',        -- 'active' | 'used' | 'expired'
  qr_used           BOOLEAN DEFAULT FALSE,        -- True after one-time QR is consumed
  qr_used_at        TIMESTAMPTZ,                  -- When was the one-time QR first used
  qr_used_by        TEXT,                         -- Who scanned it (e.g. 'Admin')
  scan_count        INTEGER DEFAULT 0,            -- Total number of times scanned
  last_scanned_at   TIMESTAMPTZ,                  -- Timestamp of most recent scan
  expires_at        TIMESTAMPTZ,                  -- Optional QR expiry datetime

  -- ✨ NEW: Email tracking
  email_sent        BOOLEAN DEFAULT FALSE,        -- Was QR email sent?
  email_sent_at     TIMESTAMPTZ,                  -- When was it sent?

  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ALTER TABLE: If participants table already exists, run these
-- ============================================================
-- Uncomment and run these if adding to existing table:

-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_token        TEXT UNIQUE;
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_type         TEXT DEFAULT 'reusable';
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_status       TEXT DEFAULT 'active';
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_used         BOOLEAN DEFAULT FALSE;
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_used_at      TIMESTAMPTZ;
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_used_by      TEXT;
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS scan_count      INTEGER DEFAULT 0;
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS last_scanned_at TIMESTAMPTZ;
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS expires_at      TIMESTAMPTZ;
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS email_sent      BOOLEAN DEFAULT FALSE;
-- ALTER TABLE participants ADD COLUMN IF NOT EXISTS email_sent_at   TIMESTAMPTZ;


-- ============================================================
-- TABLE: checkin_logs
-- ============================================================
CREATE TABLE IF NOT EXISTS checkin_logs (
  id                 BIGSERIAL PRIMARY KEY,
  participant_id     TEXT NOT NULL REFERENCES participants(participant_id) ON DELETE CASCADE,
  action_type        TEXT NOT NULL CHECK (action_type IN ('checkin', 'checkout')),
  day_number         INTEGER NOT NULL CHECK (day_number BETWEEN 1 AND 3),
  scanned_by         TEXT DEFAULT 'Admin',
  qr_status_at_scan  TEXT,                        -- ✨ NEW: Snapshot of QR status when scanned
  created_at         TIMESTAMPTZ DEFAULT NOW()
);

-- ALTER to add new column if table exists:
-- ALTER TABLE checkin_logs ADD COLUMN IF NOT EXISTS qr_status_at_scan TEXT;


-- ============================================================
-- INDEXES (for performance)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_participants_token     ON participants(qr_token);
CREATE INDEX IF NOT EXISTS idx_participants_pid       ON participants(participant_id);
CREATE INDEX IF NOT EXISTS idx_participants_email     ON participants(email);
CREATE INDEX IF NOT EXISTS idx_checkin_pid            ON checkin_logs(participant_id);
CREATE INDEX IF NOT EXISTS idx_checkin_day_action     ON checkin_logs(day_number, action_type);


-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
-- Enable RLS on both tables
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkin_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all operations with anon key (adjust for production)
-- For production, restrict to authenticated users or service role only

CREATE POLICY IF NOT EXISTS "Allow anon read participants"
  ON participants FOR SELECT USING (true);

CREATE POLICY IF NOT EXISTS "Allow anon insert participants"
  ON participants FOR INSERT WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "Allow anon update participants"
  ON participants FOR UPDATE USING (true);

CREATE POLICY IF NOT EXISTS "Allow anon read logs"
  ON checkin_logs FOR SELECT USING (true);

CREATE POLICY IF NOT EXISTS "Allow anon insert logs"
  ON checkin_logs FOR INSERT WITH CHECK (true);


-- ============================================================
-- OPTIONAL: Useful Views
-- ============================================================

-- View: Participant summary with attendance
CREATE OR REPLACE VIEW participant_attendance_summary AS
SELECT
  p.participant_id,
  p.name,
  p.email,
  p.category,
  p.qr_status,
  p.qr_type,
  p.scan_count,
  p.email_sent,
  p.payable_amount,
  BOOL_OR(l.day_number = 1 AND l.action_type = 'checkin') AS day1_attended,
  BOOL_OR(l.day_number = 2 AND l.action_type = 'checkin') AS day2_attended,
  BOOL_OR(l.day_number = 3 AND l.action_type = 'checkin') AS day3_attended,
  COUNT(CASE WHEN l.action_type = 'checkin' THEN 1 END) AS total_days_attended
FROM participants p
LEFT JOIN checkin_logs l ON l.participant_id = p.participant_id
GROUP BY p.id, p.participant_id;


-- View: Real-time inside count
CREATE OR REPLACE VIEW current_inside AS
SELECT
  participant_id,
  MAX(created_at) AS last_action_time,
  (ARRAY_AGG(action_type ORDER BY created_at DESC))[1] AS last_action
FROM checkin_logs
GROUP BY participant_id
HAVING (ARRAY_AGG(action_type ORDER BY created_at DESC))[1] = 'checkin';


-- ============================================================
-- OPTIONAL: Auto-expire QR tokens (run via cron or function)
-- ============================================================
-- Run this query periodically to expire QRs past their expiry date:
--
-- UPDATE participants
-- SET qr_status = 'expired'
-- WHERE expires_at IS NOT NULL
--   AND expires_at < NOW()
--   AND qr_status = 'active';
