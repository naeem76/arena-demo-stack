package com.arena.backend.api.event;

import java.time.Instant;
import java.util.UUID;

import com.arena.backend.domain.event.EventStatus;

public record EventResponse(UUID id, String title, String description, String sport, String location,
		Instant startsAt, Instant endsAt, int capacity, EventStatus status, Instant createdAt, Instant updatedAt) {
}
