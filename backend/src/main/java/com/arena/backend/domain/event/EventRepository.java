package com.arena.backend.domain.event;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface EventRepository {

	Event save(Event event);

	Optional<Event> findById(UUID id);

	default List<Event> findAll() {
		return findAll(null, null);
	}

	List<Event> findAll(String sport, EventStatus status);

	void deleteById(UUID id);
}
