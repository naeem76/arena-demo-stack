package com.arena.backend.infrastructure.persistence.event;

import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

import com.arena.backend.domain.event.Event;
import com.arena.backend.domain.event.EventRepository;
import com.arena.backend.domain.event.EventStatus;
import com.arena.backend.infrastructure.persistence.PageQueries;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Repository;

@Repository
public class EventPersistenceAdapter implements EventRepository {

	private final JpaEventRepository repository;

	public EventPersistenceAdapter(JpaEventRepository repository) {
		this.repository = repository;
	}

	@Override
	public Event save(Event event) {
		return repository.save(event);
	}

	@Override
	public Optional<Event> findById(UUID id) {
		return repository.findById(id);
	}

	@Override
	public Optional<Event> findByIdForUpdate(UUID id) {
		return repository.findByIdForUpdate(id);
	}

	@Override
	public Page<Event> findAll(String sport, EventStatus status, Pageable pageable) {
		return PageQueries.fetch(pageable, request ->
				repository.findAllFiltered(sport == null ? null : sport.toLowerCase(Locale.ROOT), status, request));
	}

	@Override
	public void deleteById(UUID id) {
		repository.deleteById(id);
	}
}
