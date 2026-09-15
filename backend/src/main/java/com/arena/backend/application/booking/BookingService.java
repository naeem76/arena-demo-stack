package com.arena.backend.application.booking;

import java.time.Clock;
import java.util.List;
import java.util.UUID;

import com.arena.backend.application.common.ResourceNotFoundException;
import com.arena.backend.domain.booking.Booking;
import com.arena.backend.domain.booking.BookingRepository;
import com.arena.backend.domain.booking.BookingStatus;
import com.arena.backend.domain.common.StateConflictException;
import com.arena.backend.domain.event.Event;
import com.arena.backend.domain.event.EventRepository;
import com.arena.backend.domain.event.EventStatus;
import com.arena.backend.domain.user.User;
import com.arena.backend.domain.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class BookingService {

	private final BookingRepository bookings;
	private final EventRepository events;
	private final UserRepository users;
	private final Clock clock;

	public BookingService(BookingRepository bookings, EventRepository events, UserRepository users, Clock clock) {
		this.bookings = bookings;
		this.events = events;
		this.users = users;
		this.clock = clock;
	}

	public List<Booking> list(UUID userId) {
		return bookings.findByUserId(userId);
	}

	public Booking findById(UUID id, UUID userId) {
		return bookings.findByIdAndUserId(id, userId)
				.orElseThrow(() -> new ResourceNotFoundException("Booking " + id + " was not found."));
	}

	@Transactional
	public Booking create(UUID eventId, UUID userId) {
		User user = users.findById(userId)
				.orElseThrow(() -> new ResourceNotFoundException("User was not found."));
		Event event = lockEvent(eventId);
		if (event.getStatus() != EventStatus.SCHEDULED || !event.getStartsAt().isAfter(clock.instant())) {
			throw new StateConflictException("Only scheduled events that have not started can be booked.");
		}
		if (bookings.hasActiveBooking(eventId, userId)) {
			throw new StateConflictException("You already have a confirmed booking for this event.");
		}
		if (bookings.countActiveByEventId(eventId) >= event.getCapacity()) {
			throw new StateConflictException("This event has no available places.");
		}
		return bookings.save(new Booking(event, user));
	}

	@Transactional
	public Booking cancel(UUID id, UUID userId) {
		// Read only the event ID before locking, so no stale Booking entity is cached while waiting.
		UUID eventId = bookings.findEventIdByIdAndUserId(id, userId)
				.orElseThrow(() -> new ResourceNotFoundException("Booking " + id + " was not found."));
		Event event = lockEvent(eventId);
		Booking booking = findById(id, userId);
		if (booking.getStatus() == BookingStatus.CANCELLED) {
			return booking;
		}
		if (!event.getStartsAt().isAfter(clock.instant())
				|| event.getStatus() == EventStatus.LIVE || event.getStatus() == EventStatus.COMPLETED) {
			throw new StateConflictException("Bookings cannot be cancelled after an event has started.");
		}
		booking.cancel();
		return bookings.save(booking);
	}

	private Event lockEvent(UUID id) {
		return events.findByIdForUpdate(id)
				.orElseThrow(() -> new ResourceNotFoundException("Event " + id + " was not found."));
	}
}
