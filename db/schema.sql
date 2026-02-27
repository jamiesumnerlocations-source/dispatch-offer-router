-- JOBS
CREATE TABLE IF NOT EXISTS jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  sheet_job_id TEXT NOT NULL UNIQUE,

  pickup_date TEXT,
  pickup_time TEXT,
  origin TEXT,
  destination TEXT,
  vehicle_type TEXT,

  coordinator_email TEXT,
  approval_token TEXT NOT NULL UNIQUE,
  approved_at TEXT,

  status TEXT NOT NULL DEFAULT 'needs_approval',
  assigned_agent_id INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- AGENTS (drivers)
CREATE TABLE IF NOT EXISTS agents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone_e164 TEXT NOT NULL UNIQUE,
  priority INTEGER NOT NULL,
  active INTEGER NOT NULL DEFAULT 1
);

-- OFFERS (attempts)
CREATE TABLE IF NOT EXISTS offers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  agent_id INTEGER NOT NULL,

  status TEXT NOT NULL DEFAULT 'sent', -- sent|accepted|declined|timed_out
  sent_at TEXT NOT NULL,
  responded_at TEXT,

  UNIQUE(job_id, agent_id),
  FOREIGN KEY(job_id) REFERENCES jobs(id),
  FOREIGN KEY(agent_id) REFERENCES agents(id)
);

CREATE INDEX IF NOT EXISTS idx_offers_status_sent_at ON offers(status, sent_at);
CREATE INDEX IF NOT EXISTS idx_agents_active_priority ON agents(active, priority);
