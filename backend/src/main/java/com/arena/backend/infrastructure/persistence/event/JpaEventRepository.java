package com.arena.backend.infrastructure.persistence.event;

import java.util.Optional;
import java.util.UUID;

import com.arena.backend.domain.event.Event;
import com.arena.backend.domain.event.EventStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface JpaEventRepository extends JpaRepository<Event, UUID> {

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("SELECT event FROM Event event WHERE event.id = :id")
	Optional<Event> findByIdForUpdate(@Param("id") UUID id);

	@Query("""
			SELECT event FROM Event event
			WHERE (:sport IS NULL OR lower(event.sport) = :sport)
			AND (:status IS NULL OR event.status = :status)
			ORDER BY event.startsAt, event.id
			""")
	Page<Event> findAllFiltered(@Param("sport") String sport, @Param("status") EventStatus status, Pageable pageable);
}
