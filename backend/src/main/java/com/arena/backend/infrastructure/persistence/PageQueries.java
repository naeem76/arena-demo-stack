package com.arena.backend.infrastructure.persistence;

import java.util.List;
import java.util.function.Function;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

public final class PageQueries {

	private PageQueries() {
	}

	public static <T> Page<T> fetch(Pageable pageable, Function<Pageable, Page<T>> query) {
		// JPA offsets are integers. Resolve far-out empty pages before passing their offset to JPA.
		if (pageable.isPaged() && pageable.getOffset() > Integer.MAX_VALUE) {
			long total = query.apply(PageRequest.of(0, 1)).getTotalElements();
			if (pageable.getOffset() >= total) {
				return new PageImpl<>(List.of(), pageable, total);
			}
		}
		return query.apply(pageable);
	}
}
