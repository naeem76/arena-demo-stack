package com.arena.backend.api.booking;

import com.arena.backend.api.PageResponse;
import org.springframework.data.domain.Page;

public final class BookingPageResponse extends PageResponse<BookingResponse> {

	public BookingPageResponse(Page<BookingResponse> result) {
		super(result);
	}
}
