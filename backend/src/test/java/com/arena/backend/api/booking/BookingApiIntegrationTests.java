package com.arena.backend.api.booking;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

import com.arena.backend.PostgresTestConfiguration;
import com.arena.backend.application.event.EventService;
import com.arena.backend.domain.user.User;
import com.arena.backend.domain.user.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.JwtRequestPostProcessor;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(PostgresTestConfiguration.class)
class BookingApiIntegrationTests {

	private static final Instant NOW = Instant.parse("2030-01-01T10:00:00Z");
	private static final Instant START = NOW.plusSeconds(3600);
	private static final Instant END = START.plusSeconds(3600);

	@Autowired
	private MockMvc mvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private JdbcTemplate jdbc;

	@Autowired
	private EventService events;

	@Autowired
	private UserRepository users;

	@MockitoBean
	private Clock clock;

	private UUID ownerId;
	private UUID otherId;
	private UUID adminId;

	@BeforeEach
	void setUp() {
		when(clock.instant()).thenReturn(NOW);
		User owner = users.findByUsername("demo").orElseThrow();
		ownerId = owner.getId();
		adminId = users.findByUsername("admin").orElseThrow().getId();
		otherId = users.save(new User("booking-test-" + UUID.randomUUID(), "Other user", owner.getPasswordHash())).getId();
	}

	@AfterEach
	void cleanUp() {
		jdbc.update("DELETE FROM bookings");
		jdbc.update("DELETE FROM events");
		jdbc.update("DELETE FROM users WHERE id = ?", otherId);
	}

	@Test
	void cancellationAndRebookingPreserveSeparateRows() throws Exception {
		UUID eventId = event(1);
		String firstId = book(eventId, ownerId);
		mvc.perform(bookingRequest(eventId, ownerId)).andExpect(status().isConflict());
		mvc.perform(post("/api/bookings/{id}/cancel", firstId).with(access(ownerId)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.status").value("CANCELLED"));
		String secondId = book(eventId, ownerId);
		assertThat(secondId).isNotEqualTo(firstId);
		mvc.perform(get("/api/bookings/{id}", firstId).with(access(ownerId)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.status").value("CANCELLED"));
		mvc.perform(get("/api/bookings").with(access(ownerId)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items", hasSize(2)))
				.andExpect(jsonPath("$.items[0].id").value(secondId))
				.andExpect(jsonPath("$.items[0].event.id").value(eventId.toString()))
				.andExpect(jsonPath("$.items[0].status").value("CONFIRMED"));
	}

	@Test
	void derivesOwnershipFromJwtAndHidesOtherUsersBookings() throws Exception {
		UUID eventId = event(2);
		var response = mvc.perform(post("/api/bookings").with(access(ownerId)).contentType(MediaType.APPLICATION_JSON)
				.content(objectMapper.createObjectNode().put("eventId", eventId.toString())
						.put("userId", otherId.toString()).put("status", "CANCELLED").toString()))
				.andExpect(status().isCreated()).andExpect(jsonPath("$.status").value("CONFIRMED"))
				.andExpect(jsonPath("$.user").doesNotExist()).andReturn().getResponse();
		String id = objectMapper.readTree(response.getContentAsString()).get("id").asText();
		mvc.perform(get("/api/bookings/{id}", id).with(access(ownerId))).andExpect(status().isOk());
		mvc.perform(get("/api/bookings/{id}", id).with(access(otherId))).andExpect(status().isNotFound());
		mvc.perform(post("/api/bookings/{id}/cancel", id).with(access(otherId))).andExpect(status().isNotFound());
		mvc.perform(get("/api/bookings").with(access(otherId))).andExpect(jsonPath("$.items").isEmpty());
	}

	@Test
	void fullEventRejectsBookingAndCancellationReleasesItsPlace() throws Exception {
		UUID eventId = event(1);
		String firstId = book(eventId, ownerId);
		mvc.perform(bookingRequest(eventId, otherId)).andExpect(status().isConflict())
				.andExpect(jsonPath("$.detail").value("This event has no available places."));
		mvc.perform(post("/api/bookings/{id}/cancel", firstId).with(access(ownerId))).andExpect(status().isOk());
		book(eventId, otherId);
	}

	@Test
	void bookingHistoryPreventsEventDeletion() throws Exception {
		UUID eventId = event(1);
		String id = book(eventId, ownerId);
		mvc.perform(delete("/api/events/{id}", eventId).with(adminAccess())).andExpect(status().isConflict());
		mvc.perform(post("/api/bookings/{id}/cancel", id).with(access(ownerId))).andExpect(status().isOk());
		mvc.perform(delete("/api/events/{id}", eventId).with(adminAccess())).andExpect(status().isConflict());
		mvc.perform(get("/api/events/{id}", eventId).with(access(ownerId))).andExpect(status().isOk());
	}

	@Test
	void capacityCannotDropBelowConfirmedCountAndRejectedChangesRollBack() throws Exception {
		UUID eventId = event(3);
		book(eventId, ownerId);
		String otherBooking = book(eventId, otherId);
		mvc.perform(capacityUpdate(eventId, 1)).andExpect(status().isConflict());
		mvc.perform(get("/api/events/{id}", eventId).with(access(ownerId))).andExpect(jsonPath("$.capacity").value(3));
		mvc.perform(post("/api/bookings/{id}/cancel", otherBooking).with(access(otherId))).andExpect(status().isOk());
		mvc.perform(capacityUpdate(eventId, 1)).andExpect(status().isOk()).andExpect(jsonPath("$.capacity").value(1));
	}

	@Test
	void cancelledEventRemainsVisibleInBookingHistoryAndCannotBeBooked() throws Exception {
		UUID eventId = event(2);
		String id = book(eventId, ownerId);
		mvc.perform(patch("/api/events/{id}/status", eventId).with(adminAccess()).contentType(MediaType.APPLICATION_JSON)
				.content("{\"status\":\"CANCELLED\"}")).andExpect(status().isOk());
		mvc.perform(get("/api/bookings/{id}", id).with(access(ownerId)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.status").value("CONFIRMED"))
				.andExpect(jsonPath("$.event.status").value("CANCELLED"));
		mvc.perform(bookingRequest(eventId, otherId)).andExpect(status().isConflict());
	}

	@Test
	void bookingAndCancellationCloseAtStartTime() throws Exception {
		UUID eventId = event(2);
		String id = book(eventId, ownerId);
		when(clock.instant()).thenReturn(START);
		mvc.perform(bookingRequest(eventId, otherId)).andExpect(status().isConflict());
		mvc.perform(post("/api/bookings/{id}/cancel", id).with(access(ownerId))).andExpect(status().isConflict());
	}

	@Test
	void repeatedCancellationIsIdempotentEvenAfterDeadline() throws Exception {
		String id = book(event(1), ownerId);
		JsonNode first = objectMapper.readTree(mvc.perform(post("/api/bookings/{id}/cancel", id).with(access(ownerId)))
				.andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
		when(clock.instant()).thenReturn(END);
		mvc.perform(post("/api/bookings/{id}/cancel", id).with(access(ownerId)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.status").value("CANCELLED"));
		assertThat(first.get("id").asText()).isEqualTo(id);
		assertThat(jdbc.queryForObject("SELECT count(*) FROM bookings", Integer.class)).isEqualTo(1);
	}

	@ParameterizedTest
	@ValueSource(strings = {"LIVE", "COMPLETED"})
	void manuallyStartedEventCannotBeBookedOrCancelled(String state) throws Exception {
		UUID eventId = event(2);
		String id = book(eventId, ownerId);
		events.changeStatus(eventId, com.arena.backend.domain.event.EventStatus.LIVE);
		if (state.equals("COMPLETED")) {
			events.changeStatus(eventId, com.arena.backend.domain.event.EventStatus.COMPLETED);
		}
		mvc.perform(bookingRequest(eventId, otherId)).andExpect(status().isConflict());
		mvc.perform(post("/api/bookings/{id}/cancel", id).with(access(ownerId))).andExpect(status().isConflict());
	}

	@Test
	void validatesRequestsAndReportsMissingResources() throws Exception {
		mvc.perform(post("/api/bookings").with(access(ownerId)).contentType(MediaType.APPLICATION_JSON).content("{}"))
				.andExpect(status().isBadRequest()).andExpect(jsonPath("$.errors[0].field").value("eventId"));
		mvc.perform(bookingRequest(UUID.randomUUID(), ownerId)).andExpect(status().isNotFound());
		mvc.perform(get("/api/bookings/{id}", UUID.randomUUID()).with(access(ownerId))).andExpect(status().isNotFound());
		mvc.perform(post("/api/bookings/{id}/cancel", UUID.randomUUID()).with(access(ownerId))).andExpect(status().isNotFound());
	}

	@Test
	void enforcesScopesAndDocumentsBookingInput() throws Exception {
		mvc.perform(get("/api/bookings")).andExpect(status().isUnauthorized());
		mvc.perform(post("/api/bookings").with(jwt().jwt(token -> token.subject(ownerId.toString()))
				.authorities(new SimpleGrantedAuthority("ROLE_USER")))
				.contentType(MediaType.APPLICATION_JSON).content("{}"))
				.andExpect(status().isForbidden());
		mvc.perform(get("/v3/api-docs")).andExpect(status().isOk())
				.andExpect(jsonPath("$.paths['/api/bookings'].get.responses['200'].content['application/json'].schema.$ref").value("#/components/schemas/BookingPageResponse"))
				.andExpect(jsonPath("$.components.schemas.BookingPageResponse.required").value(org.hamcrest.Matchers.containsInAnyOrder("items", "page", "size", "totalElements", "totalPages")))
				.andExpect(jsonPath("$.components.schemas.BookingPageResponse.properties.items.items.$ref").value("#/components/schemas/BookingResponse"))
				.andExpect(jsonPath("$.components.schemas.Participant.required").value(org.hamcrest.Matchers.containsInAnyOrder("id", "displayName")))
				.andExpect(jsonPath("$.paths['/api/bookings'].post.responses['201'].content['application/json']").exists())
				.andExpect(jsonPath("$.components.schemas.BookingResponse.required").value(org.hamcrest.Matchers.containsInAnyOrder("id", "event", "status", "createdAt", "updatedAt", "participant")))
				.andExpect(jsonPath("$.paths['/api/bookings'].post.responses['201'].headers.Location").exists())
				.andExpect(jsonPath("$.components.schemas.BookingRequest.properties.userId").doesNotExist());
	}

	@Test
	void adminReadsAndCancelsOtherUsersBookingsWithoutDeletingHistory() throws Exception {
		UUID eventId = event(1);
		String id = book(eventId, ownerId);
		mvc.perform(get("/api/bookings/{id}", id).with(adminAccess()))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.participant.id").value(ownerId.toString()))
				.andExpect(jsonPath("$.participant.displayName").value("Demo User"))
				.andExpect(jsonPath("$.participant.passwordHash").doesNotExist())
				.andExpect(jsonPath("$.participant.role").doesNotExist());
		mvc.perform(post("/api/bookings/{id}/cancel", id).with(adminAccess()))
				.andExpect(status().isOk()).andExpect(jsonPath("$.status").value("CANCELLED"));
		when(clock.instant()).thenReturn(END);
		mvc.perform(post("/api/bookings/{id}/cancel", id).with(adminAccess())).andExpect(status().isOk());
		mvc.perform(get("/api/bookings/{id}", id).with(access(ownerId)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.status").value("CANCELLED"));
		assertThat(jdbc.queryForObject("SELECT count(*) FROM bookings", Integer.class)).isEqualTo(1);
		assertThat(jdbc.queryForObject("SELECT count(*) FROM bookings WHERE status = 'CONFIRMED'", Integer.class)).isZero();
	}

	@Test
	void adminListingRequiresExplicitAllScopeAndFiltersByEventAndStatus() throws Exception {
		UUID firstEvent = event(3);
		UUID secondEvent = event(1);
		String confirmed = book(firstEvent, ownerId);
		String cancelled = book(firstEvent, otherId);
		String mine = book(firstEvent, adminId);
		book(secondEvent, otherId);
		mvc.perform(post("/api/bookings/{id}/cancel", cancelled).with(adminAccess())).andExpect(status().isOk());
		mvc.perform(get("/api/bookings").with(adminAccess()))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items", hasSize(1)))
				.andExpect(jsonPath("$.items[0].id").value(mine));
		mvc.perform(get("/api/bookings").param("scope", "all").with(adminAccess()))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items", hasSize(4)));
		mvc.perform(get("/api/bookings").param("scope", "all").param("eventId", firstEvent.toString())
				.param("status", "CANCELLED").with(adminAccess()))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items", hasSize(1)))
				.andExpect(jsonPath("$.items[0].id").value(cancelled));
		mvc.perform(get("/api/bookings").param("eventId", firstEvent.toString()).param("status", "CONFIRMED")
				.param("userId", otherId.toString()).param("isAdmin", "true").with(access(ownerId)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items", hasSize(1)))
				.andExpect(jsonPath("$.items[0].id").value(confirmed));
		mvc.perform(get("/api/bookings").param("scope", "all").param("isAdmin", "true").with(access(ownerId)))
				.andExpect(status().isForbidden())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(jsonPath("$.status").value(403));
	}

	@ParameterizedTest
	@ValueSource(strings = {"STARTED", "LIVE", "COMPLETED"})
	void adminCancellationStillHonorsEventLifecycle(String state) throws Exception {
		UUID eventId = event(1);
		String id = book(eventId, ownerId);
		if (state.equals("STARTED")) {
			when(clock.instant()).thenReturn(START);
		} else {
			events.changeStatus(eventId, com.arena.backend.domain.event.EventStatus.LIVE);
			if (state.equals("COMPLETED")) {
				events.changeStatus(eventId, com.arena.backend.domain.event.EventStatus.COMPLETED);
			}
		}
		mvc.perform(post("/api/bookings/{id}/cancel", id).with(adminAccess()))
				.andExpect(status().isConflict());
		mvc.perform(get("/api/bookings/{id}", id).with(adminAccess()))
				.andExpect(jsonPath("$.status").value("CONFIRMED"));
	}

	@Test
	void validatesListScopeAndReportsMissingBookingsForAdmin() throws Exception {
		mvc.perform(get("/api/bookings").param("scope", "everyone").with(adminAccess()))
				.andExpect(status().isBadRequest());
		mvc.perform(get("/api/bookings").param("status", "UNKNOWN").with(adminAccess()))
				.andExpect(status().isBadRequest());
		mvc.perform(get("/api/bookings").param("eventId", "invalid").with(adminAccess()))
				.andExpect(status().isBadRequest());
		mvc.perform(get("/api/bookings/{id}", UUID.randomUUID()).with(adminAccess()))
				.andExpect(status().isNotFound());
		mvc.perform(post("/api/bookings/{id}/cancel", UUID.randomUUID()).with(adminAccess()))
				.andExpect(status().isNotFound());
	}

	@Test
	void paginatesOwnedHistoryBeforeCountingAndKeepsStableNewestFirstOrder() throws Exception {
		List<String> tiedIds = new ArrayList<>();
		for (int i = 0; i < 21; i++) {
			UUID eventId = event(2);
			tiedIds.add(book(eventId, ownerId));
			book(eventId, otherId);
		}
		jdbc.update("UPDATE bookings SET created_at = ?", java.sql.Timestamp.from(NOW));
		tiedIds.sort(Comparator.reverseOrder());
		String newest = book(event(1), ownerId);
		jdbc.update("UPDATE bookings SET created_at = ? WHERE id = ?",
				java.sql.Timestamp.from(NOW.plusSeconds(1)), UUID.fromString(newest));
		List<String> expected = new ArrayList<>();
		expected.add(newest);
		expected.addAll(tiedIds);
		JsonNode first = objectMapper.readTree(mvc.perform(get("/api/bookings").with(access(ownerId)))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items", hasSize(20)))
				.andExpect(jsonPath("$.page").value(0)).andExpect(jsonPath("$.size").value(20))
				.andExpect(jsonPath("$.totalElements").value(22)).andExpect(jsonPath("$.totalPages").value(2))
				.andReturn().getResponse().getContentAsString());
		assertThat(first.properties()).extracting(java.util.Map.Entry::getKey)
				.containsExactlyInAnyOrder("items", "page", "size", "totalElements", "totalPages");
		List<String> actual = new ArrayList<>();
		first.get("items").forEach(item -> actual.add(item.get("id").asText()));
		JsonNode second = objectMapper.readTree(mvc.perform(get("/api/bookings").with(access(ownerId)).param("page", "1"))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items", hasSize(2)))
				.andExpect(jsonPath("$.page").value(1)).andExpect(jsonPath("$.totalElements").value(22))
				.andExpect(jsonPath("$.totalPages").value(2)).andReturn().getResponse().getContentAsString());
		second.get("items").forEach(item -> actual.add(item.get("id").asText()));
		assertThat(actual).containsExactlyElementsOf(expected);
		mvc.perform(get("/api/bookings").with(access(ownerId)).param("page", "2"))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty())
				.andExpect(jsonPath("$.page").value(2)).andExpect(jsonPath("$.size").value(20))
				.andExpect(jsonPath("$.totalElements").value(22)).andExpect(jsonPath("$.totalPages").value(2));
		mvc.perform(get("/api/bookings").with(adminAccess()).param("scope", "all").param("size", "100"))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items", hasSize(43)))
				.andExpect(jsonPath("$.size").value(100)).andExpect(jsonPath("$.totalElements").value(43))
				.andExpect(jsonPath("$.totalPages").value(1));
		mvc.perform(get("/api/bookings").with(adminAccess()))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty())
				.andExpect(jsonPath("$.totalElements").value(0)).andExpect(jsonPath("$.totalPages").value(0));
	}

	@Test
	void appliesScopeAndBothFiltersToPageContentAndTotals() throws Exception {
		UUID selected = event(3);
		String cancelled = book(selected, ownerId);
		mvc.perform(post("/api/bookings/{id}/cancel", cancelled).with(access(ownerId))).andExpect(status().isOk());
		String mine = book(selected, ownerId);
		String other = book(selected, otherId);
		book(event(1), ownerId);
		mvc.perform(get("/api/bookings").with(access(ownerId)).param("eventId", selected.toString())
				.param("status", "CONFIRMED").param("size", "1").param("userId", otherId.toString()))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items[0].id").value(mine))
				.andExpect(jsonPath("$.totalElements").value(1)).andExpect(jsonPath("$.totalPages").value(1));
		mvc.perform(get("/api/bookings").with(adminAccess()).param("scope", "all").param("eventId", selected.toString())
				.param("status", "CONFIRMED").param("size", "1"))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items[0].id").value(other))
				.andExpect(jsonPath("$.totalElements").value(2)).andExpect(jsonPath("$.totalPages").value(2));
		mvc.perform(get("/api/bookings").with(adminAccess()).param("scope", "all").param("eventId", selected.toString())
				.param("status", "CONFIRMED").param("size", "1").param("page", "1"))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items[0].id").value(mine))
				.andExpect(jsonPath("$.totalElements").value(2));
		mvc.perform(get("/api/bookings").with(access(otherId)).param("eventId", selected.toString())
				.param("status", "CANCELLED").param("page", "3").param("size", "1"))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty())
				.andExpect(jsonPath("$.page").value(3)).andExpect(jsonPath("$.size").value(1))
				.andExpect(jsonPath("$.totalElements").value(0)).andExpect(jsonPath("$.totalPages").value(0));
		mvc.perform(get("/api/bookings").with(access(ownerId)).param("scope", "all").param("page", "99"))
				.andExpect(status().isForbidden());
	}

	@Test
	void returnsAuthorizedTotalsForPagesBeyondJpaOffsetRange() throws Exception {
		UUID selected = event(2);
		book(selected, ownerId);
		book(selected, otherId);
		book(event(1), ownerId);
		mvc.perform(get("/api/bookings").with(access(ownerId)).param("eventId", selected.toString())
				.param("status", "CONFIRMED").param("page", "2147483647").param("size", "100"))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty())
				.andExpect(jsonPath("$.page").value(Integer.MAX_VALUE)).andExpect(jsonPath("$.size").value(100))
				.andExpect(jsonPath("$.totalElements").value(1)).andExpect(jsonPath("$.totalPages").value(1));
		mvc.perform(get("/api/bookings").with(adminAccess()).param("scope", "all").param("eventId", selected.toString())
				.param("status", "CONFIRMED").param("page", "2147483647").param("size", "100"))
				.andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty())
				.andExpect(jsonPath("$.totalElements").value(2)).andExpect(jsonPath("$.totalPages").value(1));
	}

	@ParameterizedTest
	@CsvSource({"page,-1", "size,0", "size,-1", "size,101", "page,nope", "size,nope", "page,1.5", "size,1.5", "page,2147483648", "size,2147483648", "page,''", "size,''"})
	void rejectsInvalidPaginationWithProblemDetails(String parameter, String value) throws Exception {
		mvc.perform(get("/api/bookings").with(access(ownerId)).param(parameter, value))
				.andExpect(status().isBadRequest())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(jsonPath("$.status").value(400))
				.andExpect(jsonPath("$.errors[*].field").value(org.hamcrest.Matchers.hasItem(parameter)));
	}

	private UUID event(int capacity) {
		return events.create("Football", null, "Football", "Park", START, END, capacity).getId();
	}

	private String book(UUID eventId, UUID userId) throws Exception {
		var response = mvc.perform(bookingRequest(eventId, userId)).andExpect(status().isCreated())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
				.andExpect(jsonPath("$.createdAt").isNotEmpty()).andReturn().getResponse();
		String id = objectMapper.readTree(response.getContentAsString()).get("id").asText();
		assertThat(response.getHeader(HttpHeaders.LOCATION)).isEqualTo("http://localhost/api/bookings/" + id);
		return id;
	}

	private MockHttpServletRequestBuilder bookingRequest(UUID eventId, UUID userId) {
		return post("/api/bookings").with(access(userId)).contentType(MediaType.APPLICATION_JSON)
				.content(objectMapper.createObjectNode().put("eventId", eventId.toString()).toString());
	}

	private MockHttpServletRequestBuilder capacityUpdate(UUID id, int capacity) {
		return put("/api/events/{id}", id).with(adminAccess()).contentType(MediaType.APPLICATION_JSON)
				.content(objectMapper.createObjectNode().put("title", "Football").put("sport", "Football")
						.put("location", "Park").put("startsAt", START.toString()).put("endsAt", END.toString())
						.put("capacity", capacity).toString());
	}

	private JwtRequestPostProcessor access(UUID userId) {
		return jwt().jwt(token -> token.subject(userId.toString()))
				.authorities(new SimpleGrantedAuthority("SCOPE_api.access"), new SimpleGrantedAuthority("ROLE_USER"));
	}

	private JwtRequestPostProcessor adminAccess() {
		return jwt().jwt(token -> token.subject(adminId.toString()))
				.authorities(new SimpleGrantedAuthority("SCOPE_api.access"), new SimpleGrantedAuthority("ROLE_ADMIN"));
	}
}
