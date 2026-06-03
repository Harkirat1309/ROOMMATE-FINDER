
-- ── Drop and recreate database (safe re-run) ─────────────────
DROP DATABASE IF EXISTS main_system_db;
CREATE DATABASE main_system_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE main_system_db;

CREATE TABLE users (
    user_id         INT             UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    email           VARCHAR(150)    NOT NULL,
    password_hash   VARCHAR(255)    NOT NULL                    COMMENT 'bcrypt hash — never plain text',
    phone           VARCHAR(20)     DEFAULT NULL,
    gender          ENUM('Male','Female','Other') DEFAULT NULL,
    date_of_birth   DATE            DEFAULT NULL,
    bio             TEXT            DEFAULT NULL,
    avatar_url      VARCHAR(500)    DEFAULT NULL,
    role            ENUM('user','admin','moderator') NOT NULL DEFAULT 'user',
    status          ENUM('active','inactive','banned','pending')
                                    NOT NULL DEFAULT 'active',
    email_verified  TINYINT(1)      NOT NULL DEFAULT 0,
    last_login      DATETIME        DEFAULT NULL,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT chk_email_format CHECK (email REGEXP '^[^@]+@[^@]+\\.[^@]+$'),
    CONSTRAINT chk_name_length CHECK (CHAR_LENGTH(TRIM(name)) >= 2)
)
ENGINE=InnoDB
COMMENT='Core user accounts with profile and authentication data';

CREATE TABLE user_profiles (
    profile_id          INT     UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id             INT     UNSIGNED NOT NULL,
    food_preference     ENUM('Veg','Non-Veg','Vegan','Jain','Any') DEFAULT 'Any',
    sleep_schedule      ENUM('Early Bird','Night Owl','Flexible')  DEFAULT 'Flexible',
    cleanliness_level   TINYINT UNSIGNED DEFAULT 3
                        COMMENT '1=messy, 5=very neat',
    study_habit         ENUM('Silent','Music','Group','Flexible')  DEFAULT 'Flexible',
    social_type         ENUM('Introvert','Extrovert','Ambivert')   DEFAULT 'Ambivert',
    hobbies             VARCHAR(300) DEFAULT NULL,
    location            VARCHAR(150) DEFAULT NULL,
    occupation          VARCHAR(100) DEFAULT NULL,
    updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_profile_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uq_profile_user UNIQUE (user_id),
    CONSTRAINT chk_cleanliness CHECK (cleanliness_level BETWEEN 1 AND 5)
)
ENGINE=InnoDB
COMMENT='Extended lifestyle profile data per user';

CREATE TABLE pairings (
    pairing_id      INT     UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id_1       INT     UNSIGNED NOT NULL  COMMENT 'Request sender',
    user_id_2       INT     UNSIGNED NOT NULL  COMMENT 'Request receiver',
    pairing_status  ENUM('pending','accepted','rejected','cancelled','expired')
                            NOT NULL DEFAULT 'pending',
    match_score     DECIMAL(5,2) DEFAULT NULL  COMMENT 'Compatibility 0-100',
    message         VARCHAR(500) DEFAULT NULL  COMMENT 'Optional intro message',
    initiated_by    INT     UNSIGNED NOT NULL  COMMENT 'Who sent the request',
    responded_at    DATETIME DEFAULT NULL,
    expires_at      DATETIME DEFAULT NULL,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT fk_pairing_user1
        FOREIGN KEY (user_id_1) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pairing_user2
        FOREIGN KEY (user_id_2) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pairing_initiator
        FOREIGN KEY (initiated_by) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_no_self_pairing
        CHECK (user_id_1 <> user_id_2),
    CONSTRAINT chk_match_score
        CHECK (match_score IS NULL OR match_score BETWEEN 0 AND 100),
    -- Prevent duplicate pairings (regardless of direction)
    CONSTRAINT uq_pairing_pair
        UNIQUE (
            LEAST(user_id_1, user_id_2),
            GREATEST(user_id_1, user_id_2)
        )
)
ENGINE=InnoDB
COMMENT='User pairing requests and confirmed matches';

CREATE TABLE activity_logs (
    log_id          BIGINT  UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         INT     UNSIGNED DEFAULT NULL  COMMENT 'NULL = system action',
    action          VARCHAR(80)  NOT NULL,
    entity_type     VARCHAR(50)  DEFAULT NULL   COMMENT 'users / pairings / etc.',
    entity_id       INT     UNSIGNED DEFAULT NULL,
    old_values      JSON    DEFAULT NULL         COMMENT 'Before state snapshot',
    new_values      JSON    DEFAULT NULL         COMMENT 'After state snapshot',
    ip_address      VARCHAR(45)  DEFAULT NULL,
    user_agent      VARCHAR(300) DEFAULT NULL,
    status          ENUM('success','failure','warning') NOT NULL DEFAULT 'success',
    message         VARCHAR(500) DEFAULT NULL,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_log_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
)
ENGINE=InnoDB
COMMENT='Immutable audit log of all system events';

CREATE TABLE sessions (
    session_id      VARCHAR(128)    PRIMARY KEY,
    user_id         INT UNSIGNED    NOT NULL,
    ip_address      VARCHAR(45)     DEFAULT NULL,
    user_agent      VARCHAR(300)    DEFAULT NULL,
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    last_activity   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    expires_at      DATETIME        NOT NULL,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_session_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
)
ENGINE=InnoDB
COMMENT='Active user sessions';

CREATE TABLE notifications (
    notif_id        INT UNSIGNED    AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNSIGNED    NOT NULL,
    type            VARCHAR(50)     NOT NULL  COMMENT 'pairing_request / accepted / etc.',
    title           VARCHAR(200)    NOT NULL,
    body            VARCHAR(500)    DEFAULT NULL,
    related_id      INT UNSIGNED    DEFAULT NULL   COMMENT 'e.g. pairing_id',
    is_read         TINYINT(1)      NOT NULL DEFAULT 0,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notif_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
)
ENGINE=InnoDB
COMMENT='User notification inbox';

CREATE INDEX idx_users_status         ON users(status);
CREATE INDEX idx_users_created        ON users(created_at DESC);
CREATE INDEX idx_users_role           ON users(role);
CREATE INDEX idx_users_last_login     ON users(last_login DESC);

CREATE INDEX idx_pairings_status      ON pairings(pairing_status);
CREATE INDEX idx_pairings_user1       ON pairings(user_id_1);
CREATE INDEX idx_pairings_user2       ON pairings(user_id_2);
CREATE INDEX idx_pairings_created     ON pairings(created_at DESC);
CREATE INDEX idx_pairings_score       ON pairings(match_score DESC);

CREATE INDEX idx_logs_user            ON activity_logs(user_id);
CREATE INDEX idx_logs_action          ON activity_logs(action);
CREATE INDEX idx_logs_entity          ON activity_logs(entity_type, entity_id);
CREATE INDEX idx_logs_created         ON activity_logs(created_at DESC);

CREATE INDEX idx_notif_user_unread    ON notifications(user_id, is_read);
CREATE INDEX idx_sessions_user        ON sessions(user_id, is_active);
CREATE INDEX idx_sessions_expiry      ON sessions(expires_at);

SELECT 'Schema created successfully' AS status;
SELECT table_name, table_comment
FROM   information_schema.tables
WHERE  table_schema = 'main_system_db'
ORDER  BY table_name;
