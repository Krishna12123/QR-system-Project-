# ACCelerate'26 — QR System v2 Integration Guide

## What's New in v2

| Feature | Status |
|---|---|
| Secure random QR token (not plain participant ID) | ✅ |
| One-time QR mode (invalidates after scan) | ✅ |
| QR expiry date/time | ✅ |
| Auto email QR after registration | ✅ |
| "Send QR Again" button | ✅ |
| EmailJS integration + Settings panel | ✅ |
| Bulk email sending | ✅ |
| Animated scan flash + sound effects | ✅ |
| QR status badges (ACTIVE / USED / EXPIRED) | ✅ |
| Copy Participant ID button | ✅ |
| Scan cooldown protection | ✅ |
| Fake QR event validation | ✅ |
| Download Participant Pass as PDF | ✅ |
| Mini bar analytics charts | ✅ |
| Email sent tracking in Attendance | ✅ |
| Scan count tracking | ✅ |

---

## Step 1 — Update Supabase Schema

1. Open your Supabase project → **SQL Editor**
2. If **starting fresh**: paste the entire `accelerate26-schema-v2.sql` and run it
3. If you have **existing data**, only run the `ALTER TABLE` section (uncomment those lines first):

```sql
ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_token        TEXT UNIQUE;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_type         TEXT DEFAULT 'reusable';
ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_status       TEXT DEFAULT 'active';
ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_used         BOOLEAN DEFAULT FALSE;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_used_at      TIMESTAMPTZ;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS qr_used_by      TEXT;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS scan_count      INTEGER DEFAULT 0;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS last_scanned_at TIMESTAMPTZ;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS expires_at      TIMESTAMPTZ;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS email_sent      BOOLEAN DEFAULT FALSE;
ALTER TABLE participants ADD COLUMN IF NOT EXISTS email_sent_at   TIMESTAMPTZ;

ALTER TABLE checkin_logs ADD COLUMN IF NOT EXISTS qr_status_at_scan TEXT;
```

---

## Step 2 — Set Up EmailJS

### 2a. Create Account
1. Go to https://emailjs.com → Sign Up (free)
2. Connect your email provider (Gmail recommended):
   - Dashboard → **Email Services** → Add New Service → Gmail
   - Authorise with your Google account
   - Copy the **Service ID** (e.g. `service_abc123`)

### 2b. Create Email Template
1. Dashboard → **Email Templates** → Create New Template
2. Paste this template HTML (customise as needed):

```html
Subject: Your ACCelerate'26 QR Code — {{participant_id}}

Hello {{to_name}},

{{message}}

━━━━━━━━━━━━━━━━━━━━━
PARTICIPANT DETAILS
━━━━━━━━━━━━━━━━━━━━━
• Name:            {{to_name}}
• ID:              {{participant_id}}
• Category:        {{category}}
• Institute:       {{affiliation}}
• Amount Payable:  {{payable_amount}}
• Event:           {{event_name}}
━━━━━━━━━━━━━━━━━━━━━

Your QR Code:
[Add an image block in the template builder with src={{qr_image_url}}]

See you at the event!
— Team ACCelerate'26
```

3. In the template builder, set:
   - **To Email**: `{{to_email}}`
   - **To Name**: `{{to_name}}`
4. Save → copy the **Template ID** (e.g. `template_xyz456`)

### 2c. Get Your Public Key
1. Dashboard → **Account** → **General** tab
2. Copy the **Public Key**

### 2d. Enter in App
1. Open the app → **⚙️ Settings** tab
2. Fill in:
   - Public Key
   - Service ID
   - Template ID
3. Click **💾 Save Settings**
4. Use **Send Test Email** to verify

---

## Step 3 — Understanding the New QR Security System

### How it works

**Old (insecure):**
```json
{ "participant_id": "ACC-X4F2", "name": "John", "event": "ACCelerate26" }
```
Anyone who sees participant ID can forge a QR code.

**New (secure):**
```json
{ "token": "3f8a2c1d9e4b7a6f...", "event": "ACCelerate26" }
```
- Token is a 48-character cryptographically random hex string
- Token is stored in Supabase, linked to the participant
- QR never contains participant name or ID
- Even if someone screenshots a QR, a one-time QR is invalidated after first scan

### QR Types

| Type | Behaviour |
|---|---|
| **Reusable** | Can be scanned multiple times across days |
| **One-Time** | Invalidated permanently after first successful scan |

### QR Statuses

| Status | Meaning |
|---|---|
| `active` | Valid, ready to scan |
| `used` | Consumed (one-time mode) |
| `expired` | Past expiry date/time |

### Error Messages on Scan

| Message | Cause |
|---|---|
| ⚠️ Invalid QR Token | Token not found in database |
| 🚫 QR Already Used | One-time QR was already scanned |
| ⌛ Expired QR Code | Past the expiry datetime |
| ❌ Invalid QR — Wrong Event | QR contains wrong event name (forgery attempt) |
| ⚠️ Already Checked IN | Duplicate scan for same day |

---

## Step 4 — Security Configuration

In **⚙️ Settings → QR Security Defaults**:

- **Default to One-Time QR** — New registrations auto-use one-time mode
- **Scan Cooldown Protection** — 2-second delay between scans (prevents rapid-fire abuse)
- **Sound Effects** — Success/error beeps on scan
- **Auto-send Email** — Send QR email immediately after registration

---

## Step 5 — Handling Existing Participants (Migration)

If you have existing registrations without tokens, run this SQL to generate tokens for them:

```sql
-- Generate tokens for participants that don't have one yet
UPDATE participants
SET
  qr_token  = encode(gen_random_bytes(24), 'hex'),
  qr_type   = 'reusable',
  qr_status = 'active',
  qr_used   = FALSE
WHERE qr_token IS NULL;
```

> **Note:** `gen_random_bytes` requires the `pgcrypto` extension. Enable it in Supabase:
> Dashboard → Database → Extensions → search "pgcrypto" → Enable

---

## Folder Structure (if self-hosting)

```
accelerate26/
├── index.html                    ← Main app (accelerate26-checkin-v2.html)
├── accelerate26-schema-v2.sql    ← Run once in Supabase SQL Editor
├── README.md                     ← This guide
└── assets/                       ← (optional) logos, favicons
```

---

## Environment / Config Reference

All configuration is stored in `localStorage` under these keys:

| Key | Contents |
|---|---|
| `acc26_ejs` | `{ pk, svc, tpl }` — EmailJS credentials |
| `acc26_sec` | `{ defaultOnetime, cooldown, sound, autoEmail }` — Security settings |

Supabase URL and Key are entered at login and are NOT persisted (for security).

---

## EmailJS Free Plan Limits

| Limit | Value |
|---|---|
| Emails/month | 200 |
| Requests/month | 200 |
| Templates | 2 |

For larger events (200+ participants), upgrade to EmailJS paid plan or use a backend mailer (Resend, SendGrid, etc.).

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "QR not found" on scan | Participant registered without token — run migration SQL |
| Email not sending | Check EmailJS credentials in Settings → Send Test Email |
| "Wrong Event" on valid QR | Old QR was generated before v2 — re-register or scan manually |
| Camera not starting | Use HTTPS (required for camera access) |
| PDF download blank | Generate QR first before downloading pass |
| Cooldown too long | Disable in Settings → QR Security → Scan Cooldown |
