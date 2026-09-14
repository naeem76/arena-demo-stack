package com.arena.backend;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Base64;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.web.util.UriComponentsBuilder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
		"app.security.issuer=http://localhost:8080",
		"app.security.demo-username=demo",
		"app.security.demo-password=arena-demo"
})
@AutoConfigureMockMvc
@ActiveProfiles("diagnostics")
@Import(PostgresTestConfiguration.class)
class SecurityIntegrationTests {

	private static final String ISSUER = "http://localhost:8080";
	private static final String REDIRECT_URI = ISSUER + "/scalar";
	private static final String VERIFIER = "a".repeat(64);

	@Autowired
	private MockMvc mvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private JwtEncoder jwtEncoder;

	@Test
	void browserPreflightDoesNotRequireBearerToken() throws Exception {
		mvc.perform(options("/api/diagnostics/validation")
				.header(HttpHeaders.ORIGIN, "http://localhost:4200")
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST")
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "Authorization,Content-Type"))
				.andExpect(status().isOk())
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "http://localhost:4200"));
	}

	@Test
	void requiresBearerTokenRatherThanRedirectingApiRequestsToLogin() throws Exception {
		mvc.perform(get("/api/diagnostics/errors/404").accept(MediaType.TEXT_HTML))
				.andExpect(status().isUnauthorized())
				.andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, "Bearer"))
				.andExpect(header().doesNotExist(HttpHeaders.LOCATION))
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(jsonPath("$.status").value(401))
				.andExpect(jsonPath("$.instance").value("/api/diagnostics/errors/404"));
	}

	@Test
	void rejectsMalformedTokenWithoutLeakingDecoderDetails() throws Exception {
		mvc.perform(get("/api/diagnostics/errors/404").header(HttpHeaders.AUTHORIZATION, "Bearer not-a-jwt"))
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.detail").value("A valid bearer token is required."));
	}

	@Test
	void rejectsExpiredToken() throws Exception {
		mvc.perform(get("/api/diagnostics/errors/404").header(HttpHeaders.AUTHORIZATION,
				"Bearer " + signedToken(ISSUER, "api.read", Instant.now().minusSeconds(120))))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void rejectsWrongIssuer() throws Exception {
		mvc.perform(get("/api/diagnostics/errors/404").header(HttpHeaders.AUTHORIZATION,
				"Bearer " + signedToken("http://wrong-issuer.example", "api.read", Instant.now().plusSeconds(300))))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void rejectsTamperedSignature() throws Exception {
		String[] parts = signedToken(ISSUER, "api.read", Instant.now().plusSeconds(300)).split("\\.");
		parts[2] = (parts[2].startsWith("a") ? "b" : "a") + parts[2].substring(1);
		mvc.perform(get("/api/diagnostics/errors/404")
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + String.join(".", parts)))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void readOnlyTokenCannotWrite() throws Exception {
		mvc.perform(post("/api/diagnostics/validation")
				.header(HttpHeaders.AUTHORIZATION,
						"Bearer " + signedToken(ISSUER, "api.read", Instant.now().plusSeconds(300)))
				.contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"sample\",\"quantity\":1}"))
				.andExpect(status().isForbidden())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, containsString("insufficient_scope")))
				.andExpect(jsonPath("$.status").value(403));
	}

	@Test
	void loginSessionDoesNotAuthenticateApiRequests() throws Exception {
		mvc.perform(get("/api/diagnostics/errors/404").session(login()))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void loginRequiresCsrfToken() throws Exception {
		mvc.perform(post("/login").param("username", "demo").param("password", "arena-demo"))
				.andExpect(status().isForbidden());
	}

	@Test
	void rejectsIncorrectLoginPassword() throws Exception {
		mvc.perform(post("/login").with(csrf()).param("username", "demo").param("password", "wrong"))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, "/login?error"));
	}

	@Test
	void authorizationCodeWithPkceIssuesUsableJwtAndCannotBeReplayed() throws Exception {
		String code = authorize();
		String body = exchange(code, VERIFIER)
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.token_type").value("Bearer"))
				.andExpect(jsonPath("$.expires_in").isNumber())
				.andReturn().getResponse().getContentAsString();
		JsonNode tokens = objectMapper.readTree(body);
		String token = tokens.get("access_token").asText();

		mvc.perform(get("/api/diagnostics/errors/409").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.detail").value("Diagnostic error response."));
		mvc.perform(post("/api/diagnostics/validation").header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
				.contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"sample\",\"quantity\":1}"))
				.andExpect(status().isOk());
		exchange(code, VERIFIER).andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.error").value("invalid_grant"));
	}

	@ParameterizedTest
	@ValueSource(strings = {"", "incorrect-verifier"})
	void rejectsMissingOrWrongPkceVerifier(String verifier) throws Exception {
		exchange(authorize(), verifier).andExpect(status().isBadRequest());
	}

	@Test
	void requiresPkceChallengeAtAuthorization() throws Exception {
		mvc.perform(get("/oauth2/authorize").session(login())
				.queryParam("client_id", "scalar").queryParam("response_type", "code")
				.queryParam("redirect_uri", REDIRECT_URI).queryParam("scope", "api.read"))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, containsString("error=invalid_request")));
	}

	@Test
	void publishesOAuthFlowAndScalarPkceSettings() throws Exception {
		mvc.perform(get("/v3/api-docs"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.components.securitySchemes.arenaOAuth.flows.authorizationCode.authorizationUrl")
						.value(ISSUER + "/oauth2/authorize"))
				.andExpect(jsonPath("$.components.securitySchemes.arenaOAuth.flows.authorizationCode.tokenUrl")
						.value(ISSUER + "/oauth2/token"));
		mvc.perform(get("/scalar"))
				.andExpect(status().isOk())
				.andExpect(content().string(containsString("SHA-256")))
				.andExpect(content().string(containsString(REDIRECT_URI)));
	}

	@Test
	void publishesOnlyPublicSigningKeyMaterial() throws Exception {
		String body = mvc.perform(get("/oauth2/jwks"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.keys[0].kty").value("RSA"))
				.andExpect(jsonPath("$.keys[0].d").doesNotExist())
				.andReturn().getResponse().getContentAsString();
		assertThat(objectMapper.readTree(body).get("keys").size()).isEqualTo(1);
	}

	private MockHttpSession login() throws Exception {
		return (MockHttpSession) mvc.perform(post("/login").with(csrf())
				.param("username", "demo").param("password", "arena-demo"))
				.andExpect(status().isFound()).andReturn().getRequest().getSession(false);
	}

	private String authorize() throws Exception {
		String challenge = Base64.getUrlEncoder().withoutPadding().encodeToString(
				MessageDigest.getInstance("SHA-256").digest(VERIFIER.getBytes(StandardCharsets.US_ASCII)));
		String redirect = mvc.perform(get("/oauth2/authorize").session(login())
				.queryParam("client_id", "scalar").queryParam("response_type", "code")
				.queryParam("redirect_uri", REDIRECT_URI).queryParam("scope", "api.read api.write")
				.queryParam("code_challenge", challenge).queryParam("code_challenge_method", "S256"))
				.andExpect(status().isFound()).andReturn().getResponse().getRedirectedUrl();
		String code = UriComponentsBuilder.fromUriString(redirect).build().getQueryParams().getFirst("code");
		assertThat(code).isNotBlank();
		return code;
	}

	private ResultActions exchange(String code, String verifier) throws Exception {
		return mvc.perform(post("/oauth2/token").contentType(MediaType.APPLICATION_FORM_URLENCODED)
				.param("grant_type", "authorization_code").param("client_id", "scalar")
				.param("redirect_uri", REDIRECT_URI).param("code", code).param("code_verifier", verifier));
	}

	private String signedToken(String issuer, String scope, Instant expiresAt) {
		JwtClaimsSet claims = JwtClaimsSet.builder().issuer(issuer).subject("demo")
				.issuedAt(expiresAt.minusSeconds(600)).expiresAt(expiresAt).claim("scope", scope).build();
		return jwtEncoder.encode(JwtEncoderParameters.from(
				JwsHeader.with(SignatureAlgorithm.RS256).build(), claims)).getTokenValue();
	}
}
