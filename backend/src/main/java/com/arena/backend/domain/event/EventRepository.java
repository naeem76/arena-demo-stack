package com.arena.backend.domain.event;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface EventRepository {

	Event save(Event event);

	Optional<Event> findById(UUID id);

	Optional<Event> findByIdForUpdate(UUID id);

	default List<Event> findAll() {
		return findAll(null, null, Pageable.unpaged()).getContent();
	}

	Page<Event> findAll(String sport, EventStatus status, Pageable pageable);

	void deleteById(UUID id);
}
