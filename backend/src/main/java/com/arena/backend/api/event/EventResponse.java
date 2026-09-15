package com.arena.backend.api.event;

import java.time.Instant;
import java.util.UUID;

import com.arena.backend.domain.event.EventStatus;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(requiredProperties = {"id", "title", "sport", "location", "startsAt", "endsAt", "capacity", "status", "createdAt", "updatedAt"})
public record EventResponse(UUID id, String title, @Schema(types = {"string", "null"}) String description, String sport, String location,
		Instant startsAt, Instant endsAt, int capacity, EventStatus status, Instant createdAt, Instant updatedAt) {
}
