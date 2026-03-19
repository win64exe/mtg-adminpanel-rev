const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '../data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

const db = new Database(path.join(DATA_DIR, 'mtg-panel.db'));
try { db.pragma('journal_mode = WAL'); } catch (_) {}
try { db.pragma('synchronous = NORMAL'); } catch (_) {}
try { db.pragma('foreign_keys = ON'); } catch (_) {}
try { db.pragma('busy_timeout = 5000'); } catch (_) {}

// ── Tables ────────────────────────────────────────────────
db.exec(`
  CREATE TABLE IF NOT EXISTS nodes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    host TEXT NOT NULL,
    ssh_user TEXT DEFAULT 'root',
    ssh_port INTEGER DEFAULT 22,
    ssh_key TEXT,
    ssh_password TEXT,
    base_dir TEXT DEFAULT '/opt/mtg/users',
    start_port INTEGER DEFAULT 4433,
    flag TEXT,
    agent_port INTEGER DEFAULT 8081,
    mtg_image TEXT,
    secret_domain TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    port INTEGER,
    secret TEXT,
    note TEXT,
    expires_at DATETIME,
    traffic_limit_gb INTEGER,
    traffic_reset_interval TEXT,
    next_reset_at DATETIME,
    max_devices INTEGER,
    total_traffic_rx_bytes INTEGER DEFAULT 0,
    total_traffic_tx_bytes INTEGER DEFAULT 0,
    traffic_rx_snap TEXT,
    traffic_tx_snap TEXT,
    billing_price REAL,
    billing_currency TEXT DEFAULT 'RUB',
    billing_period TEXT DEFAULT 'monthly',
    billing_paid_until DATETIME,
    billing_status TEXT DEFAULT 'active',
    status TEXT DEFAULT 'active',
    last_seen_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(node_id) REFERENCES nodes(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS connections_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id INTEGER NOT NULL,
    user_name TEXT NOT NULL,
    connections INTEGER DEFAULT 0,
    recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
  );

  CREATE INDEX IF NOT EXISTS idx_users_node_name ON users(node_id, name);
  CREATE INDEX IF NOT EXISTS idx_users_node_status ON users(node_id, status);
  CREATE INDEX IF NOT EXISTS idx_users_last_seen ON users(last_seen_at);
  CREATE INDEX IF NOT EXISTS idx_hist_node_user_time ON connections_history(node_id, user_name, recorded_at);
  CREATE INDEX IF NOT EXISTS idx_nodes_host ON nodes(host);
  CREATE INDEX IF NOT EXISTS idx_settings_key ON settings(key);
`);

module.exports = db;
