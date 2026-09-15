package com.arena.backend.api.event;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

import com.arena.backend.PostgresTestConfiguration;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
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
import static org.hamcrest.Matchers.containsInAnyOrder;
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
class EventApiIntegrationTests {

	private static final Instant NOW = Instant.parse("2030-01-01T10:00:00Z");

	@Autowired
	private MockMvc mvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private JdbcTemplate jdbc;

	@MockitoBean
	private Clock clock;

	@BeforeEach
	void setClock() {
		when(clock.instant()).thenReturn(NOW);
	}

	@AfterEach
	void removeTestEvents() {
		jdbc.update("DELETE FROM events");
	}

	@Test
	void executesFullCrudWithCorrectResponseContracts() throws Exception {
		var created = mvc.perform(post("/api/events").with(access()).contentType(MediaType.APPLICATION_JSON)
				.content(request("Football").toString()))
				.andExpect(status().isCreated())
				.andExpect(jsonPath("$.status").value("SCHEDULED"))
				.andExpect(jsonPath("$.createdAt").isNotEmpty())
				.andExpect(jsonPath("$.updatedAt").isNotEmpty())
				.andReturn().getResponse();
		String id = objectMapper.readTree(created.getContentAsString()).get("id").asText();
		assertThat(created.getHeader(HttpHeaders.LOCATION)).isEqualTo("http://localhost/api/events/" + id);
		JsonNode details = objectMapper.readTree(mvc.perform(get("/api/events/{id}", id).with(access()))
				.andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
		assertThat(details.get("sport").asText()).isEqualTo("Football");
		assertThat(details.get("capacity").asInt()).isEqualTo(20);

		mvc.perform(get("/api/events").with(access()))
				.andExpect(status().isOk()).andExpect(jsonPath("$[0].id").value(id));
		mvc.perform(put("/api/events/{id}", id).with(access()).contentType(MediaType.APPLICATION_JSON)
				.content(request("Evening football").put("capacity", 24).toString()))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.title").value("Evening football"))
				.andExpect(jsonPath("$.capacity").value(24))
				.andExpect(jsonPath("$.createdAt").value(details.get("createdAt").asText()));
		mvc.perform(delete("/api/events/{id}", id).with(access()))
				.andExpect(status().isNoContent()).andExpect(content().string(""));
		mvc.perform(get("/api/events/{id}", id).with(access())).andExpect(status().isNotFound());
		mvc.perform(get("/api/events").with(access())).andExpect(jsonPath("$").isEmpty());
	}

	@Test
	void protectsServerOwnedFieldsOnCreate() throws Exception {
		String suppliedId = UUID.randomUUID().toString();
		JsonNode result = objectMapper.readTree(mvc.perform(post("/api/events").with(access())
				.contentType(MediaType.APPLICATION_JSON).content(request("Football")
						.put("id", suppliedId).put("status", "LIVE").put("createdAt", "2000-01-01T00:00:00Z").toString()))
				.andExpect(status().isCreated()).andReturn().getResponse().getContentAsString());
		assertThat(result.get("id").asText()).isNotEqualTo(suppliedId);
		assertThat(result.get("status").asText()).isEqualTo("SCHEDULED");
		assertThat(result.get("createdAt").asText()).isNotEqualTo("2000-01-01T00:00:00Z");
	}

	@Test
	void returnsFieldValidationErrorsWithoutSaving() throws Exception {
		ObjectNode invalid = request("").put("capacity", 0);
		invalid.remove("startsAt");
		mvc.perform(post("/api/events").with(access()).contentType(MediaType.APPLICATION_JSON).content(invalid.toString()))
				.andExpect(status().isBadRequest())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(jsonPath("$.errors[*].field", containsInAnyOrder("title", "capacity", "startsAt")));
		assertThat(jdbc.queryForObject("SELECT count(*) FROM events", Integer.class)).isZero();
	}

	@Test
	void rejectsCreationAtCurrentTime() throws Exception {
		mvc.perform(post("/api/events").with(access()).contentType(MediaType.APPLICATION_JSON)
				.content(request("Football").put("startsAt", NOW.toString()).toString()))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.detail").value("New events must start in the future."));
	}

	@Test
	void rejectsInvalidScheduleWithSafeBusinessError() throws Exception {
		ObjectNode invalid = request("Football");
		invalid.put("endsAt", invalid.get("startsAt").asText());
		mvc.perform(post("/api/events").with(access()).contentType(MediaType.APPLICATION_JSON).content(invalid.toString()))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.detail").value("Event end time must be after its start time."));
	}

	@Test
	void enforcesLifecycleAndRollsBackRejectedUpdates() throws Exception {
		String id = create("Football");
		mvc.perform(statusRequest(id, "COMPLETED")).andExpect(status().isConflict());
		mvc.perform(statusRequest(id, "LIVE")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("LIVE"));
		mvc.perform(put("/api/events/{id}", id).with(access()).contentType(MediaType.APPLICATION_JSON)
				.content(request("Forbidden edit").toString()))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.detail").value("Only scheduled events can have their details edited."));
		mvc.perform(get("/api/events/{id}", id).with(access())).andExpect(jsonPath("$.title").value("Football"));
		mvc.perform(statusRequest(id, "COMPLETED")).andExpect(status().isOk());
		mvc.perform(statusRequest(id, "COMPLETED")).andExpect(status().isOk());
		mvc.perform(statusRequest(id, "LIVE")).andExpect(status().isConflict());
	}

	@Test
	void cancelsScheduledEventsWithoutAllowingReopening() throws Exception {
		String id = create("Football");
		mvc.perform(statusRequest(id, "CANCELLED"))
				.andExpect(status().isOk()).andExpect(jsonPath("$.status").value("CANCELLED"));
		mvc.perform(statusRequest(id, "SCHEDULED")).andExpect(status().isConflict());
	}

	@ParameterizedTest
	@ValueSource(strings = {"GET", "PUT", "PATCH", "DELETE"})
	void reportsMissingResourceForEachOperation(String method) throws Exception {
		String id = UUID.randomUUID().toString();
		MockHttpServletRequestBuilder operation = switch (method) {
			case "GET" -> get("/api/events/{id}", id);
			case "PUT" -> put("/api/events/{id}", id).contentType(MediaType.APPLICATION_JSON).content(request("Football").toString());
			case "PATCH" -> statusRequest(id, "LIVE");
			default -> delete("/api/events/{id}", id);
		};
		mvc.perform(operation.with(access())).andExpect(status().isNotFound())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(jsonPath("$.detail").value("Event " + id + " was not found."));
	}

	@Test
	void filtersEventsAndValidatesQueryParameters() throws Exception {
		String first = create("Scheduled football");
		String live = create("Live football");
		mvc.perform(statusRequest(live, "LIVE")).andExpect(status().isOk());
		mvc.perform(get("/api/events").with(access()).param("sport", " fOoTbAlL ").param("status", "SCHEDULED"))
				.andExpect(status().isOk()).andExpect(jsonPath("$", hasSize(1)))
				.andExpect(jsonPath("$[0].id").value(first));
		mvc.perform(get("/api/events").with(access()).param("sport", "Tennis")).andExpect(jsonPath("$").isEmpty());
		mvc.perform(get("/api/events").with(access()).param("status", "UNKNOWN")).andExpect(status().isBadRequest());
		mvc.perform(get("/api/events").with(access()).param("sport", "x".repeat(51))).andExpect(status().isBadRequest());
	}

	@Test
	void rejectsMalformedIdsAndStatusBodies() throws Exception {
		mvc.perform(get("/api/events/not-a-uuid").with(access())).andExpect(status().isBadRequest());
		String id = create("Football");
		mvc.perform(statusRequest(id, "UNKNOWN")).andExpect(status().isBadRequest());
		mvc.perform(patch("/api/events/{id}/status", id).with(access()).contentType(MediaType.APPLICATION_JSON).content("{}"))
				.andExpect(status().isBadRequest()).andExpect(jsonPath("$.errors[0].field").value("status"));
	}

	@Test
	void enforcesAccessScopeAndEventRoles() throws Exception {
		String id = create("Football");
		var userAccess = jwt().authorities(new SimpleGrantedAuthority("SCOPE_api.access"),
				new SimpleGrantedAuthority("ROLE_USER"));
		mvc.perform(get("/api/events")).andExpect(status().isUnauthorized());
		mvc.perform(get("/api/events").with(jwt().authorities(new SimpleGrantedAuthority("SCOPE_api.access"))))
				.andExpect(status().isForbidden());
		mvc.perform(get("/api/events").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER"))))
				.andExpect(status().isForbidden());
		mvc.perform(get("/api/events").with(userAccess)).andExpect(status().isOk());
		mvc.perform(get("/api/events/{id}", id).with(userAccess)).andExpect(status().isOk());
		mvc.perform(post("/api/events").with(userAccess)
				.contentType(MediaType.APPLICATION_JSON).content(request("Football").toString()))
				.andExpect(status().isForbidden());
		mvc.perform(put("/api/events/{id}", id).with(userAccess)
				.contentType(MediaType.APPLICATION_JSON).content(request("Updated football").toString()))
				.andExpect(status().isForbidden());
		mvc.perform(statusRequest(id, "LIVE").with(userAccess)).andExpect(status().isForbidden());
		mvc.perform(delete("/api/events/{id}", id).with(userAccess)).andExpect(status().isForbidden());
	}

	@Test
	void documentsEventContractsInOpenApi() throws Exception {
		mvc.perform(get("/v3/api-docs")).andExpect(status().isOk())
				.andExpect(jsonPath("$.paths['/api/events'].get.responses['200'].content['application/json'].schema.type").value("array"))
				.andExpect(jsonPath("$.paths['/api/events'].post.responses['201'].content['application/json']").exists())
				.andExpect(jsonPath("$.components.schemas.EventResponse.required").value(org.hamcrest.Matchers.hasItems("id", "title", "status")))
				.andExpect(jsonPath("$.components.schemas.EventResponse.properties.description.type").value(org.hamcrest.Matchers.hasItems("string", "null")))
				.andExpect(jsonPath("$.paths['/api/events'].post.responses['201'].headers.Location").exists())
				.andExpect(jsonPath("$.paths['/api/events/{id}'].delete.responses['204']").exists())
				.andExpect(jsonPath("$.components.schemas.EventRequest.properties.id").doesNotExist())
				.andExpect(jsonPath("$.components.schemas.EventRequest.properties.status").doesNotExist());
	}

	private String create(String title) throws Exception {
		String body = mvc.perform(post("/api/events").with(access()).contentType(MediaType.APPLICATION_JSON)
				.content(request(title).toString())).andExpect(status().isCreated())
				.andReturn().getResponse().getContentAsString();
		return objectMapper.readTree(body).get("id").asText();
	}

	private ObjectNode request(String title) {
		return objectMapper.createObjectNode().put("title", title).put("description", "A local sports event")
				.put("sport", "Football").put("location", "Riverside Park").put("capacity", 20)
				.put("startsAt", NOW.plusSeconds(3600).toString()).put("endsAt", NOW.plusSeconds(7200).toString());
	}

	private MockHttpServletRequestBuilder statusRequest(String id, String status) {
		return patch("/api/events/{id}/status", id).with(access()).contentType(MediaType.APPLICATION_JSON)
				.content(objectMapper.createObjectNode().put("status", status).toString());
	}

	private JwtRequestPostProcessor access() {
		return jwt().authorities(new SimpleGrantedAuthority("SCOPE_api.access"), new SimpleGrantedAuthority("ROLE_ADMIN"));
	}
}
