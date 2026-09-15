package com.arena.backend.infrastructure.persistence.event;

import java.util.List;
import java.util.UUID;

import com.arena.backend.domain.event.Event;
import com.arena.backend.domain.event.EventStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface JpaEventRepository extends JpaRepository<Event, UUID> {

	@Query("""
			SELECT event FROM Event event
			WHERE (:sport IS NULL OR lower(event.sport) = :sport)
			AND (:status IS NULL OR event.status = :status)
			ORDER BY event.startsAt, event.id
			""")
	List<Event> findAllFiltered(@Param("sport") String sport, @Param("status") EventStatus status);
}
