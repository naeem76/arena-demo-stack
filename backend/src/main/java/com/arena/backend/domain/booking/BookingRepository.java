package com.arena.backend.domain.booking;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BookingRepository {

	Booking save(Booking booking);

	Optional<Booking> findById(UUID id);

	Optional<UUID> findEventIdById(UUID id);

	Optional<Booking> findByIdAndUserId(UUID id, UUID userId);

	Optional<UUID> findEventIdByIdAndUserId(UUID id, UUID userId);

	default List<Booking> findByUserId(UUID userId) {
		return findByUserId(userId, null, null);
	}

	List<Booking> findByUserId(UUID userId, UUID eventId, BookingStatus status);

	List<Booking> findAll(UUID eventId, BookingStatus status);

	boolean existsByEventId(UUID eventId);

	boolean hasActiveBooking(UUID eventId, UUID userId);

	long countActiveByEventId(UUID eventId);
}
