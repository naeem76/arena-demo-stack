CREATE TABLE bookings (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL DEFAULT 'CONFIRMED',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,

    CONSTRAINT bookings_status_valid CHECK (status IN ('CONFIRMED', 'CANCELLED'))
);

CREATE UNIQUE INDEX bookings_active_event_user_unique
    ON bookings (event_id, user_id) WHERE status = 'CONFIRMED';

CREATE INDEX bookings_event_idx ON bookings (event_id);
CREATE INDEX bookings_user_created_idx ON bookings (user_id, created_at DESC, id DESC);
