package com.arena.backend.domain.booking;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BookingRepository {

	Booking save(Booking booking);

	Optional<Booking> findByIdAndUserId(UUID id, UUID userId);

	Optional<UUID> findEventIdByIdAndUserId(UUID id, UUID userId);

	List<Booking> findByUserId(UUID userId);

	boolean existsByEventId(UUID eventId);

	boolean hasActiveBooking(UUID eventId, UUID userId);

	long countActiveByEventId(UUID eventId);
}
