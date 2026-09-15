package com.arena.backend.application.event;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.arena.backend.application.common.ResourceNotFoundException;
import com.arena.backend.domain.common.InvalidInputException;
import com.arena.backend.domain.event.Event;
import com.arena.backend.domain.event.EventRepository;
import com.arena.backend.domain.event.EventStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class EventService {

	private final EventRepository repository;
	private final Clock clock;

	public EventService(EventRepository repository, Clock clock) {
		this.repository = repository;
		this.clock = clock;
	}

	public List<Event> list(String sport, EventStatus status) {
		String filter = sport == null || sport.isBlank() ? null : sport.strip();
		return repository.findAll(filter, status);
	}

	public Event findById(UUID id) {
		return repository.findById(id)
				.orElseThrow(() -> new ResourceNotFoundException("Event " + id + " was not found."));
	}

	@Transactional
	public Event create(String title, String description, String sport, String location,
			Instant startsAt, Instant endsAt, int capacity) {
		if (startsAt == null || !startsAt.isAfter(clock.instant())) {
			throw new InvalidInputException("New events must start in the future.");
		}
		return repository.save(new Event(title, description, sport, location, startsAt, endsAt, capacity));
	}

	@Transactional
	public Event update(UUID id, String title, String description, String sport, String location,
			Instant startsAt, Instant endsAt, int capacity) {
		Event event = findById(id);
		event.updateDetails(title, description, sport, location, startsAt, endsAt, capacity);
		return repository.save(event);
	}

	@Transactional
	public Event changeStatus(UUID id, EventStatus status) {
		Event event = findById(id);
		event.changeStatus(status);
		return repository.save(event);
	}

	@Transactional
	public void delete(UUID id) {
		findById(id);
		repository.deleteById(id);
	}
}
