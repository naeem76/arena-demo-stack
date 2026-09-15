CREATE TABLE events (
    id UUID PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description VARCHAR(2000),
    sport VARCHAR(50) NOT NULL,
    location VARCHAR(200) NOT NULL,
    starts_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
    capacity INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,

    CONSTRAINT events_title_not_blank CHECK (title ~ '[^[:space:]]'),
    CONSTRAINT events_sport_not_blank CHECK (sport ~ '[^[:space:]]'),
    CONSTRAINT events_location_not_blank CHECK (location ~ '[^[:space:]]'),
    CONSTRAINT events_capacity_positive CHECK (capacity > 0),
    CONSTRAINT events_schedule_valid CHECK (ends_at > starts_at),
    CONSTRAINT events_status_valid CHECK (status IN ('SCHEDULED', 'LIVE', 'COMPLETED', 'CANCELLED'))
);
