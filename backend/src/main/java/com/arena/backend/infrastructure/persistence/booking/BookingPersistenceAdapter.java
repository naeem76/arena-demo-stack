package com.arena.backend.infrastructure.persistence.booking;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import com.arena.backend.domain.booking.Booking;
import com.arena.backend.domain.booking.BookingRepository;
import com.arena.backend.domain.booking.BookingStatus;
import org.springframework.stereotype.Repository;

@Repository
public class BookingPersistenceAdapter implements BookingRepository {

	private final JpaBookingRepository repository;

	public BookingPersistenceAdapter(JpaBookingRepository repository) {
		this.repository = repository;
	}

	@Override
	public Booking save(Booking booking) {
		return repository.save(booking);
	}

	@Override
	public Optional<Booking> findByIdAndUserId(UUID id, UUID userId) {
		return repository.findByIdAndUser_Id(id, userId);
	}

	@Override
	public Optional<UUID> findEventIdByIdAndUserId(UUID id, UUID userId) {
		return repository.findEventIdByIdAndUserId(id, userId);
	}

	@Override
	public List<Booking> findByUserId(UUID userId) {
		return repository.findAllByUser_IdOrderByCreatedAtDescIdDesc(userId);
	}

	@Override
	public boolean existsByEventId(UUID eventId) {
		return repository.existsByEvent_Id(eventId);
	}

	@Override
	public boolean hasActiveBooking(UUID eventId, UUID userId) {
		return repository.existsByEvent_IdAndUser_IdAndStatus(eventId, userId, BookingStatus.CONFIRMED);
	}

	@Override
	public long countActiveByEventId(UUID eventId) {
		return repository.countByEvent_IdAndStatus(eventId, BookingStatus.CONFIRMED);
	}
}
