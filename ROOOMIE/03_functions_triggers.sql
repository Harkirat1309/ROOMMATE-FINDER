
USE main_system_db;

DELIMITER $$

DROP FUNCTION IF EXISTS fn_compatibility_score$$
CREATE FUNCTION fn_compatibility_score(
    p_user1 INT UNSIGNED,
    p_user2 INT UNSIGNED
) RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_score         DECIMAL(5,2) DEFAULT 0;
    DECLARE v_food1         VARCHAR(20);
    DECLARE v_food2         VARCHAR(20);
    DECLARE v_sleep1        VARCHAR(20);
    DECLARE v_sleep2        VARCHAR(20);
    DECLARE v_clean1        TINYINT UNSIGNED;
    DECLARE v_clean2        TINYINT UNSIGNED;
    DECLARE v_study1        VARCHAR(20);
    DECLARE v_study2        VARCHAR(20);
    DECLARE v_social1       VARCHAR(20);
    DECLARE v_social2       VARCHAR(20);
    DECLARE v_clean_diff    TINYINT;

    -- Fetch profiles (default to flexible values if no profile)
    SELECT IFNULL(food_preference,'Any'),  IFNULL(sleep_schedule,'Flexible'),
           IFNULL(cleanliness_level,3),    IFNULL(study_habit,'Flexible'),
           IFNULL(social_type,'Ambivert')
    INTO   v_food1, v_sleep1, v_clean1, v_study1, v_social1
    FROM   user_profiles WHERE user_id = p_user1;

    SELECT IFNULL(food_preference,'Any'),  IFNULL(sleep_schedule,'Flexible'),
           IFNULL(cleanliness_level,3),    IFNULL(study_habit,'Flexible'),
           IFNULL(social_type,'Ambivert')
    INTO   v_food2, v_sleep2, v_clean2, v_study2, v_social2
    FROM   user_profiles WHERE user_id = p_user2;

    -- ── FOOD (25 pts) ────────────────────────────────────────
    IF v_food1 = 'Any' OR v_food2 = 'Any' OR v_food1 = v_food2 THEN
        SET v_score = v_score + 25;
    END IF;

    -- ── SLEEP SCHEDULE (25 pts) ──────────────────────────────
    IF v_sleep1 = 'Flexible' OR v_sleep2 = 'Flexible' THEN
        SET v_score = v_score + 25;
    ELSEIF v_sleep1 = v_sleep2 THEN
        SET v_score = v_score + 25;
    ELSE
        SET v_score = v_score + 5;  -- mismatch, small partial
    END IF;

    -- ── CLEANLINESS (20 pts) ─────────────────────────────────
    SET v_clean_diff = ABS(v_clean1 - v_clean2);
    SET v_score = v_score + CASE v_clean_diff
        WHEN 0 THEN 20
        WHEN 1 THEN 15
        WHEN 2 THEN 8
        WHEN 3 THEN 3
        ELSE 0
    END;

    -- ── STUDY HABITS (20 pts) ────────────────────────────────
    IF v_study1 = 'Flexible' OR v_study2 = 'Flexible' OR v_study1 = v_study2 THEN
        SET v_score = v_score + 20;
    ELSE
        SET v_score = v_score + 5;
    END IF;

    -- ── SOCIAL TYPE (10 pts) ─────────────────────────────────
    IF v_social1 = 'Ambivert' OR v_social2 = 'Ambivert' OR v_social1 = v_social2 THEN
        SET v_score = v_score + 10;
    ELSE
        SET v_score = v_score + 3;
    END IF;

    RETURN ROUND(LEAST(v_score, 100), 2);
END$$

DROP FUNCTION IF EXISTS fn_user_pairing_status$$
CREATE FUNCTION fn_user_pairing_status(p_user_id INT UNSIGNED)
RETURNS VARCHAR(20)
DETERMINISTIC
READS SQL DATA
BEGIN
    IF EXISTS (
        SELECT 1 FROM pairings
        WHERE (user_id_1 = p_user_id OR user_id_2 = p_user_id)
          AND pairing_status = 'accepted'
    ) THEN RETURN 'paired'; END IF;

    IF EXISTS (
        SELECT 1 FROM pairings
        WHERE (user_id_1 = p_user_id OR user_id_2 = p_user_id)
          AND pairing_status = 'pending'
    ) THEN RETURN 'pending'; END IF;

    RETURN 'available';
END$$

DROP TRIGGER IF EXISTS trg_after_user_insert$$
CREATE TRIGGER trg_after_user_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO activity_logs
        (user_id, action, entity_type, entity_id, new_values, status, message)
    VALUES
        (NEW.user_id, 'USER_CREATED', 'users', NEW.user_id,
         JSON_OBJECT(
             'name',   NEW.name,
             'email',  NEW.email,
             'gender', NEW.gender,
             'role',   NEW.role
         ),
         'success',
         CONCAT('User account created: ', NEW.email));
END$$

DROP TRIGGER IF EXISTS trg_after_user_update$$
CREATE TRIGGER trg_after_user_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    DECLARE v_changes JSON DEFAULT JSON_OBJECT();

    IF OLD.name   <> NEW.name   THEN SET v_changes = JSON_SET(v_changes, '$.name',   NEW.name);   END IF;
    IF OLD.email  <> NEW.email  THEN SET v_changes = JSON_SET(v_changes, '$.email',  NEW.email);  END IF;
    IF OLD.status <> NEW.status THEN SET v_changes = JSON_SET(v_changes, '$.status', NEW.status); END IF;
    IF OLD.role   <> NEW.role   THEN SET v_changes = JSON_SET(v_changes, '$.role',   NEW.role);   END IF;

    INSERT INTO activity_logs
        (user_id, action, entity_type, entity_id, old_values, new_values, status)
    VALUES
        (NEW.user_id, 'USER_UPDATED', 'users', NEW.user_id,
         JSON_OBJECT('name', OLD.name, 'email', OLD.email, 'status', OLD.status),
         v_changes, 'success');
END$$

DROP TRIGGER IF EXISTS trg_before_pairing_insert$$
CREATE TRIGGER trg_before_pairing_insert
BEFORE INSERT ON pairings
FOR EACH ROW
BEGIN
    -- Normalise: always store lower_id as user_id_1
    IF NEW.user_id_1 > NEW.user_id_2 THEN
        SET @tmp          = NEW.user_id_1;
        SET NEW.user_id_1 = NEW.user_id_2;
        SET NEW.user_id_2 = @tmp;
    END IF;

    -- Set expiry if not provided
    IF NEW.expires_at IS NULL THEN
        SET NEW.expires_at = DATE_ADD(NOW(), INTERVAL 7 DAY);
    END IF;

    -- Auto-calculate score if not supplied
    IF NEW.match_score IS NULL THEN
        SET NEW.match_score = fn_compatibility_score(NEW.user_id_1, NEW.user_id_2);
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_after_pairing_update$$
CREATE TRIGGER trg_after_pairing_update
AFTER UPDATE ON pairings
FOR EACH ROW
BEGIN
    IF OLD.pairing_status <> NEW.pairing_status THEN
        INSERT INTO activity_logs
            (user_id, action, entity_type, entity_id, old_values, new_values, status)
        VALUES
            (NEW.initiated_by,
             CONCAT('PAIRING_', UPPER(NEW.pairing_status)),
             'pairings', NEW.pairing_id,
             JSON_OBJECT('status', OLD.pairing_status),
             JSON_OBJECT('status', NEW.pairing_status,
                         'responded_at', NEW.responded_at),
             'success');
    END IF;
END$$


-- EVENT: Auto-expire pending pairings after 7 days
DROP EVENT IF EXISTS evt_expire_pairings$$
CREATE EVENT evt_expire_pairings
ON SCHEDULE EVERY 1 HOUR
DO
BEGIN
    UPDATE pairings
    SET    pairing_status = 'expired'
    WHERE  pairing_status = 'pending'
      AND  expires_at     < NOW();
END$$

DELIMITER ;

-- Enable the event scheduler
SET GLOBAL event_scheduler = ON;

SELECT 'Functions and triggers created successfully' AS status;
