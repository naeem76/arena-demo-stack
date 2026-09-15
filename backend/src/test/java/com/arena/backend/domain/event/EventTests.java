package com.arena.backend.domain.event;

import java.time.Instant;

import com.arena.backend.domain.common.InvalidInputException;
import com.arena.backend.domain.common.StateConflictException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class EventTests {

	private static final Instant START = Instant.parse("2030-01-01T10:00:00Z");
	private static final Instant END = START.plusSeconds(3600);

	@ParameterizedTest
	@CsvSource({
			"SCHEDULED,SCHEDULED,true", "SCHEDULED,LIVE,true", "SCHEDULED,COMPLETED,false", "SCHEDULED,CANCELLED,true",
			"LIVE,SCHEDULED,false", "LIVE,LIVE,true", "LIVE,COMPLETED,true", "LIVE,CANCELLED,true",
			"COMPLETED,SCHEDULED,false", "COMPLETED,LIVE,false", "COMPLETED,COMPLETED,true", "COMPLETED,CANCELLED,false",
			"CANCELLED,SCHEDULED,false", "CANCELLED,LIVE,false", "CANCELLED,COMPLETED,false", "CANCELLED,CANCELLED,true"
	})
	void enforcesStatusTransitions(EventStatus from, EventStatus to, boolean allowed) {
		Event event = eventAt(from);
		if (allowed) {
			event.changeStatus(to);
			assertThat(event.getStatus()).isEqualTo(to);
		} else {
			assertThatThrownBy(() -> event.changeStatus(to)).isInstanceOf(StateConflictException.class);
			assertThat(event.getStatus()).isEqualTo(from);
		}
	}

	@ParameterizedTest
	@EnumSource(value = EventStatus.class, names = "SCHEDULED", mode = EnumSource.Mode.EXCLUDE)
	void rejectsDetailEditsOutsideScheduledState(EventStatus status) {
		Event event = eventAt(status);
		assertThatThrownBy(() -> event.updateDetails("Changed", null, "Tennis", "Court", START, END, 2))
				.isInstanceOf(StateConflictException.class);
		assertThat(event.getTitle()).isEqualTo("Football");
	}

	@Test
	void updatesScheduledDetails() {
		Event event = eventAt(EventStatus.SCHEDULED);
		event.updateDetails("Tennis", null, "Tennis", "Court", START, END, 2);
		assertThat(event.getTitle()).isEqualTo("Tennis");
		assertThat(event.getCapacity()).isEqualTo(2);
	}

	@ParameterizedTest
	@ValueSource(longs = {-1, 0})
	void rejectsInvalidScheduleWithoutPartiallyChangingDetails(long duration) {
		Event event = eventAt(EventStatus.SCHEDULED);
		assertThatThrownBy(() -> event.updateDetails("Changed", null, "Football", "Park",
				START, START.plusSeconds(duration), 20)).isInstanceOf(InvalidInputException.class);
		assertThat(event.getTitle()).isEqualTo("Football");
		assertThat(event.getEndsAt()).isEqualTo(END);
	}

	@ParameterizedTest
	@ValueSource(ints = {-1, 0})
	void rejectsNonPositiveCapacity(int capacity) {
		assertThatThrownBy(() -> new Event("Football", null, "Football", "Park", START, END, capacity))
				.isInstanceOf(InvalidInputException.class);
	}

	@Test
	void rejectsMissingStatus() {
		Event event = eventAt(EventStatus.SCHEDULED);
		assertThatThrownBy(() -> event.changeStatus(null)).isInstanceOf(InvalidInputException.class);
	}

	private Event eventAt(EventStatus status) {
		Event event = new Event("Football", null, "Football", "Park", START, END, 20);
		if (status == EventStatus.COMPLETED) {
			event.changeStatus(EventStatus.LIVE);
		}
		event.changeStatus(status);
		return event;
	}
}
