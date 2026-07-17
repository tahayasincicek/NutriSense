-- NutriSense güvenli hesap ve diyetisyen yaşam döngüsü (MySQL 8+).
-- Önce yedek alınmalı; kurumun migration aracıyla tek transaction içinde uygulanmalıdır.

ALTER TABLE dietitians
    ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN phone_verified BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS dietitian_assignments (
    id CHAR(36) NOT NULL,
    user_id CHAR(36) NOT NULL,
    dietitian_id CHAR(36) NOT NULL,
    status ENUM('pending', 'approved', 'cancelled') NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY ix_dietitian_assignments_user_id (user_id),
    KEY ix_dietitian_assignments_dietitian_id (dietitian_id),
    CONSTRAINT fk_dietitian_assignments_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_dietitian_assignments_dietitian
        FOREIGN KEY (dietitian_id) REFERENCES dietitians (id)
);

CREATE TABLE IF NOT EXISTS auth_audit_logs (
    id CHAR(36) NOT NULL,
    user_id CHAR(36) NULL,
    event VARCHAR(64) NOT NULL,
    email_hash VARCHAR(64) NULL,
    ip_address VARCHAR(64) NULL,
    success BOOLEAN NOT NULL,
    reason VARCHAR(128) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY ix_auth_audit_logs_user_id (user_id),
    KEY ix_auth_audit_logs_event (event),
    KEY ix_auth_audit_logs_created_at (created_at)
);
