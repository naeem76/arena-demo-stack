package com.arena.backend.api;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.data.domain.PageRequest;

public class PaginationRequest {

	@Min(0)
	private int page = 0;

	@Min(1)
	@Max(100)
	private int size = 20;

	@Schema(defaultValue = "0", minimum = "0", description = "Zero-based page number")
	public int getPage() {
		return page;
	}

	public void setPage(int page) {
		this.page = page;
	}

	@Schema(defaultValue = "20", minimum = "1", maximum = "100", description = "Maximum items per page")
	public int getSize() {
		return size;
	}

	public void setSize(int size) {
		this.size = size;
	}

	public PageRequest toPageRequest() {
		return PageRequest.of(page, size);
	}
}
