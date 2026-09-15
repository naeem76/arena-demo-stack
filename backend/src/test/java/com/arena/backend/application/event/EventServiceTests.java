package com.arena.backend.application.event;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import com.arena.backend.application.common.ResourceNotFoundException;
import com.arena.backend.domain.common.InvalidInputException;
import com.arena.backend.domain.common.StateConflictException;
import com.arena.backend.domain.event.Event;
import com.arena.backend.domain.event.EventRepository;
import com.arena.backend.domain.event.EventStatus;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EventServiceTests {

	private static final Instant NOW = Instant.parse("2030-01-01T10:00:00Z");
	private static final Instant START = NOW.plusSeconds(3600);
	private static final Instant END = START.plusSeconds(3600);

	@Mock
	private EventRepository repository;

	private EventService service;

	@BeforeEach
	void setUp() {
		service = new EventService(repository, Clock.fixed(NOW, ZoneOffset.UTC));
	}

	@Test
	void createsScheduledEventInTheFuture() {
		when(repository.save(any(Event.class))).thenAnswer(invocation -> invocation.getArgument(0));
		Event created = service.create("Football", null, "Football", "Park", START, END, 20);
		assertThat(created.getStatus()).isEqualTo(EventStatus.SCHEDULED);
		assertThat(created.getStartsAt()).isEqualTo(START);
		verify(repository).save(created);
	}

	@ParameterizedTest
	@ValueSource(longs = {-1, 0})
	void rejectsCreationAtOrBeforeNow(long offset) {
		assertThatThrownBy(() -> service.create("Football", null, "Football", "Park",
				NOW.plusSeconds(offset), END, 20)).isInstanceOf(InvalidInputException.class);
		verifyNoInteractions(repository);
	}

	@Test
	void reportsMissingEvent() {
		UUID id = UUID.randomUUID();
		assertThatThrownBy(() -> service.findById(id)).isInstanceOf(ResourceNotFoundException.class);
	}

	@Test
	void updatesThroughTheExistingEntity() {
		UUID id = UUID.randomUUID();
		Event event = newEvent();
		when(repository.findById(id)).thenReturn(Optional.of(event));
		when(repository.save(event)).thenReturn(event);
		assertThat(service.update(id, "Tennis", null, "Tennis", "Court", START, END, 2)).isSameAs(event);
		assertThat(event.getTitle()).isEqualTo("Tennis");
		verify(repository).save(event);
	}

	@Test
	void doesNotSaveAnEventWhoseDetailsAreReadOnly() {
		UUID id = UUID.randomUUID();
		Event event = newEvent();
		event.changeStatus(EventStatus.LIVE);
		when(repository.findById(id)).thenReturn(Optional.of(event));
		assertThatThrownBy(() -> service.update(id, "Tennis", null, "Tennis", "Court", START, END, 2))
				.isInstanceOf(StateConflictException.class);
		verify(repository, never()).save(any());
	}

	@Test
	void changesStatusThroughTheEntity() {
		UUID id = UUID.randomUUID();
		Event event = newEvent();
		when(repository.findById(id)).thenReturn(Optional.of(event));
		when(repository.save(event)).thenReturn(event);
		assertThat(service.changeStatus(id, EventStatus.LIVE).getStatus()).isEqualTo(EventStatus.LIVE);
		verify(repository).save(event);
	}

	@Test
	void deletesExistingEvent() {
		UUID id = UUID.randomUUID();
		when(repository.findById(id)).thenReturn(Optional.of(newEvent()));
		service.delete(id);
		verify(repository).deleteById(id);
	}

	@Test
	void doesNotSilentlyDeleteMissingEvent() {
		UUID id = UUID.randomUUID();
		assertThatThrownBy(() -> service.delete(id)).isInstanceOf(ResourceNotFoundException.class);
		verify(repository, never()).deleteById(any());
	}

	@Test
	void passesTrimmedFiltersToRepository() {
		Event event = newEvent();
		when(repository.findAll("Football", EventStatus.SCHEDULED)).thenReturn(List.of(event));
		assertThat(service.list(" Football ", EventStatus.SCHEDULED)).containsExactly(event);
	}

	@ParameterizedTest
	@NullAndEmptySource
	@ValueSource(strings = {" \t"})
	void treatsBlankSportAsNoFilter(String sport) {
		service.list(sport, null);
		verify(repository).findAll(null, null);
	}

	private Event newEvent() {
		return new Event("Football", null, "Football", "Park", START, END, 20);
	}
}
