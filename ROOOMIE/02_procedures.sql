
USE main_system_db;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_create_user$$
CREATE PROCEDURE sp_create_user(
    IN  p_name          VARCHAR(100),
    IN  p_email         VARCHAR(150),
    IN  p_password_hash VARCHAR(255),
    IN  p_phone         VARCHAR(20),
    IN  p_gender        VARCHAR(10),
    IN  p_bio           TEXT,
    OUT p_user_id       INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Validate required fields
    IF TRIM(p_name) = '' OR p_name IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Name is required.';
    END IF;
    IF TRIM(p_email) = '' OR p_email IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email is required.';
    END IF;

    -- Check duplicate email
    IF EXISTS (SELECT 1 FROM users WHERE email = LOWER(TRIM(p_email))) THEN
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = 'Email already registered.';
    END IF;

    START TRANSACTION;

    -- Insert user
    INSERT INTO users (name, email, password_hash, phone, gender, bio)
    VALUES (
        TRIM(p_name),
        LOWER(TRIM(p_email)),
        p_password_hash,
        NULLIF(TRIM(p_phone), ''),
        NULLIF(p_gender, ''),
        NULLIF(TRIM(p_bio), '')
    );

    SET p_user_id = LAST_INSERT_ID();

    -- Auto-create empty profile row
    INSERT INTO user_profiles (user_id) VALUES (p_user_id);

    -- Log the event
    INSERT INTO activity_logs (user_id, action, entity_type, entity_id,
                                new_values, status, message)
    VALUES (p_user_id, 'USER_REGISTERED', 'users', p_user_id,
            JSON_OBJECT('name', p_name, 'email', p_email),
            'success', CONCAT('New user registered: ', p_name));

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_update_user$$
CREATE PROCEDURE sp_update_user(
    IN p_user_id    INT UNSIGNED,
    IN p_name       VARCHAR(100),
    IN p_phone      VARCHAR(20),
    IN p_gender     VARCHAR(10),
    IN p_bio        TEXT
)
BEGIN
    DECLARE v_old_name VARCHAR(100);
    DECLARE v_old_phone VARCHAR(20);

    -- Snapshot old values for audit log
    SELECT name, phone INTO v_old_name, v_old_phone
    FROM users WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = 'User not found.';
    END IF;

    UPDATE users
    SET name    = IFNULL(NULLIF(TRIM(p_name), ''),  name),
        phone   = NULLIF(TRIM(p_phone), ''),
        gender  = NULLIF(p_gender, ''),
        bio     = NULLIF(TRIM(p_bio), '')
    WHERE user_id = p_user_id;

    INSERT INTO activity_logs (user_id, action, entity_type, entity_id,
                                old_values, new_values, status)
    VALUES (p_user_id, 'USER_UPDATED', 'users', p_user_id,
            JSON_OBJECT('name', v_old_name, 'phone', v_old_phone),
            JSON_OBJECT('name', p_name, 'phone', p_phone),
            'success');
END$$

DROP PROCEDURE IF EXISTS sp_delete_user$$
CREATE PROCEDURE sp_delete_user(
    IN p_user_id        INT UNSIGNED,
    IN p_hard_delete    TINYINT(1),
    IN p_admin_id       INT UNSIGNED
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = 'User not found.';
    END IF;

    IF p_hard_delete = 1 THEN
        DELETE FROM users WHERE user_id = p_user_id;
        INSERT INTO activity_logs (user_id, action, entity_type, entity_id, status, message)
        VALUES (p_admin_id, 'USER_HARD_DELETED', 'users', p_user_id,
                'success', CONCAT('Hard deleted user ID: ', p_user_id));
    ELSE
        UPDATE users SET status = 'inactive' WHERE user_id = p_user_id;
        INSERT INTO activity_logs (user_id, action, entity_type, entity_id, status, message)
        VALUES (p_admin_id, 'USER_DEACTIVATED', 'users', p_user_id,
                'success', CONCAT('Deactivated user ID: ', p_user_id));
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_save_profile$$
CREATE PROCEDURE sp_save_profile(
    IN p_user_id            INT UNSIGNED,
    IN p_food_preference    VARCHAR(20),
    IN p_sleep_schedule     VARCHAR(20),
    IN p_cleanliness_level  TINYINT UNSIGNED,
    IN p_study_habit        VARCHAR(20),
    IN p_social_type        VARCHAR(20),
    IN p_hobbies            VARCHAR(300),
    IN p_location           VARCHAR(150),
    IN p_occupation         VARCHAR(100)
)
BEGIN
    INSERT INTO user_profiles
        (user_id, food_preference, sleep_schedule, cleanliness_level,
         study_habit, social_type, hobbies, location, occupation)
    VALUES
        (p_user_id, p_food_preference, p_sleep_schedule, p_cleanliness_level,
         p_study_habit, p_social_type, p_hobbies, p_location, p_occupation)
    ON DUPLICATE KEY UPDATE
        food_preference   = p_food_preference,
        sleep_schedule    = p_sleep_schedule,
        cleanliness_level = p_cleanliness_level,
        study_habit       = p_study_habit,
        social_type       = p_social_type,
        hobbies           = p_hobbies,
        location          = p_location,
        occupation        = p_occupation;

    INSERT INTO activity_logs (user_id, action, entity_type, entity_id, status)
    VALUES (p_user_id, 'PROFILE_UPDATED', 'user_profiles', p_user_id, 'success');
END$$

DROP PROCEDURE IF EXISTS sp_send_pairing_request(
    IN  p_from_user_id  INT UNSIGNED,
    IN  p_to_user_id    INT UNSIGNED,
    IN  p_message       VARCHAR(500),
    OUT p_pairing_id    INT UNSIGNED
)$$
DROP PROCEDURE IF EXISTS sp_send_pairing_request$$
CREATE PROCEDURE sp_send_pairing_request(
    IN  p_from_user_id  INT UNSIGNED,
    IN  p_to_user_id    INT UNSIGNED,
    IN  p_message       VARCHAR(500),
    OUT p_pairing_id    INT UNSIGNED
)
BEGIN
    DECLARE v_score DECIMAL(5,2) DEFAULT 0;

    -- Self-pairing guard
    IF p_from_user_id = p_to_user_id THEN
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = 'Cannot send request to yourself.';
    END IF;

    -- Both users must be active
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_from_user_id AND status = 'active') THEN
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = 'Sender account is not active.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_to_user_id AND status = 'active') THEN
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = 'Recipient account is not active.';
    END IF;

    -- Check no active pairing already exists
    IF EXISTS (
        SELECT 1 FROM pairings
        WHERE  LEAST(user_id_1, user_id_2)    = LEAST(p_from_user_id, p_to_user_id)
          AND  GREATEST(user_id_1, user_id_2) = GREATEST(p_from_user_id, p_to_user_id)
          AND  pairing_status IN ('pending', 'accepted')
    ) THEN
        SIGNAL SQLSTATE '45005' SET MESSAGE_TEXT = 'An active pairing already exists between these users.';
    END IF;

    -- Calculate compatibility score
    SET v_score = fn_compatibility_score(p_from_user_id, p_to_user_id);

    -- Insert pairing
    INSERT INTO pairings
        (user_id_1, user_id_2, pairing_status, match_score, message,
         initiated_by, expires_at)
    VALUES
        (p_from_user_id, p_to_user_id, 'pending', v_score, p_message,
         p_from_user_id, DATE_ADD(NOW(), INTERVAL 7 DAY));

    SET p_pairing_id = LAST_INSERT_ID();

    -- Notify recipient
    INSERT INTO notifications (user_id, type, title, body, related_id)
    VALUES (p_to_user_id, 'pairing_request',
            'New pairing request',
            CONCAT('You have a new request from User #', p_from_user_id),
            p_pairing_id);

    -- Log
    INSERT INTO activity_logs (user_id, action, entity_type, entity_id,
                                new_values, status)
    VALUES (p_from_user_id, 'PAIRING_REQUESTED', 'pairings', p_pairing_id,
            JSON_OBJECT('to_user', p_to_user_id, 'score', v_score),
            'success');
END$$

DROP PROCEDURE IF EXISTS sp_respond_to_pairing$$
CREATE PROCEDURE sp_respond_to_pairing(
    IN p_pairing_id     INT UNSIGNED,
    IN p_responder_id   INT UNSIGNED,
    IN p_action         VARCHAR(20)   -- 'accept' or 'reject'
)
BEGIN
    DECLARE v_receiver_id   INT UNSIGNED;
    DECLARE v_sender_id     INT UNSIGNED;
    DECLARE v_status        VARCHAR(20);
    DECLARE v_new_status    VARCHAR(20);

    SELECT user_id_2, user_id_1, pairing_status
    INTO   v_receiver_id, v_sender_id, v_status
    FROM   pairings
    WHERE  pairing_id = p_pairing_id
    FOR UPDATE;

    IF v_receiver_id IS NULL THEN
        SIGNAL SQLSTATE '45006' SET MESSAGE_TEXT = 'Pairing not found.';
    END IF;
    IF v_receiver_id <> p_responder_id THEN
        SIGNAL SQLSTATE '45007' SET MESSAGE_TEXT = 'Only the recipient can respond to this request.';
    END IF;
    IF v_status <> 'pending' THEN
        SIGNAL SQLSTATE '45008'
        SET MESSAGE_TEXT = 'This pairing request is no longer pending.';
    END IF;

    SET v_new_status = CASE LOWER(p_action)
        WHEN 'accept' THEN 'accepted'
        WHEN 'reject' THEN 'rejected'
        ELSE NULL
    END;

    IF v_new_status IS NULL THEN
        SIGNAL SQLSTATE '45009' SET MESSAGE_TEXT = 'Action must be accept or reject.';
    END IF;

    UPDATE pairings
    SET    pairing_status = v_new_status,
           responded_at   = NOW()
    WHERE  pairing_id     = p_pairing_id;

    -- Notify sender
    INSERT INTO notifications (user_id, type, title, body, related_id)
    VALUES (v_sender_id,
            CONCAT('pairing_', v_new_status),
            CONCAT('Pairing request ', v_new_status),
            CONCAT('User #', p_responder_id, ' has ', v_new_status, ' your request.'),
            p_pairing_id);

    INSERT INTO activity_logs (user_id, action, entity_type, entity_id,
                                new_values, status)
    VALUES (p_responder_id,
            CONCAT('PAIRING_', UPPER(v_new_status)),
            'pairings', p_pairing_id,
            JSON_OBJECT('new_status', v_new_status),
            'success');
END$$

DROP PROCEDURE IF EXISTS sp_cancel_pairing$$
CREATE PROCEDURE sp_cancel_pairing(
    IN p_pairing_id INT UNSIGNED,
    IN p_user_id    INT UNSIGNED
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pairings
        WHERE pairing_id = p_pairing_id
          AND initiated_by = p_user_id
          AND pairing_status = 'pending'
    ) THEN
        SIGNAL SQLSTATE '45010'
        SET MESSAGE_TEXT = 'Pairing not found or cannot be cancelled.';
    END IF;

    UPDATE pairings
    SET    pairing_status = 'cancelled',
           responded_at   = NOW()
    WHERE  pairing_id = p_pairing_id;

    INSERT INTO activity_logs (user_id, action, entity_type, entity_id, status)
    VALUES (p_user_id, 'PAIRING_CANCELLED', 'pairings', p_pairing_id, 'success');
END$$

DELIMITER ;

SELECT 'Stored procedures created successfully' AS status;
