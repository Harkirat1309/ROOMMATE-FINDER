
USE main_system_db;


-- ── Insert Users (password = 'Password123' bcrypt hash) ───────
INSERT INTO users (name, email, password_hash, phone, gender, bio, role, status) VALUES
('Arjun Sharma',    'arjun@demo.com',   '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_1', '9876543210', 'Male',   'CS engineer, love chess and coding', 'user',  'active'),
('Priya Mehta',     'priya@demo.com',   '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_2', '9876543211', 'Female', 'Yoga enthusiast, early riser',       'user',  'active'),
('Rahul Verma',     'rahul@demo.com',   '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_3', '9876543212', 'Male',   'Music lover, night owl',             'user',  'active'),
('Sneha Patel',     'sneha@demo.com',   '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_4', '9876543213', 'Female', 'Artist, flexible schedule',          'user',  'active'),
('Vikram Singh',    'vikram@demo.com',  '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_5', '9876543214', 'Male',   'Introvert, focused on studies',      'user',  'active'),
('Anjali Gupta',    'anjali@demo.com',  '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_6', '9876543215', 'Female', 'Vegan, health conscious',            'user',  'active'),
('Karan Joshi',     'karan@demo.com',   '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_7', '9876543216', 'Male',   'Social butterfly, cricket fan',      'user',  'active'),
('Neha Agarwal',    'neha@demo.com',    '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_8', '9876543217', 'Female', 'Painter, quiet study sessions',      'user',  'active'),
('Rohan Das',       'rohan@demo.com',   '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_9', '9876543218', 'Male',   'Cook, guitar player',                'user',  'active'),
('Divya Nair',      'divya@demo.com',   '$2b$12$eW5.mZL9fQ8XkHcJuTnY4.sample_hash_10','9876543219', 'Female', 'Book worm, very neat',               'admin', 'active');

-- ── Insert Profiles ───────────────────────────────────────────
INSERT INTO user_profiles
    (user_id, food_preference, sleep_schedule, cleanliness_level,
     study_habit, social_type, hobbies, location, occupation)
VALUES
(1, 'Non-Veg', 'Night Owl',  4, 'Silent',   'Introvert', 'Chess, Coding',     'Block-A, Hostel', 'CS Student'),
(2, 'Veg',     'Early Bird', 5, 'Silent',   'Introvert', 'Yoga, Reading',     'Block-B, Hostel', 'Med Student'),
(3, 'Non-Veg', 'Night Owl',  3, 'Music',    'Extrovert', 'Guitar, Gaming',    'Block-A, Hostel', 'EC Student'),
(4, 'Veg',     'Flexible',   4, 'Flexible', 'Ambivert',  'Art, Dancing',      'Block-C, Hostel', 'Design Student'),
(5, 'Any',     'Night Owl',  3, 'Silent',   'Introvert', 'Reading, Coding',   'Block-A, Hostel', 'CS Student'),
(6, 'Vegan',   'Early Bird', 5, 'Silent',   'Ambivert',  'Meditation,Running','Block-B, Hostel', 'Pharmacy Student'),
(7, 'Non-Veg', 'Flexible',   2, 'Group',    'Extrovert', 'Cricket, Movies',   'Block-A, Hostel', 'MBA Student'),
(8, 'Veg',     'Early Bird', 4, 'Silent',   'Introvert', 'Painting, Writing', 'Block-C, Hostel', 'Arts Student'),
(9, 'Any',     'Night Owl',  3, 'Music',    'Ambivert',  'Cooking, Guitar',   'Block-B, Hostel', 'Engineering'),
(10,'Veg',     'Flexible',   5, 'Silent',   'Introvert', 'Books, Puzzles',    'Block-B, Hostel', 'Admin');

-- ── Insert Pairings ───────────────────────────────────────────
-- NOTE: Scores auto-calculated by trg_before_pairing_insert
INSERT INTO pairings
    (user_id_1, user_id_2, pairing_status, message, initiated_by, responded_at)
VALUES
(1, 5, 'accepted', 'We both love coding and are night owls!', 1, NOW()),
(2, 8, 'accepted', 'Both early birds and Veg — perfect match!', 2, NOW()),
(3, 7, 'pending',  'Hey Karan, I think we would vibe!',         3, NULL),
(4, 9, 'pending',  'Flexible schedules — could work well.',     4, NULL),
(6, 2, 'rejected', 'Looking for a vegan roommate.',             6, NOW()),
(5, 3, 'cancelled','Changed my mind.',                          5, NULL);

-- ── Update last_login for realism ─────────────────────────────
UPDATE users SET last_login = DATE_SUB(NOW(), INTERVAL FLOOR(RAND()*72) HOUR)
WHERE user_id BETWEEN 1 AND 10;


-- ── Q1: See ALL users (live, refreshes on each run) ───────────
SELECT * FROM vw_all_users;

-- ── Q2: Active users only ─────────────────────────────────────
SELECT * FROM vw_active_users;

-- ── Q3: Users available for pairing ──────────────────────────
SELECT * FROM vw_available_users;

-- ── Q4: ALL pairings ──────────────────────────────────────────
SELECT * FROM vw_all_pairings;

-- ── Q5: Only accepted (live) pairings ─────────────────────────
SELECT * FROM vw_active_pairings;

-- ── Q6: Pending requests waiting for response ─────────────────
SELECT * FROM vw_pending_pairings;

-- ── Q7: Recent activity feed ──────────────────────────────────
SELECT * FROM vw_recent_activity;

-- ── Q8: Dashboard summary stats ───────────────────────────────
SELECT * FROM vw_dashboard_stats;

-- ── Q9: Top compatibility matches ─────────────────────────────
SELECT * FROM vw_top_matches LIMIT 10;

-- ── Q10: User activity summary ────────────────────────────────
SELECT * FROM vw_user_activity_summary;


-- ─────────────────── CREATE ────────────────────────────────────

-- Create a new user via procedure
CALL sp_create_user(
    'Test User',
    'testuser@demo.com',
    '$2b$12$hashedpassword',
    '9999999999',
    'Male',
    'I am a test user',
    @new_user_id
);
SELECT @new_user_id AS new_user_id;

-- Save/update their profile
CALL sp_save_profile(
    @new_user_id,
    'Veg',        -- food
    'Flexible',   -- sleep
    4,            -- cleanliness
    'Silent',     -- study
    'Ambivert',   -- social
    'Football, Reading',
    'Hostel Block-D',
    'Engineering Student'
);

-- Send a pairing request
CALL sp_send_pairing_request(
    @new_user_id,   -- from
    3,              -- to (Rahul)
    'Hi! Want to be roommates?',
    @pairing_id
);
SELECT @pairing_id AS pairing_id;

-- ─────────────────── READ ──────────────────────────────────────

-- Get a single user by ID
SELECT
    u.user_id, u.name, u.email, u.gender, u.status, u.created_at,
    up.food_preference, up.sleep_schedule, up.cleanliness_level,
    up.study_habit, up.social_type, up.hobbies,
    fn_user_pairing_status(u.user_id) AS pairing_status
FROM  users u
LEFT JOIN user_profiles up ON up.user_id = u.user_id
WHERE u.user_id = 1;

-- Search users by name or email
SELECT user_id, name, email, status, created_at
FROM   users
WHERE  name LIKE '%Arjun%' OR email LIKE '%arjun%';

-- Users created today
SELECT user_id, name, email, created_at
FROM   users
WHERE  DATE(created_at) = CURDATE();

-- Compatibility score between two users
SELECT fn_compatibility_score(1, 5) AS compatibility_score;

-- All pairings for a specific user
SELECT * FROM vw_all_pairings
WHERE  user_id_1 = 1 OR user_id_2 = 1;

-- Activity log for a user
SELECT log_id, action, entity_type, message, created_at
FROM   activity_logs
WHERE  user_id = 1
ORDER  BY created_at DESC;

-- ─────────────────── UPDATE ────────────────────────────────────

-- Update user info via procedure
CALL sp_update_user(
    1,              -- user_id
    'Arjun Kumar',  -- new name
    '9876543299',   -- new phone
    'Male',         -- gender
    'Updated bio!'  -- bio
);

-- Update user status (admin action)
UPDATE users
SET    status = 'active'
WHERE  user_id = 1;

-- Verify user's email
UPDATE users
SET    email_verified = 1
WHERE  email = 'arjun@demo.com';

-- Accept a pairing request
CALL sp_respond_to_pairing(3, 7, 'accept');  -- pairing 3, user 7 accepts

-- ─────────────────── DELETE ────────────────────────────────────

-- Soft delete (recommended — keeps audit trail)
CALL sp_delete_user(
    @new_user_id,  -- user to delete
    0,             -- 0 = soft delete (sets status=inactive)
    10             -- admin performing the action
);

-- Hard delete (permanent — cascades to all related rows)
-- CALL sp_delete_user(@new_user_id, 1, 10);

-- Cancel a pairing request
CALL sp_cancel_pairing(4, 4);


-- ── WINDOW 1: Live user count by status ───────────────────────
SELECT
    status,
    COUNT(*)                                    AS user_count,
    COUNT(CASE WHEN DATE(created_at) = CURDATE() THEN 1 END) AS joined_today
FROM   users
GROUP  BY status;

-- ── WINDOW 2: Live pairing counts by status ───────────────────
SELECT
    pairing_status,
    COUNT(*)                                    AS count,
    AVG(match_score)                            AS avg_score,
    MAX(created_at)                             AS latest
FROM   pairings
GROUP  BY pairing_status;

-- ── WINDOW 3: Last 10 events (real-time feed) ─────────────────
SELECT
    DATE_FORMAT(created_at, '%H:%i:%s') AS time,
    IFNULL(u.name, 'System')            AS who,
    l.action,
    l.entity_type,
    l.message
FROM   activity_logs l
LEFT JOIN users u ON u.user_id = l.user_id
ORDER  BY l.log_id DESC
LIMIT  10;

-- ── WINDOW 4: New users in last 24h ───────────────────────────
SELECT
    user_id, name, email, gender, status,
    DATE_FORMAT(created_at, '%d %b %Y %H:%i') AS registered_at
FROM   users
WHERE  created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER  BY created_at DESC;

-- ── WINDOW 5: Unresponded pairings (expiring soon) ────────────
SELECT
    p.pairing_id,
    u1.name   AS from_user,
    u2.name   AS to_user,
    p.match_score,
    p.message,
    p.expires_at,
    TIMESTAMPDIFF(HOUR, NOW(), p.expires_at) AS hours_until_expiry
FROM   pairings p
JOIN   users u1 ON u1.user_id = p.user_id_1
JOIN   users u2 ON u2.user_id = p.user_id_2
WHERE  p.pairing_status = 'pending'
  AND  p.expires_at     > NOW()
ORDER  BY p.expires_at ASC;


-- Verify all tables have data
SELECT 'users'         AS tbl, COUNT(*) AS rows FROM users
UNION ALL
SELECT 'user_profiles',        COUNT(*)          FROM user_profiles
UNION ALL
SELECT 'pairings',             COUNT(*)          FROM pairings
UNION ALL
SELECT 'activity_logs',        COUNT(*)          FROM activity_logs
UNION ALL
SELECT 'notifications',        COUNT(*)          FROM notifications;

-- Verify triggers fired (check log for USER_CREATED entries)
SELECT action, COUNT(*) AS count
FROM   activity_logs
GROUP  BY action
ORDER  BY count DESC;

-- Verify compatibility scores were auto-calculated
SELECT pairing_id, user_id_1, user_id_2, match_score
FROM   pairings
WHERE  match_score IS NOT NULL;

SELECT 'All sample data inserted and verified!' AS status;
