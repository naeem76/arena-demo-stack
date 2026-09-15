package com.arena.backend.api.booking;

import java.time.Instant;
import java.util.UUID;

import com.arena.backend.api.event.EventResponse;
import com.arena.backend.domain.booking.BookingStatus;

public record BookingResponse(UUID id, EventResponse event, BookingStatus status,
		Instant createdAt, Instant updatedAt, Participant participant) {

	public record Participant(UUID id, String displayName) {
	}
}
