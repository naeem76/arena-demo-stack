package com.arena.backend.api.event;

import com.arena.backend.api.PageResponse;
import org.springframework.data.domain.Page;

public final class EventPageResponse extends PageResponse<EventResponse> {

	public EventPageResponse(Page<EventResponse> result) {
		super(result);
	}
}
