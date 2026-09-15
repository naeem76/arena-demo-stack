package com.arena.backend.infrastructure.persistence.event;

import java.util.UUID;

import com.arena.backend.domain.event.Event;
import org.springframework.data.jpa.repository.JpaRepository;

public interface JpaEventRepository extends JpaRepository<Event, UUID> {
}
