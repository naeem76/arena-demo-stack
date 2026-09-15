package com.arena.backend.api.booking;

import com.arena.backend.api.event.EventMapper;
import com.arena.backend.domain.booking.Booking;

final class BookingMapper {

	private BookingMapper() {
	}

	static BookingResponse toResponse(Booking booking) {
		return new BookingResponse(booking.getId(), EventMapper.toResponse(booking.getEvent()),
				booking.getStatus(), booking.getCreatedAt(), booking.getUpdatedAt());
	}
}
