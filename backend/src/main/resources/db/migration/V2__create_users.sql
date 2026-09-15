CREATE TABLE users (
    id UUID PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,

    CONSTRAINT users_username_not_blank CHECK (username ~ '[^[:space:]]'),
    CONSTRAINT users_display_name_not_blank CHECK (display_name ~ '[^[:space:]]'),
    CONSTRAINT users_password_hash_bcrypt CHECK (password_hash ~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$')
);

CREATE UNIQUE INDEX users_username_unique ON users (lower(username));
