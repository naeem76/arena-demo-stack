package com.arena.backend.infrastructure.persistence.booking;

import java.time.Instant;
import java.util.UUID;

import com.arena.backend.PostgresTestConfiguration;
import com.arena.backend.configuration.JpaAuditingConfiguration;
import com.arena.backend.domain.booking.Booking;
import com.arena.backend.domain.booking.BookingRepository;
import com.arena.backend.domain.booking.BookingStatus;
import com.arena.backend.domain.event.Event;
import com.arena.backend.domain.event.EventRepository;
import com.arena.backend.domain.user.User;
import com.arena.backend.domain.user.UserRepository;
import com.arena.backend.infrastructure.persistence.event.EventPersistenceAdapter;
import com.arena.backend.infrastructure.persistence.user.UserPersistenceAdapter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest(showSql = false)
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({PostgresTestConfiguration.class, JpaAuditingConfiguration.class, BookingPersistenceAdapter.class,
		EventPersistenceAdapter.class, UserPersistenceAdapter.class})
class BookingRepositoryIntegrationTests {

	private static final String PASSWORD_HASH = new BCryptPasswordEncoder(12).encode("test-password");

	@Autowired
	private BookingRepository bookings;

	@Autowired
	private EventRepository events;

	@Autowired
	private UserRepository users;

	@Autowired
	private TestEntityManager entityManager;

	@Autowired
	private JdbcTemplate jdbc;

	private Event event;
	private User user;

	@BeforeEach
	void setUp() {
		user = users.save(new User("participant", "Participant", PASSWORD_HASH));
		event = events.save(new Event("Football", null, "Football", "Park",
				Instant.parse("2030-01-01T10:00:00Z"), Instant.parse("2030-01-01T11:00:00Z"), 20));
		entityManager.flush();
	}

	@Test
	void cancelledRowsCoexistWithNewConfirmationAndDoNotConsumeCapacity() {
		Booking original = bookings.save(new Booking(event, user));
		entityManager.flush();
		original.cancel();
		entityManager.flush();
		Booking replacement = bookings.save(new Booking(event, user));
		entityManager.flush();
		entityManager.clear();

		assertThat(replacement.getId()).isNotEqualTo(original.getId());
		assertThat(bookings.countActiveByEventId(event.getId())).isEqualTo(1);
		assertThat(bookings.hasActiveBooking(event.getId(), user.getId())).isTrue();
		assertThat(bookings.existsByEventId(event.getId())).isTrue();
		assertThat(bookings.findByUserId(user.getId())).hasSize(2);
		Booking loaded = bookings.findByIdAndUserId(original.getId(), user.getId()).orElseThrow();
		entityManager.clear();
		assertThat(loaded.getStatus()).isEqualTo(BookingStatus.CANCELLED);
		assertThat(loaded.getCreatedAt()).isNotNull();
		assertThat(loaded.getUpdatedAt()).isNotNull();
		assertThat(loaded.getEvent().getTitle()).isEqualTo("Football");
		assertThat(bookings.findEventIdByIdAndUserId(loaded.getId(), user.getId())).contains(event.getId());
		assertThat(bookings.findEventIdByIdAndUserId(loaded.getId(), UUID.randomUUID())).isEmpty();

		Booking current = bookings.findByIdAndUserId(replacement.getId(), user.getId()).orElseThrow();
		current.cancel();
		entityManager.flush();
		bookings.save(new Booking(event, user));
		entityManager.flush();
		entityManager.clear();
		assertThat(bookings.findByUserId(user.getId())).hasSize(3)
				.filteredOn(booking -> booking.getStatus() == BookingStatus.CANCELLED).hasSize(2);
		assertThat(bookings.countActiveByEventId(event.getId())).isEqualTo(1);
	}

	@Test
	void partialUniqueIndexRejectsDuplicateConfirmedRows() {
		bookings.save(new Booking(event, user));
		entityManager.flush();
		assertThatThrownBy(() -> {
			bookings.save(new Booking(event, user));
			entityManager.flush();
		}).isInstanceOf(org.hibernate.exception.ConstraintViolationException.class);
	}

	@ParameterizedTest
	@ValueSource(strings = {"event_id", "user_id"})
	void foreignKeysRejectMissingParents(String column) {
		Booking booking = bookings.save(new Booking(event, user));
		entityManager.flush();
		assertThatThrownBy(() -> jdbc.update("UPDATE bookings SET " + column + " = ? WHERE id = ?",
				UUID.randomUUID(), booking.getId())).isInstanceOf(DataIntegrityViolationException.class);
	}

	@ParameterizedTest
	@ValueSource(strings = {"events", "users"})
	void historyPreventsParentDeletionEvenAfterCancellation(String table) {
		Booking booking = bookings.save(new Booking(event, user));
		booking.cancel();
		entityManager.flush();
		UUID id = table.equals("events") ? event.getId() : user.getId();
		assertThatThrownBy(() -> jdbc.update("DELETE FROM " + table + " WHERE id = ?", id))
				.isInstanceOf(DataIntegrityViolationException.class);
	}

	@Test
	void databaseRejectsUnknownBookingStatus() {
		Booking booking = bookings.save(new Booking(event, user));
		entityManager.flush();
		assertThatThrownBy(() -> jdbc.update("UPDATE bookings SET status = ? WHERE id = ?", "UNKNOWN", booking.getId()))
				.isInstanceOf(DataIntegrityViolationException.class);
	}
}
