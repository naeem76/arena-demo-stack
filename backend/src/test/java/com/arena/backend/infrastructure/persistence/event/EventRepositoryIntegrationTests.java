package com.arena.backend.infrastructure.persistence.event;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;
import java.util.stream.Stream;

import com.arena.backend.PostgresTestConfiguration;
import com.arena.backend.configuration.JpaAuditingConfiguration;
import com.arena.backend.domain.event.Event;
import com.arena.backend.domain.event.EventRepository;
import com.arena.backend.domain.event.EventStatus;
import jakarta.validation.ConstraintViolationException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest(showSql = false)
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({PostgresTestConfiguration.class, JpaAuditingConfiguration.class, EventPersistenceAdapter.class})
class EventRepositoryIntegrationTests {

	private static final Instant START = Instant.parse("2026-10-01T18:30:00.123456Z");
	private static final Instant END = START.plusSeconds(3600);

	@Autowired
	private EventRepository repository;

	@Autowired
	private TestEntityManager entityManager;

	@Autowired
	private JdbcTemplate jdbc;

	@Test
	void savesAndReloadsEventWithGeneratedIdentityAndAuditFields() {
		Instant beforeSave = Instant.now().minusSeconds(1);
		Event event = saveAndReload(newEvent("Community football"));

		assertThat(event.getId()).isNotNull();
		assertThat(event.getTitle()).isEqualTo("Community football");
		assertThat(event.getDescription()).isEqualTo("A friendly local sports event.");
		assertThat(event.getSport()).isEqualTo("Football");
		assertThat(event.getLocation()).isEqualTo("Riverside Park");
		assertThat(event.getStartsAt()).isEqualTo(START);
		assertThat(event.getEndsAt()).isEqualTo(END);
		assertThat(event.getCapacity()).isEqualTo(20);
		assertThat(event.getStatus()).isEqualTo(EventStatus.SCHEDULED);
		assertThat(event.getCreatedAt()).isBetween(beforeSave, Instant.now());
		assertThat(event.getUpdatedAt()).isEqualTo(event.getCreatedAt());
	}

	@Test
	void updatesDetachedEventAndPreservesCreationTimestamp() {
		Event event = saveAndReload(newEvent("Community football"));
		UUID id = event.getId();
		Instant createdAt = event.getCreatedAt();
		Instant previousUpdate = event.getUpdatedAt();
		entityManager.clear();
		event.updateDetails("Evening football", null, "Football", "Central Park",
				START.plusSeconds(7200), END.plusSeconds(7200), 24);
		event.changeStatus(EventStatus.LIVE);

		Event updated = saveAndReload(event);

		assertThat(updated.getId()).isEqualTo(id);
		assertThat(updated.getTitle()).isEqualTo("Evening football");
		assertThat(updated.getDescription()).isNull();
		assertThat(updated.getLocation()).isEqualTo("Central Park");
		assertThat(updated.getStartsAt()).isEqualTo(START.plusSeconds(7200));
		assertThat(updated.getEndsAt()).isEqualTo(END.plusSeconds(7200));
		assertThat(updated.getCapacity()).isEqualTo(24);
		assertThat(updated.getStatus()).isEqualTo(EventStatus.LIVE);
		assertThat(updated.getCreatedAt()).isEqualTo(createdAt);
		assertThat(updated.getUpdatedAt()).isAfter(previousUpdate);
	}

	@Test
	void listsStoredEvents() {
		Event first = saveAndReload(newEvent("Morning football"));
		Event second = saveAndReload(newEvent("Evening football"));

		assertThat(repository.findAll()).extracting(Event::getId)
				.containsExactlyInAnyOrder(first.getId(), second.getId());
	}

	@Test
	void returnsEmptyForMissingEvent() {
		assertThat(repository.findById(UUID.randomUUID())).isEmpty();
	}

	@Test
	void deletesStoredEvent() {
		Event event = saveAndReload(newEvent("Community football"));
		repository.deleteById(event.getId());
		entityManager.flush();
		entityManager.clear();

		assertThat(repository.findById(event.getId())).isEmpty();
	}

	@ParameterizedTest
	@EnumSource(EventStatus.class)
	void storesStatusByName(EventStatus status) {
		Event event = newEvent("Community football");
		if (status == EventStatus.COMPLETED) {
			event.changeStatus(EventStatus.LIVE);
		}
		event.changeStatus(status);
		Event stored = saveAndReload(event);

		assertThat(stored.getStatus()).isEqualTo(status);
		assertThat(jdbc.queryForObject("SELECT status FROM events WHERE id = ?", String.class, stored.getId()))
				.isEqualTo(status.name());
	}

	@Test
	void acceptsHistoricalEventsAndNewSportsWithoutSchemaChanges() {
		Event historical = new Event("Community ultimate", null, "Ultimate", "Riverside Park",
				Instant.parse("2020-01-01T10:00:00Z"), Instant.parse("2020-01-01T11:00:00Z"), 14);
		historical.changeStatus(EventStatus.LIVE);
		historical.changeStatus(EventStatus.COMPLETED);

		Event stored = saveAndReload(historical);

		assertThat(stored.getSport()).isEqualTo("Ultimate");
		assertThat(stored.getStatus()).isEqualTo(EventStatus.COMPLETED);
		assertThat(stored.getDescription()).isNull();
	}

	@Test
	void validatesEntityBeforePersistence() {
		Event invalid = new Event(" ", null, "Football", "Park", START, END, 1);

		assertThatThrownBy(() -> {
			repository.save(invalid);
			entityManager.flush();
		}).isInstanceOf(ConstraintViolationException.class);
	}

	@ParameterizedTest(name = "rejects invalid database value for {0}: {1}")
	@MethodSource("invalidDatabaseValues")
	void databaseEnforcesConstraintsWithoutBeanValidation(String column, Object value) {
		Event stored = saveAndReload(newEvent("Community football"));

		// Column names come only from the fixed test cases below; values are bound parameters.
		assertThatThrownBy(() -> jdbc.update("UPDATE events SET " + column + " = ? WHERE id = ?",
				value, stored.getId())).isInstanceOf(DataIntegrityViolationException.class);
	}

	@Test
	void filtersBySportAndStatusAndOrdersByStartTime() {
		Event scheduled = saveAndReload(newEvent("Scheduled football"));
		Event live = new Event("Live football", null, "Football", "Park", END, END.plusSeconds(3600), 20);
		live.changeStatus(EventStatus.LIVE);
		live = saveAndReload(live);
		Event basketball = saveAndReload(new Event("Basketball", null, "Basketball", "Court",
				START.minusSeconds(7200), START.minusSeconds(3600), 10));

		assertThat(repository.findAll()).extracting(Event::getId)
				.containsExactly(basketball.getId(), scheduled.getId(), live.getId());
		assertThat(repository.findAll("fOoTbAlL", null, PageRequest.of(0, 20))).extracting(Event::getId)
				.containsExactly(scheduled.getId(), live.getId());
		assertThat(repository.findAll(null, EventStatus.LIVE, PageRequest.of(0, 20))).extracting(Event::getId)
				.containsExactly(live.getId());
		assertThat(repository.findAll("Football", EventStatus.SCHEDULED, PageRequest.of(0, 20))).extracting(Event::getId)
				.containsExactly(scheduled.getId());
		assertThat(repository.findAll("Tennis", null, PageRequest.of(0, 20))).isEmpty();
	}

	@Test
	void appliesVersionedMigration() {
		assertThat(jdbc.queryForObject(
				"SELECT count(*) FROM flyway_schema_history WHERE version = '1' AND success = true", Integer.class))
				.isEqualTo(1);
	}

	@Test
	void loadsOnlyTheRequestedPageFromTheDatabase() {
		for (int i = 0; i < 3; i++) {
			repository.save(newEvent("Football " + i));
		}
		entityManager.flush();
		entityManager.clear();

		var page = repository.findAll("Football", EventStatus.SCHEDULED, PageRequest.of(1, 1));

		assertThat(page.getContent()).hasSize(1);
		assertThat(page.getTotalElements()).isEqualTo(3);
		assertThat(page.getTotalPages()).isEqualTo(3);
		assertThat(entityManager.getEntityManager().unwrap(org.hibernate.Session.class)
				.getStatistics().getEntityCount()).isEqualTo(1);
	}

	private Event newEvent(String title) {
		return new Event(title, "A friendly local sports event.", "Football", "Riverside Park", START, END, 20);
	}

	private Event saveAndReload(Event event) {
		Event saved = repository.save(event);
		entityManager.flush();
		entityManager.clear();
		return repository.findById(saved.getId()).orElseThrow();
	}

	static Stream<Arguments> invalidDatabaseValues() {
		return Stream.of(
				Arguments.of("title", null),
				Arguments.of("title", " \t\n"),
				Arguments.of("title", "x".repeat(151)),
				Arguments.of("description", "x".repeat(2001)),
				Arguments.of("sport", " "),
				Arguments.of("sport", "x".repeat(51)),
				Arguments.of("location", " "),
				Arguments.of("location", "x".repeat(201)),
				Arguments.of("capacity", 0),
				Arguments.of("capacity", -1),
				Arguments.of("status", "UNKNOWN"),
				Arguments.of("status", null),
				Arguments.of("starts_at", null),
				Arguments.of("ends_at", START.atOffset(ZoneOffset.UTC)),
				Arguments.of("ends_at", START.minusSeconds(1).atOffset(ZoneOffset.UTC)),
				Arguments.of("created_at", null),
				Arguments.of("updated_at", null));
	}
}
