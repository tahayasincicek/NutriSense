-- NutriSense v1 refresh token rotation tablosu (MySQL 8+).
-- Production'da veritabanı yedeği ve kurumun migration aracıyla uygulanmalıdır.

CREATE TABLE IF NOT EXISTS refresh_tokens (
    jti CHAR(36) NOT NULL,
    user_id CHAR(36) NOT NULL,
    token_hash VARCHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at DATETIME NULL,
    replaced_by_jti CHAR(36) NULL,
    PRIMARY KEY (jti),
    UNIQUE KEY uq_refresh_tokens_token_hash (token_hash),
    KEY ix_refresh_tokens_user_id (user_id),
    KEY ix_refresh_tokens_expires_at (expires_at),
    CONSTRAINT fk_refresh_tokens_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE
);
