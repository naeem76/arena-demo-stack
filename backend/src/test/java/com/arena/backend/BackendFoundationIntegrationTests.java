package com.arena.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(PostgresTestConfiguration.class)
class BackendFoundationIntegrationTests {

	@Autowired
	private MockMvc mvc;

	@Autowired
	private JdbcTemplate jdbc;

	@Test
	void startsWithPostgresAndFlywayAndReportsHealth() throws Exception {
		assertThat(jdbc.queryForObject("select 1", Integer.class)).isEqualTo(1);
		assertThat(jdbc.queryForObject("select to_regclass('public.flyway_schema_history')::text", String.class))
				.isEqualTo("flyway_schema_history");
		mvc.perform(get("/actuator/health"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("UP"))
				.andExpect(jsonPath("$.components").doesNotExist());
	}

	@Test
	void publishesOpenApiMetadataWithoutDiagnosticEndpoints() throws Exception {
		mvc.perform(get("/v3/api-docs"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.info.title").value("Arena Assessment API"))
				.andExpect(jsonPath("$.info.version").value("0.0.1"))
				.andExpect(jsonPath("$.paths['/scalar']").doesNotExist())
				.andExpect(jsonPath("$.paths['/scalar/scalar.js']").doesNotExist())
				.andExpect(jsonPath("$.paths['/api/diagnostics/errors/{status}']").doesNotExist());
	}

	@Test
	void servesScalarPointingToOpenApi() throws Exception {
		mvc.perform(get("/scalar"))
				.andExpect(status().isOk())
				.andExpect(content().string(containsString("/v3/api-docs")));
	}

	@Test
	void diagnosticsAreUnavailableWithoutTheirProfile() throws Exception {
		mvc.perform(get("/api/diagnostics/errors/400"))
				.andExpect(status().isUnauthorized());
		mvc.perform(get("/api/diagnostics/errors/400")
				.with(jwt().authorities(new SimpleGrantedAuthority("SCOPE_api.read"))))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.status").value(404));
	}
}
