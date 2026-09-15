package com.arena.backend.domain.common;

public class StateConflictException extends RuntimeException {

	public StateConflictException(String message) {
		super(message);
	}
}
