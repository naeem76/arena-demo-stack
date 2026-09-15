package com.arena.backend.domain.booking;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface BookingRepository {

	Booking save(Booking booking);

	Optional<Booking> findById(UUID id);

	Optional<UUID> findEventIdById(UUID id);

	Optional<Booking> findByIdAndUserId(UUID id, UUID userId);

	Optional<UUID> findEventIdByIdAndUserId(UUID id, UUID userId);

	default List<Booking> findByUserId(UUID userId) {
		return findByUserId(userId, null, null, Pageable.unpaged()).getContent();
	}

	Page<Booking> findByUserId(UUID userId, UUID eventId, BookingStatus status, Pageable pageable);

	Page<Booking> findAll(UUID eventId, BookingStatus status, Pageable pageable);

	boolean existsByEventId(UUID eventId);

	boolean hasActiveBooking(UUID eventId, UUID userId);

	long countActiveByEventId(UUID eventId);
}
