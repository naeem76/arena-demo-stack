package com.arena.backend.api.event;

import com.arena.backend.domain.event.Event;

final class EventMapper {

	private EventMapper() {
	}

	static EventResponse toResponse(Event event) {
		return new EventResponse(event.getId(), event.getTitle(), event.getDescription(), event.getSport(),
				event.getLocation(), event.getStartsAt(), event.getEndsAt(), event.getCapacity(), event.getStatus(),
				event.getCreatedAt(), event.getUpdatedAt());
	}
}
