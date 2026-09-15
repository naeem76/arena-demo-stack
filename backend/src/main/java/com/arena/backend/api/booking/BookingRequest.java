package com.arena.backend.api.booking;

import java.util.UUID;

import jakarta.validation.constraints.NotNull;

public record BookingRequest(@NotNull UUID eventId) {
}
