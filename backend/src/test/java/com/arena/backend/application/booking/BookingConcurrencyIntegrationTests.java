package com.arena.backend.application.booking;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import com.arena.backend.PostgresTestConfiguration;
import com.arena.backend.application.event.EventService;
import com.arena.backend.domain.booking.BookingRepository;
import com.arena.backend.domain.common.StateConflictException;
import com.arena.backend.domain.user.User;
import com.arena.backend.domain.user.UserRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(PostgresTestConfiguration.class)
class BookingConcurrencyIntegrationTests {

	private static final Instant NOW = Instant.parse("2030-01-01T10:00:00Z");
	private static final Instant START = NOW.plusSeconds(3600);
	private static final Instant END = START.plusSeconds(3600);

	@Autowired
	private BookingService service;

	@Autowired
	private BookingRepository bookings;

	@Autowired
	private EventService events;

	@Autowired
	private UserRepository users;

	@Autowired
	private JdbcTemplate jdbc;

	@MockitoBean
	private Clock clock;

	private UUID firstUser;
	private UUID secondUser;

	@BeforeEach
	void setUp() {
		when(clock.instant()).thenReturn(NOW);
		User demo = users.findByUsername("demo").orElseThrow();
		firstUser = demo.getId();
		secondUser = users.save(new User("race-" + UUID.randomUUID(), "Other user", demo.getPasswordHash())).getId();
	}

	@AfterEach
	void cleanUp() {
		jdbc.update("DELETE FROM bookings");
		jdbc.update("DELETE FROM events");
		jdbc.update("DELETE FROM users WHERE id = ?", secondUser);
	}

	@Test
	void onlyOneUserCanReserveTheLastPlace() throws Exception {
		UUID eventId = event(1);
		assertThat(race(() -> service.create(eventId, firstUser), () -> service.create(eventId, secondUser)))
				.containsExactlyInAnyOrder(true, false);
		assertThat(bookings.countActiveByEventId(eventId)).isEqualTo(1);
	}

	@Test
	void simultaneousRequestsCannotCreateDuplicateActiveReservations() throws Exception {
		UUID eventId = event(2);
		assertThat(race(() -> service.create(eventId, firstUser), () -> service.create(eventId, firstUser)))
				.containsExactlyInAnyOrder(true, false);
		assertThat(bookings.findByUserId(firstUser)).hasSize(1);
	}

	@Test
	void capacityReductionAndBookingShareTheSameLock() throws Exception {
		UUID eventId = event(2);
		service.create(eventId, firstUser);
		assertThat(race(() -> service.create(eventId, secondUser),
				() -> events.update(eventId, "Football", null, "Football", "Park", START, END, 1)))
				.containsExactlyInAnyOrder(true, false);
		assertThat(bookings.countActiveByEventId(eventId)).isEqualTo(events.findById(eventId).getCapacity());
	}

	@ParameterizedTest
	@ValueSource(booleans = {false, true})
	void simultaneousCancellationsAreIdempotentAndPreserveHistory(boolean cancelAsAdmin) throws Exception {
		UUID eventId = event(1);
		UUID bookingId = service.create(eventId, firstUser).getId();
		var owner = UsernamePasswordAuthenticationToken.authenticated(firstUser.toString(), null,
				List.of(new SimpleGrantedAuthority("ROLE_USER")));
		var otherCaller = cancelAsAdmin
				? UsernamePasswordAuthenticationToken.authenticated(secondUser.toString(), null,
						List.of(new SimpleGrantedAuthority("ROLE_ADMIN")))
				: owner;
		assertThat(race(() -> service.cancel(bookingId, owner), () -> service.cancel(bookingId, otherCaller)))
				.containsExactly(true, true);
		assertThat(bookings.countActiveByEventId(eventId)).isZero();
		assertThat(bookings.findByUserId(firstUser)).hasSize(1);
		service.create(eventId, secondUser);
		assertThat(bookings.countActiveByEventId(eventId)).isEqualTo(1);
	}

	private UUID event(int capacity) {
		return events.create("Football", null, "Football", "Park", START, END, capacity).getId();
	}

	private List<Boolean> race(Runnable first, Runnable second) throws Exception {
		var start = new CyclicBarrier(2);
		try (var executor = Executors.newFixedThreadPool(2)) {
			var firstResult = executor.submit(() -> attempt(start, first));
			var secondResult = executor.submit(() -> attempt(start, second));
			return List.of(firstResult.get(10, TimeUnit.SECONDS), secondResult.get(10, TimeUnit.SECONDS));
		}
	}

	private boolean attempt(CyclicBarrier start, Runnable action) throws Exception {
		start.await(5, TimeUnit.SECONDS);
		try {
			action.run();
			return true;
		} catch (StateConflictException expected) {
			return false;
		}
	}
}
