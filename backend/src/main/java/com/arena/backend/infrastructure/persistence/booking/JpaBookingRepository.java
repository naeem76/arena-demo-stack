package com.arena.backend.infrastructure.persistence.booking;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import com.arena.backend.domain.booking.Booking;
import com.arena.backend.domain.booking.BookingStatus;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface JpaBookingRepository extends JpaRepository<Booking, UUID> {

	@Override
	@EntityGraph(attributePaths = {"event", "user"})
	Optional<Booking> findById(UUID id);

	@EntityGraph(attributePaths = {"event", "user"})
	Optional<Booking> findByIdAndUser_Id(UUID id, UUID userId);

	@EntityGraph(attributePaths = {"event", "user"})
	@Query("""
			SELECT booking FROM Booking booking
			WHERE booking.user.id = :userId
			AND (:eventId IS NULL OR booking.event.id = :eventId)
			AND (:status IS NULL OR booking.status = :status)
			ORDER BY booking.createdAt DESC, booking.id DESC
			""")
	List<Booking> findOwned(@Param("userId") UUID userId, @Param("eventId") UUID eventId,
			@Param("status") BookingStatus status);

	@EntityGraph(attributePaths = {"event", "user"})
	@Query("""
			SELECT booking FROM Booking booking
			WHERE (:eventId IS NULL OR booking.event.id = :eventId)
			AND (:status IS NULL OR booking.status = :status)
			ORDER BY booking.createdAt DESC, booking.id DESC
			""")
	List<Booking> findFiltered(@Param("eventId") UUID eventId, @Param("status") BookingStatus status);

	@Query("SELECT booking.event.id FROM Booking booking WHERE booking.id = :id")
	Optional<UUID> findEventIdById(@Param("id") UUID id);

	@Query("SELECT booking.event.id FROM Booking booking WHERE booking.id = :id AND booking.user.id = :userId")
	Optional<UUID> findEventIdByIdAndUserId(@Param("id") UUID id, @Param("userId") UUID userId);

	boolean existsByEvent_Id(UUID eventId);

	boolean existsByEvent_IdAndUser_IdAndStatus(UUID eventId, UUID userId, BookingStatus status);

	long countByEvent_IdAndStatus(UUID eventId, BookingStatus status);
}
