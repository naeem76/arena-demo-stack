package com.arena.backend.api;

import java.util.List;

import io.swagger.v3.oas.annotations.media.Schema;
import org.springframework.data.domain.Page;

public abstract class PageResponse<T> {

	private final List<T> items;
	private final int page;
	private final int size;
	private final long totalElements;
	private final int totalPages;

	protected PageResponse(Page<T> result) {
		items = result.getContent();
		page = result.getNumber();
		size = result.getSize();
		totalElements = result.getTotalElements();
		totalPages = result.getTotalPages();
	}

	@Schema(requiredMode = Schema.RequiredMode.REQUIRED)
	public List<T> getItems() {
		return items;
	}

	@Schema(requiredMode = Schema.RequiredMode.REQUIRED, minimum = "0")
	public int getPage() {
		return page;
	}

	@Schema(requiredMode = Schema.RequiredMode.REQUIRED, minimum = "1", maximum = "100")
	public int getSize() {
		return size;
	}

	@Schema(requiredMode = Schema.RequiredMode.REQUIRED, minimum = "0")
	public long getTotalElements() {
		return totalElements;
	}

	@Schema(requiredMode = Schema.RequiredMode.REQUIRED, minimum = "0")
	public int getTotalPages() {
		return totalPages;
	}
}
