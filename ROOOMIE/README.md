# 🗄️ main_system_db — Complete MySQL System

Production-ready MySQL database system with users, pairings,
activity logging, stored procedures, triggers, views, REST API,
and a live admin dashboard.

---

## 📁 Project Structure

```
mysql-system/
├── database/
│   ├── 01_schema.sql              ← Tables, indexes, constraints
│   ├── 02_procedures.sql          ← 8 stored procedures
│   ├── 03_functions_triggers.sql  ← Functions + 5 triggers + event
│   ├── 04_views.sql               ← 10 live views (Workbench-ready)
│   └── 05_sample_data_and_queries.sql ← Data + full CRUD examples
├── backend/
│   ├── server.js                  ← Node.js Express REST API
│   ├── package.json
│   └── .env.example               ← Copy to .env and fill in values
└── frontend/
    └── dashboard.html             ← Live admin dashboard (open in browser)
```

---

## ⚡ QUICK START

### Step 1 — Run SQL in MySQL Workbench

Open MySQL Workbench → connect to your server → run files in order:

```sql
-- File > Open SQL Script → select each file → Ctrl+Shift+Enter
01_schema.sql
02_procedures.sql
03_functions_triggers.sql
04_views.sql
05_sample_data_and_queries.sql   ← Loads 10 users + 6 pairings
```

### Step 2 — Open Live Dashboard

Just double-click `frontend/dashboard.html` in your browser.
Works immediately with built-in mock data — no backend needed.

### Step 3 — Run Backend (optional, for live API)

```bash
cd backend
cp .env.example .env
# Edit .env with your MySQL credentials
npm install
npm start
# API runs at http://localhost:4000
```

---

## 🗃️ Database Objects

### Tables (6)
| Table | Description |
|-------|-------------|
| `users` | Core user accounts with auth + profile |
| `user_profiles` | Lifestyle data (food, sleep, cleanliness...) |
| `pairings` | Relationships between users |
| `activity_logs` | Full audit trail (JSON old/new values) |
| `sessions` | Active login sessions |
| `notifications` | User notification inbox |

### Views — Use in MySQL Workbench (10)
```sql
SELECT * FROM vw_all_users;            -- All registered users
SELECT * FROM vw_active_users;         -- Active users only
SELECT * FROM vw_available_users;      -- Users without an active pairing
SELECT * FROM vw_all_pairings;         -- All pairings with names + scores
SELECT * FROM vw_active_pairings;      -- Accepted pairs only
SELECT * FROM vw_pending_pairings;     -- Pending requests
SELECT * FROM vw_dashboard_stats;      -- Summary numbers
SELECT * FROM vw_top_matches;          -- Highest compatibility scores
SELECT * FROM vw_recent_activity;      -- Last 100 events
SELECT * FROM vw_user_activity_summary;-- Per-user stats
```

### Stored Procedures (8)
| Procedure | Description |
|-----------|-------------|
| `sp_create_user(...)` | Register user + auto-create profile row |
| `sp_update_user(...)` | Update name/phone/gender/bio |
| `sp_delete_user(...)` | Soft or hard delete with logging |
| `sp_save_profile(...)` | Upsert lifestyle profile |
| `sp_send_pairing_request(...)` | Send request with auto-score |
| `sp_respond_to_pairing(...)` | Accept or reject |
| `sp_cancel_pairing(...)` | Cancel sent request |

### Functions (2)
| Function | Returns |
|----------|---------|
| `fn_compatibility_score(id1, id2)` | DECIMAL 0–100 (weighted match) |
| `fn_user_pairing_status(id)` | 'paired' / 'pending' / 'available' |

### Triggers (5)
| Trigger | When | Purpose |
|---------|------|---------|
| `trg_after_user_insert` | INSERT users | Logs creation event |
| `trg_after_user_update` | UPDATE users | Diffs and logs changes |
| `trg_before_pairing_insert` | INSERT pairings | Normalises IDs + auto-score |
| `trg_after_pairing_update` | UPDATE pairings | Logs status transitions |

### Scheduled Event
- `evt_expire_pairings` — runs every hour, expires overdue pending requests

---

## 📋 Common Workbench Queries

### Real-time monitoring — open in separate tabs, press Ctrl+Enter to refresh

```sql
-- Tab 1: Live user counts
SELECT status, COUNT(*) AS count FROM users GROUP BY status;

-- Tab 2: Live pairing summary
SELECT pairing_status, COUNT(*), AVG(match_score) FROM pairings GROUP BY pairing_status;

-- Tab 3: Live activity stream (last 10)
SELECT created_at, action, message FROM activity_logs ORDER BY log_id DESC LIMIT 10;

-- Tab 4: Users joined today
SELECT user_id, name, email, created_at FROM users WHERE DATE(created_at) = CURDATE();
```

### CRUD examples

```sql
-- CREATE: Register user
CALL sp_create_user('Arjun Sharma','arjun@test.com','$2b$hashed','9876543210','Male','Bio',@uid);
SELECT @uid;

-- READ: Search users
SELECT * FROM vw_all_users WHERE name LIKE '%Arjun%';

-- UPDATE: Change user info
CALL sp_update_user(1, 'Arjun Kumar', '9999999999', 'Male', 'Updated bio');

-- DELETE: Soft delete
CALL sp_delete_user(1, 0, 10);  -- 0=soft, admin_id=10

-- PAIRING: Send request
CALL sp_send_pairing_request(1, 3, 'Want to pair up?', @pid);
SELECT @pid;

-- PAIRING: Accept
CALL sp_respond_to_pairing(1, 3, 'accept');

-- COMPATIBILITY: Check score
SELECT fn_compatibility_score(1, 5) AS score;
```

---

## 🔗 API Endpoints (backend running on port 4000)

```
GET    /api/users                 All users (filterable)
GET    /api/users/:id             Single user
POST   /api/users                 Register user
PUT    /api/users/:id             Update user
DELETE /api/users/:id             Delete user
PUT    /api/users/:id/profile     Save lifestyle profile
GET    /api/users/available       Users not in active pairing
GET    /api/pairings              All pairings
GET    /api/pairings/user/:id     Pairings for specific user
POST   /api/pairings              Send pairing request
PATCH  /api/pairings/:id/respond  Accept or reject
PATCH  /api/pairings/:id/cancel   Cancel request
GET    /api/compatibility/:a/:b   Compatibility score
GET    /api/stats                 Dashboard summary
GET    /api/activity              Activity log
```

---

## 🧪 Verify Everything Works

```sql
-- Check all tables have data
SELECT 'users' AS tbl, COUNT(*) FROM users
UNION ALL SELECT 'pairings',    COUNT(*) FROM pairings
UNION ALL SELECT 'activity_logs',COUNT(*) FROM activity_logs;

-- Check triggers fired
SELECT action, COUNT(*) FROM activity_logs GROUP BY action;

-- Check auto-calculated scores
SELECT pairing_id, match_score FROM pairings WHERE match_score IS NOT NULL;

-- Check views work
SELECT total_users, active_pairings, events_today FROM vw_dashboard_stats;
```
