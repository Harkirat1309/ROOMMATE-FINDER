
USE main_system_db;

CREATE OR REPLACE VIEW vw_all_users AS
SELECT
    u.user_id,
    u.name,
    u.email,
    u.phone,
    u.gender,
    u.role,
    u.status,
    u.email_verified,
    fn_user_pairing_status(u.user_id)   AS pairing_status,
    up.food_preference,
    up.sleep_schedule,
    up.cleanliness_level,
    up.study_habit,
    up.social_type,
    up.location,
    up.occupation,
    u.last_login,
    u.created_at,
    TIMESTAMPDIFF(DAY, u.created_at, NOW()) AS days_since_joined
FROM       users u
LEFT JOIN  user_profiles up ON up.user_id = u.user_id
ORDER BY   u.created_at DESC;

CREATE OR REPLACE VIEW vw_active_users AS
SELECT * FROM vw_all_users WHERE status = 'active';

CREATE OR REPLACE VIEW vw_all_pairings AS
SELECT
    p.pairing_id,
    p.user_id_1,
    u1.name                             AS user1_name,
    u1.email                            AS user1_email,
    p.user_id_2,
    u2.name                             AS user2_name,
    u2.email                            AS user2_email,
    p.pairing_status,
    p.match_score,
    CASE
        WHEN p.match_score >= 80 THEN 'Excellent'
        WHEN p.match_score >= 60 THEN 'Good'
        WHEN p.match_score >= 40 THEN 'Fair'
        ELSE 'Low'
    END                                 AS score_label,
    p.message,
    initiator.name                      AS initiated_by_name,
    p.expires_at,
    p.responded_at,
    p.created_at,
    TIMESTAMPDIFF(HOUR, p.created_at, NOW()) AS hours_old
FROM       pairings p
JOIN       users u1       ON u1.user_id = p.user_id_1
JOIN       users u2       ON u2.user_id = p.user_id_2
JOIN       users initiator ON initiator.user_id = p.initiated_by
ORDER BY   p.created_at DESC;

CREATE OR REPLACE VIEW vw_active_pairings AS
SELECT * FROM vw_all_pairings WHERE pairing_status = 'accepted';

CREATE OR REPLACE VIEW vw_pending_pairings AS
SELECT * FROM vw_all_pairings
WHERE  pairing_status = 'pending'
  AND  expires_at     > NOW();

CREATE OR REPLACE VIEW vw_recent_activity AS
SELECT
    l.log_id,
    l.created_at,
    IFNULL(u.name, 'System')            AS actor,
    l.action,
    l.entity_type,
    l.entity_id,
    l.status,
    l.message,
    l.new_values,
    l.ip_address
FROM       activity_logs l
LEFT JOIN  users u ON u.user_id = l.user_id
ORDER BY   l.created_at DESC
LIMIT      100;

CREATE OR REPLACE VIEW vw_dashboard_stats AS
SELECT
    (SELECT COUNT(*) FROM users)                                        AS total_users,
    (SELECT COUNT(*) FROM users WHERE status = 'active')                AS active_users,
    (SELECT COUNT(*) FROM users WHERE status = 'inactive')              AS inactive_users,
    (SELECT COUNT(*) FROM users WHERE created_at >= CURDATE())          AS new_users_today,
    (SELECT COUNT(*) FROM users WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)) AS new_users_week,
    (SELECT COUNT(*) FROM pairings)                                     AS total_pairings,
    (SELECT COUNT(*) FROM pairings WHERE pairing_status = 'accepted')   AS active_pairings,
    (SELECT COUNT(*) FROM pairings WHERE pairing_status = 'pending')    AS pending_pairings,
    (SELECT COUNT(*) FROM pairings WHERE pairing_status = 'rejected')   AS rejected_pairings,
    (SELECT COUNT(*) FROM pairings WHERE created_at >= CURDATE())       AS pairings_today,
    (SELECT COUNT(*) FROM activity_logs WHERE created_at >= CURDATE())  AS events_today,
    (SELECT AVG(match_score) FROM pairings WHERE match_score IS NOT NULL) AS avg_match_score,
    NOW()                                                               AS snapshot_at;

CREATE OR REPLACE VIEW vw_top_matches AS
SELECT
    p.pairing_id,
    u1.name     AS user1,
    u2.name     AS user2,
    p.match_score,
    p.pairing_status,
    p.created_at
FROM       pairings p
JOIN       users u1 ON u1.user_id = p.user_id_1
JOIN       users u2 ON u2.user_id = p.user_id_2
WHERE      p.match_score IS NOT NULL
ORDER BY   p.match_score DESC;

CREATE OR REPLACE VIEW vw_available_users AS
SELECT
    u.user_id, u.name, u.email, u.gender,
    up.food_preference, up.sleep_schedule,
    up.cleanliness_level, up.social_type,
    up.location, up.occupation,
    u.created_at
FROM       users u
LEFT JOIN  user_profiles up ON up.user_id = u.user_id
WHERE      u.status = 'active'
  AND      fn_user_pairing_status(u.user_id) = 'available'
ORDER BY   u.created_at DESC;

CREATE OR REPLACE VIEW vw_user_activity_summary AS
SELECT
    u.user_id,
    u.name,
    u.email,
    u.status,
    COUNT(DISTINCT l.log_id)            AS total_events,
    MAX(l.created_at)                   AS last_event_at,
    COUNT(DISTINCT p.pairing_id)        AS total_pairings,
    SUM(p.pairing_status = 'accepted')  AS accepted_pairings,
    SUM(p.pairing_status = 'pending')   AS pending_pairings,
    u.last_login,
    u.created_at
FROM       users u
LEFT JOIN  activity_logs l ON l.user_id = u.user_id
LEFT JOIN  pairings p
    ON (p.user_id_1 = u.user_id OR p.user_id_2 = u.user_id)
GROUP BY   u.user_id, u.name, u.email, u.status,
           u.last_login, u.created_at
ORDER BY   total_events DESC;

SELECT 'Views created successfully' AS status;
SHOW FULL TABLES IN main_system_db WHERE TABLE_TYPE = 'VIEW';
