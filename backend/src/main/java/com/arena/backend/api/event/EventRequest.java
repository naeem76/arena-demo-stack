package com.arena.backend.api.event;

import java.time.Instant;

import com.arena.backend.domain.event.Event;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record EventRequest(
		@NotBlank @Size(max = Event.MAX_TITLE_LENGTH) String title,
		@Size(max = Event.MAX_DESCRIPTION_LENGTH) String description,
		@NotBlank @Size(max = Event.MAX_SPORT_LENGTH) String sport,
		@NotBlank @Size(max = Event.MAX_LOCATION_LENGTH) String location,
		@NotNull Instant startsAt,
		@NotNull Instant endsAt,
		@NotNull @Min(1) Integer capacity) {
}
