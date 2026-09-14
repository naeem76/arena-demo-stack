package com.arena.backend.api;

import com.arena.backend.api.diagnostics.DiagnosticsController;
import com.arena.backend.configuration.WebConfiguration;
import com.arena.backend.configuration.SecurityConfiguration;
import com.arena.backend.security.SecurityProblemHandler;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = DiagnosticsController.class, properties =
		"app.cors.allowed-origins=http://localhost:4200,http://client.example")
@Import({ApiExceptionHandler.class, WebConfiguration.class, SecurityConfiguration.class, SecurityProblemHandler.class})
@ActiveProfiles("diagnostics")
@WithMockUser(authorities = {"SCOPE_api.read", "SCOPE_api.write"})
class ApiFoundationWebTests {

	@MockitoBean
	private JwtDecoder jwtDecoder;

	@Autowired
	private MockMvc mvc;

	@ParameterizedTest
	@ValueSource(ints = {400, 401, 403, 404, 409, 422, 429, 500, 503})
	void returnsRequestedStatusAsProblemDetails(int code) throws Exception {
		mvc.perform(get("/api/diagnostics/errors/{status}", code))
				.andExpect(status().is(code))
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(jsonPath("$.type").value("about:blank"))
				.andExpect(jsonPath("$.title").isNotEmpty())
				.andExpect(jsonPath("$.status").value(code))
				.andExpect(jsonPath("$.instance").value("/api/diagnostics/errors/" + code))
				.andExpect(jsonPath("$.detail").value(code >= 500
						? "The request could not be completed. Please try again later."
						: "Diagnostic error response."))
				.andExpect(jsonPath("$.trace").doesNotExist())
				.andExpect(jsonPath("$.exception").doesNotExist());
	}

	@ParameterizedTest
	@ValueSource(ints = {399, 600})
	void rejectsStatusOutsideErrorRange(int code) throws Exception {
		mvc.perform(get("/api/diagnostics/errors/{status}", code))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.errors[0].field").value("status"))
				.andExpect(jsonPath("$.errors[0].message").isNotEmpty());
	}

	@Test
	void masksParameterConversionDetails() throws Exception {
		mvc.perform(get("/api/diagnostics/errors/not-a-number"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.detail").value("A request parameter has an invalid type."));
	}

	@Test
	void returnsActionableFieldErrorsWithoutRejectedValues() throws Exception {
		mvc.perform(post("/api/diagnostics/validation")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"name":"", "quantity":0}
						"""))
				.andExpect(status().isBadRequest())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(jsonPath("$.errors[*].field", containsInAnyOrder("name", "quantity")))
				.andExpect(jsonPath("$.errors[0].message").isNotEmpty())
				.andExpect(jsonPath("$.errors[0].rejectedValue").doesNotExist());
	}

	@ParameterizedTest
	@ValueSource(strings = {"{}", "{\"name\":\"sample\",\"quantity\":101}"})
	void rejectsMissingFieldsAndUpperBoundViolations(String body) throws Exception {
		mvc.perform(post("/api/diagnostics/validation")
				.contentType(MediaType.APPLICATION_JSON).content(body))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.errors").isNotEmpty());
	}

	@ParameterizedTest
	@ValueSource(strings = {"{", "{\"name\":\"sample\",\"quantity\":\"invalid\"}"})
	void masksJsonParsingDetails(String body) throws Exception {
		mvc.perform(post("/api/diagnostics/validation")
				.contentType(MediaType.APPLICATION_JSON).content(body))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.detail")
						.value("Request body must contain valid JSON with the expected field types."));
	}

	@Test
	void acceptsValidRequest() throws Exception {
		mvc.perform(post("/api/diagnostics/validation")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"name":"sample", "quantity":1}
						"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.name").value("sample"))
				.andExpect(jsonPath("$.quantity").value(1));
	}

	@Test
	@ExtendWith(OutputCaptureExtension.class)
	void logsUnexpectedExceptionWithoutExposingIt(CapturedOutput output) throws Exception {
		String response = mvc.perform(get("/api/diagnostics/errors/unexpected"))
				.andExpect(status().isInternalServerError())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(jsonPath("$.detail")
						.value("The request could not be completed. Please try again later."))
				.andReturn().getResponse().getContentAsString();

		assertThat(response).doesNotContain("IllegalStateException", "internal details", "stackTrace");
		assertThat(output.getOut()).contains("IllegalStateException", "internal details must stay in server logs");
	}

	@Test
	void preservesFrameworkStatusAndHeaders() throws Exception {
		mvc.perform(get("/api/diagnostics/validation"))
				.andExpect(status().isMethodNotAllowed())
				.andExpect(header().string(HttpHeaders.ALLOW, containsString("POST")))
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON));
	}

	@ParameterizedTest
	@ValueSource(strings = {"http://localhost:4200", "http://client.example"})
	void acceptsPreflightFromConfiguredOrigins(String origin) throws Exception {
		mvc.perform(options("/api/diagnostics/validation")
				.header(HttpHeaders.ORIGIN, origin)
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST")
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "Content-Type,Authorization"))
				.andExpect(status().isOk())
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, origin))
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, containsString("POST")))
				.andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS));
	}

	@Test
	void rejectsUnconfiguredOrigin() throws Exception {
		mvc.perform(options("/api/diagnostics/validation")
				.header(HttpHeaders.ORIGIN, "http://untrusted.example")
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST"))
				.andExpect(status().isForbidden())
				.andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
	}

	@Test
	void includesCorsHeadersOnErrorResponses() throws Exception {
		mvc.perform(get("/api/diagnostics/errors/404")
				.header(HttpHeaders.ORIGIN, "http://localhost:4200"))
				.andExpect(status().isNotFound())
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "http://localhost:4200"))
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, "Location"));
	}
}
