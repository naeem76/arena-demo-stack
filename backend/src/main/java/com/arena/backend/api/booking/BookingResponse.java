package com.arena.backend.api.booking;

import java.time.Instant;
import java.util.UUID;

import com.arena.backend.api.event.EventResponse;
import com.arena.backend.domain.booking.BookingStatus;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(requiredProperties = {"id", "event", "status", "createdAt", "updatedAt", "participant"})
public record BookingResponse(UUID id, EventResponse event, BookingStatus status,
		Instant createdAt, Instant updatedAt, Participant participant) {

	@Schema(requiredProperties = {"id", "displayName"})
	public record Participant(UUID id, String displayName) {
	}
}
