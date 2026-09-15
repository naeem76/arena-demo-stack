package com.arena.backend.api.event;

import com.arena.backend.domain.event.EventStatus;
import jakarta.validation.constraints.NotNull;

public record EventStatusRequest(@NotNull EventStatus status) {
}
