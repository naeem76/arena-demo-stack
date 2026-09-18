package com.arena.backend;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.UUID;
import java.util.stream.Stream;

import com.arena.backend.configuration.SecurityProperties;
import com.arena.backend.domain.user.User;
import com.arena.backend.domain.user.UserRepository;
import com.arena.backend.domain.user.UserRole;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.security.web.WebAttributes;
import org.springframework.web.util.UriComponentsBuilder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
		"app.security.issuer=http://localhost:18080",
		"app.security.web-origin=http://localhost:4299",
		"app.security.demo-username=demo",
		"app.security.demo-password=arena-demo"
})
@AutoConfigureMockMvc
@ActiveProfiles("diagnostics")
@Import(PostgresTestConfiguration.class)
class SecurityIntegrationTests {

	private static final String ISSUER = "http://localhost:18080";
	private static final String REDIRECT_URI = ISSUER + "/scalar";
	private static final String WEB_ORIGIN = "http://localhost:4299";
	private static final String VERIFIER = "a".repeat(64);

	@Autowired
	private MockMvc mvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private JwtEncoder jwtEncoder;

	@Autowired
	private JwtDecoder jwtDecoder;

	@Autowired
	private UserRepository users;

	@Autowired
	private PasswordEncoder passwordEncoder;

	@Autowired
	private SecurityProperties securityProperties;

	@Autowired
	@Qualifier("demoUserInitializer")
	private ApplicationRunner demoUserInitializer;

	@Test
	void demoPasswordIsHashedAndNotResetByInitialization() throws Exception {
		User user = users.findByUsername("demo").orElseThrow();
		String hash = user.getPasswordHash();
		assertThat(hash).startsWith("$2a$12$").isNotEqualTo("arena-demo");
		assertThat(passwordEncoder.matches("arena-demo", hash)).isTrue();
		String anotherHash = passwordEncoder.encode("arena-demo");
		assertThat(anotherHash).isNotEqualTo(hash);
		assertThat(passwordEncoder.matches("arena-demo", anotherHash)).isTrue();

		demoUserInitializer.run(new DefaultApplicationArguments());
		assertThat(users.findByUsername("demo").orElseThrow().getPasswordHash()).isEqualTo(hash);
		assertThat(objectMapper.valueToTree(user).has("passwordHash")).isFalse();
		assertThat(securityProperties.toString()).doesNotContain("arena-demo", "arena-admin");
		assertThat(user.getRole()).isEqualTo(UserRole.USER);
		User admin = users.findByUsername("admin").orElseThrow();
		assertThat(admin.getRole()).isEqualTo(UserRole.ADMIN);
		String adminHash = admin.getPasswordHash();
		assertThat(passwordEncoder.matches("arena-admin", adminHash)).isTrue();
		demoUserInitializer.run(new DefaultApplicationArguments());
		assertThat(users.findByUsername("admin").orElseThrow().getPasswordHash()).isEqualTo(adminHash);
	}

	@ParameterizedTest
	@MethodSource("maximumLengthPasswords")
	void frameworkRejectsPasswordsExceedingBcryptByteLimit(String password) {
		String hash = passwordEncoder.encode(password);
		assertThat(passwordEncoder.matches(password, hash)).isTrue();
		assertThatThrownBy(() -> passwordEncoder.encode(password + "x"))
				.isInstanceOf(IllegalArgumentException.class);
	}

	@ParameterizedTest
	@MethodSource("maximumLengthPasswords")
	void loginDoesNotAcceptPasswordSuffixBeyondBcryptLimit(String password) throws Exception {
		String username = "long-password-" + password.charAt(0);
		users.save(new User(username, "Long password user", passwordEncoder.encode(password)));
		mvc.perform(post("/login").with(csrf()).param("username", username).param("password", password))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, "/"));
		mvc.perform(post("/login").with(csrf()).param("username", username)
				.param("password", password + "x"))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, "/login?error"));
	}

	@Test
	void browserPreflightDoesNotRequireBearerToken() throws Exception {
		mvc.perform(options("/api/diagnostics/validation")
				.header(HttpHeaders.ORIGIN, "http://localhost:4299")
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST")
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "Authorization,Content-Type"))
				.andExpect(status().isOk())
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "http://localhost:4299"));
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
				"Bearer " + signedToken(ISSUER, "api.access", Instant.now().minusSeconds(120))))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void rejectsWrongIssuer() throws Exception {
		mvc.perform(get("/api/diagnostics/errors/404").header(HttpHeaders.AUTHORIZATION,
				"Bearer " + signedToken("http://wrong-issuer.example", "api.access", Instant.now().plusSeconds(300))))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void rejectsTamperedSignature() throws Exception {
		String[] parts = signedToken(ISSUER, "api.access", Instant.now().plusSeconds(300)).split("\\.");
		parts[2] = (parts[2].startsWith("a") ? "b" : "a") + parts[2].substring(1);
		mvc.perform(get("/api/diagnostics/errors/404")
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + String.join(".", parts)))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void legacyReadScopeDoesNotGrantApiAccess() throws Exception {
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
	void authPagesRenderAccessibleFormsWithCsrfAndLocalStyles() throws Exception {
		String page = mvc.perform(get("/login"))
				.andExpect(status().isOk())
				.andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_HTML))
				.andExpect(header().string("X-Content-Type-Options", "nosniff"))
				.andExpect(header().string(HttpHeaders.CACHE_CONTROL, containsString("no-store")))
				.andReturn().getResponse().getContentAsString();
		assertThat(page).contains("lang=\"en\"", "href=\"/auth.css\"", "action=\"/login\"", "method=\"post\"",
				"name=\"_csrf\"", "<label for=\"username\">Username</label>",
				"<label for=\"password\">Password</label>", "autocomplete=\"current-password\"")
				.doesNotContain("role=\"alert\"");
		mvc.perform(get("/auth.css"))
				.andExpect(status().isOk())
				.andExpect(content().contentTypeCompatibleWith("text/css"))
				.andExpect(header().string("X-Content-Type-Options", "nosniff"));
		mvc.perform(post("/auth.css").with(csrf()).session(login()))
				.andExpect(status().isForbidden());
		mvc.perform(get("/auth/unexpected").session(login())).andExpect(status().isForbidden());
		mvc.perform(get("/").session(login())).andExpect(status().isForbidden());
	}

	@Test
	void loginErrorNeverRendersUntrustedParametersOrExceptionDetails() throws Exception {
		MockHttpSession session = new MockHttpSession();
		String untrusted = "<script>alert('private-details')</script>";
		session.setAttribute(WebAttributes.AUTHENTICATION_EXCEPTION, new BadCredentialsException(untrusted));
		String page = mvc.perform(get("/login").session(session).param("error", untrusted).param("username", untrusted))
				.andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
		assertThat(page).contains("role=\"alert\"", "aria-describedby=\"login-error\"", "aria-invalid=\"true\"",
				"Invalid username or password.").doesNotContain("private-details", "<script");
	}

	@Test
	void logoutConfirmationIsReadOnlyAndPostRequiresCsrf() throws Exception {
		MockHttpSession session = login();
		String page = mvc.perform(get("/logout").session(session))
				.andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
		assertThat(page).contains("action=\"/logout\"", "method=\"post\"", "name=\"_csrf\"");
		assertThat(session.isInvalid()).isFalse();
		mvc.perform(post("/logout").session(session)).andExpect(status().isForbidden());
		assertThat(session.isInvalid()).isFalse();
		authorize("api.access", session);
		mvc.perform(post("/logout").session(session).with(csrf()))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, "/login?logout"));
		assertThat(session.isInvalid()).isTrue();
		mvc.perform(get("/login?logout"))
				.andExpect(status().isOk())
				.andExpect(content().string(containsString("role=\"status\"")))
				.andExpect(content().string(containsString("You have been signed out.")));
	}

	@Test
	void authPagesAndFailedLoginPreservePendingOAuthRequest() throws Exception {
		MockHttpSession session = (MockHttpSession) mvc.perform(get("/oauth2/authorize")
				.accept(MediaType.TEXT_HTML)
				.queryParam("client_id", "arena-web").queryParam("response_type", "code")
				.queryParam("redirect_uri", WEB_ORIGIN + "/auth/callback")
				.queryParam("scope", "openid profile api.access").queryParam("state", "saved-state")
				.queryParam("code_challenge", VERIFIER).queryParam("code_challenge_method", "S256"))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, "http://localhost/login"))
				.andReturn().getRequest().getSession(false);
		mvc.perform(get("/login").session(session)).andExpect(status().isOk());
		mvc.perform(get("/auth.css").session(session)).andExpect(status().isOk());
		mvc.perform(post("/login").session(session).with(csrf())
				.param("username", "demo").param("password", "wrong"))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, "/login?error"));
		mvc.perform(get("/login?error").session(session)).andExpect(status().isOk());
		String saved = mvc.perform(post("/login").session(session).with(csrf())
				.param("username", "demo").param("password", "arena-demo"))
				.andExpect(status().isFound()).andReturn().getResponse().getRedirectedUrl();
		assertThat(saved).startsWith("http://localhost/oauth2/authorize?");
		mvc.perform(get(URI.create(saved)).session(session))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, containsString(WEB_ORIGIN + "/auth/callback?code=")))
				.andExpect(header().string(HttpHeaders.LOCATION, containsString("state=saved-state")));
	}

	@ParameterizedTest
	@ValueSource(strings = {"demo", "missing-user", "disabled-user"})
	void rejectsInvalidOrDisabledAccountsWithTheSamePublicMessage(String username) throws Exception {
		if (username.equals("disabled-user")) {
			User disabled = new User(username, "Disabled user", passwordEncoder.encode("wrong"));
			disabled.setEnabled(false);
			users.save(disabled);
		}
		MockHttpSession session = (MockHttpSession) mvc.perform(post("/login").with(csrf())
				.param("username", username).param("password", "wrong"))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, "/login?error"))
				.andReturn().getRequest().getSession(false);
		AuthenticationException error = (AuthenticationException) session.getAttribute(WebAttributes.AUTHENTICATION_EXCEPTION);
		assertThat(error.getMessage()).isEqualTo("Invalid username or password.");
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
		assertThat(tokens.has("id_token")).isFalse();
		assertThat(tokens.has("refresh_token")).isFalse();
		String token = tokens.get("access_token").asText();
		assertThat(jwtDecoder.decode(token).getSubject())
				.isEqualTo(users.findByUsername("demo").orElseThrow().getId().toString());
		assertThat(jwtDecoder.decode(token).getClaims()).doesNotContainKeys("password", "passwordHash");
		mvc.perform(get("/userinfo").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
				.andExpect(status().isForbidden());

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
				.queryParam("redirect_uri", REDIRECT_URI).queryParam("scope", "api.access"))
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
	void publishesOidcDiscoveryForBrowserClients() throws Exception {
		mvc.perform(get("/.well-known/openid-configuration")
				.header(HttpHeaders.ORIGIN, "http://localhost:4299"))
				.andExpect(status().isOk())
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "http://localhost:4299"))
				.andExpect(jsonPath("$.issuer").value(ISSUER))
				.andExpect(jsonPath("$.authorization_endpoint").value(ISSUER + "/oauth2/authorize"))
				.andExpect(jsonPath("$.token_endpoint").value(ISSUER + "/oauth2/token"))
				.andExpect(jsonPath("$.jwks_uri").value(ISSUER + "/oauth2/jwks"))
				.andExpect(jsonPath("$.userinfo_endpoint").value(ISSUER + "/userinfo"));
	}

	@ParameterizedTest
	@ValueSource(strings = {"/.well-known/openid-configuration", "/.well-known/oauth-authorization-server",
			"/oauth2/jwks", "/oauth2/token", "/userinfo"})
	void protocolCorsAllowsConfiguredOriginAndRejectsOtherOrigins(String path) throws Exception {
		String method = path.equals("/oauth2/token") ? "POST" : "GET";
		mvc.perform(options(path).header(HttpHeaders.ORIGIN, "http://localhost:4299")
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, method)
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "Authorization,Content-Type"))
				.andExpect(status().isOk())
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "http://localhost:4299"));
		mvc.perform(options(path).header(HttpHeaders.ORIGIN, "https://untrusted.example")
				.header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, method))
				.andExpect(status().isForbidden())
				.andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
	}

	@ParameterizedTest
	@CsvSource({"scalar,openid api.access,http://localhost:18080/scalar", "scalar,openid profile api.access,http://localhost:18080/scalar",
			"arena-web,openid profile api.access,http://localhost:4299/auth/callback",
			"arena-mobile,openid profile api.access,com.arena.mobile:/oauth/callback"})
	void oidcIssuesIdentityAndScopeAppropriateUserInfo(String clientId, String scopes, String redirectUri) throws Exception {
		JsonNode tokens = objectMapper.readTree(exchange(
				authorize(scopes, login(), clientId, redirectUri), VERIFIER, clientId, redirectUri)
				.andExpect(status().isOk())
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, WEB_ORIGIN))
				.andExpect(jsonPath("$.id_token").isString())
				.andExpect(jsonPath("$.refresh_token").doesNotExist())
				.andReturn().getResponse().getContentAsString());
		String accessToken = tokens.get("access_token").asText();
		String idTokenValue = tokens.get("id_token").asText();
		var idToken = jwtDecoder.decode(idTokenValue);
		User user = users.findByUsername("demo").orElseThrow();
		assertThat(idToken.getSubject()).isEqualTo(user.getId().toString());
		assertThat(idToken.getSubject()).isEqualTo(jwtDecoder.decode(accessToken).getSubject());
		assertThat(idToken.getIssuer().toString()).isEqualTo(ISSUER);
		assertThat(idToken.getAudience()).containsExactly(clientId);
		assertThat(idToken.getClaimAsString("nonce")).isEqualTo("test-nonce");
		assertThat(idToken.getExpiresAt()).isAfter(Instant.now());
		assertThat(idToken.getClaims()).doesNotContainKeys("password", "passwordHash", "scope");
		var accessJwt = jwtDecoder.decode(accessToken);
		assertThat(accessJwt.getIssuer().toString()).isEqualTo(ISSUER);
		assertThat(accessJwt.getClaimAsStringList("scope")).containsExactlyInAnyOrder(scopes.split(" "));
		assertThat(tokens.get("scope").asText().split(" ")).containsExactlyInAnyOrder(scopes.split(" "));
		assertThat(accessJwt.getClaimAsStringList("roles")).containsExactly("USER");
		assertThat(idToken.getClaims()).doesNotContainKey("roles");
		assertThat(Duration.between(accessJwt.getIssuedAt(), accessJwt.getExpiresAt())).isEqualTo(Duration.ofMinutes(15));
		JsonNode userInfo = objectMapper.readTree(mvc.perform(get("/userinfo")
				.header(HttpHeaders.ORIGIN, WEB_ORIGIN)
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
				.andExpect(status().isOk())
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, WEB_ORIGIN))
				.andExpect(jsonPath("$.sub").value(user.getId().toString()))
				.andReturn().getResponse().getContentAsString());
		if (scopes.contains("profile")) {
			assertThat(idToken.getClaimAsString("name")).isEqualTo(user.getDisplayName());
			assertThat(userInfo.get("name").asText()).isEqualTo(user.getDisplayName());
			assertThat(userInfo.size()).isEqualTo(2);
		} else {
			assertThat(idToken.getClaims()).doesNotContainKey("name");
			assertThat(userInfo.size()).isEqualTo(1);
		}
		mvc.perform(get("/api/events").header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
				.header(HttpHeaders.ORIGIN, WEB_ORIGIN))
				.andExpect(status().isOk())
				.andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, WEB_ORIGIN));
		mvc.perform(get("/api/events").header(HttpHeaders.AUTHORIZATION, "Bearer " + idTokenValue))
				.andExpect(status().isForbidden());
	}

	@Test
	void userInfoRequiresBearerAuthentication() throws Exception {
		mvc.perform(get("/userinfo")).andExpect(status().isUnauthorized());
		mvc.perform(get("/userinfo").header(HttpHeaders.AUTHORIZATION, "Bearer not-a-jwt"))
				.andExpect(status().isUnauthorized());
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

	@Test
	void identityScopesDoNotGrantApiAccessEvenToAnAdmin() throws Exception {
		String token = signedToken(ISSUER, "openid profile", Instant.now().plusSeconds(300), List.of("ADMIN"));
		mvc.perform(post("/api/diagnostics/validation").header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
				.contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"sample\",\"quantity\":1}"))
				.andExpect(status().isForbidden())
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
				.andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, containsString("insufficient_scope")))
				.andExpect(jsonPath("$.status").value(403));
		mvc.perform(get("/api/events").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
				.andExpect(status().isForbidden());
	}

	@Test
	void apiScopeRequiresAKnownRole() throws Exception {
		String token = signedToken(ISSUER, "api.access", Instant.now().plusSeconds(300), List.of());
		mvc.perform(get("/api/events").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
				.andExpect(status().isForbidden());
	}

	@ParameterizedTest
	@CsvSource({"demo,arena-demo,USER", "admin,arena-admin,ADMIN"})
	void issuedRolesComeFromTheAccountAndControlEventManagement(String username, String password, String role)
			throws Exception {
		JsonNode tokens = objectMapper.readTree(exchange(
				authorize("openid profile api.access", login(username, password)), VERIFIER)
				.andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
		String accessToken = tokens.get("access_token").asText();
		assertThat(jwtDecoder.decode(accessToken).getClaimAsStringList("roles")).containsExactly(role);
		assertThat(jwtDecoder.decode(tokens.get("id_token").asText()).getClaims()).doesNotContainKey("roles");
		mvc.perform(get("/api/events").header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
				.andExpect(status().isOk());
		mvc.perform(delete("/api/events/{id}", UUID.randomUUID())
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
				.andExpect(status().is(role.equals("ADMIN") ? 404 : 403));
	}

	@Test
	void legacyReadWriteScopesCannotBeRequested() throws Exception {
		mvc.perform(get("/oauth2/authorize").session(login())
				.queryParam("client_id", "scalar").queryParam("response_type", "code")
				.queryParam("redirect_uri", REDIRECT_URI).queryParam("scope", "api.read api.write"))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, containsString("error=invalid_scope")));
	}

	@ParameterizedTest
	@CsvSource({"arena-web,http://localhost:4299/unregistered",
			"arena-mobile,com.arena.mobile:/oauth/callback/",
			"arena-mobile,com.arena.mobile://oauth/callback",
			"arena-mobile,http://localhost:4299/auth/callback"})
	void publicClientRejectsUnregisteredAuthorizationRedirect(String clientId, String redirectUri) throws Exception {
		mvc.perform(get("/oauth2/authorize").session(login())
				.queryParam("client_id", clientId).queryParam("response_type", "code")
				.queryParam("redirect_uri", redirectUri).queryParam("scope", "openid profile api.access")
				.queryParam("code_challenge", VERIFIER).queryParam("code_challenge_method", "S256"))
				.andExpect(status().isBadRequest())
				.andExpect(header().doesNotExist(HttpHeaders.LOCATION));
	}

	@ParameterizedTest
	@CsvSource({"arena-web,http://localhost:4299/auth/callback,''", "arena-web,http://localhost:4299/auth/callback,plain",
			"arena-mobile,com.arena.mobile:/oauth/callback,''", "arena-mobile,com.arena.mobile:/oauth/callback,plain"})
	void publicClientRequiresS256Challenge(String clientId, String redirectUri, String method) throws Exception {
		var request = get("/oauth2/authorize").session(login())
				.queryParam("client_id", clientId).queryParam("response_type", "code")
				.queryParam("redirect_uri", redirectUri).queryParam("scope", "openid profile api.access");
		if (!method.isEmpty()) {
			request.queryParam("code_challenge", VERIFIER).queryParam("code_challenge_method", method);
		}
		String redirect = mvc.perform(request).andExpect(status().isFound())
				.andReturn().getResponse().getRedirectedUrl();
		assertThat(redirect).startsWith(redirectUri + "?");
		var parameters = UriComponentsBuilder.fromUriString(redirect).build().getQueryParams();
		assertThat(parameters.getFirst("error")).isEqualTo("invalid_request");
		assertThat(parameters).doesNotContainKey("code");
	}

	@ParameterizedTest
	@CsvSource({"arena-web,http://localhost:4299/auth/callback,''", "arena-web,http://localhost:4299/auth/callback,incorrect-verifier",
			"arena-mobile,com.arena.mobile:/oauth/callback,''", "arena-mobile,com.arena.mobile:/oauth/callback,incorrect-verifier"})
	void publicClientRejectsMissingOrWrongVerifier(String clientId, String redirectUri, String verifier) throws Exception {
		String code = authorize("openid profile api.access", login(), clientId, redirectUri);
		exchange(code, verifier, clientId, redirectUri).andExpect(status().isBadRequest());
	}

	@ParameterizedTest
	@CsvSource({"arena-web,http://localhost:4299/auth/callback,http://localhost:4299/signed-out",
			"arena-mobile,com.arena.mobile:/oauth/callback,com.arena.mobile:/signed-out"})
	void rpLogoutValidatesRedirectAndInvalidatesLoginSession(String clientId, String redirectUri, String logoutUri) throws Exception {
		MockHttpSession session = login();
		String code = authorize("openid profile api.access", session, clientId, redirectUri);
		JsonNode tokens = objectMapper.readTree(exchange(code, VERIFIER, clientId, redirectUri)
				.andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
		String idToken = tokens.get("id_token").asText();
		mvc.perform(get("/connect/logout").session(session)
				.queryParam("id_token_hint", idToken)
				.queryParam("post_logout_redirect_uri", logoutUri + "/"))
				.andExpect(status().isBadRequest())
				.andExpect(header().doesNotExist(HttpHeaders.LOCATION));
		assertThat(session.isInvalid()).isFalse();
		// The rejected logout must leave the real login usable for authorization.
		authorize("openid profile api.access", session, clientId, redirectUri);
		mvc.perform(get("/connect/logout").session(session)
				.queryParam("id_token_hint", idToken)
				.queryParam("post_logout_redirect_uri", logoutUri)
				.queryParam("state", "logout-state"))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, logoutUri + "?state=logout-state"));
		assertThat(session.isInvalid()).isTrue();
		mvc.perform(get("/oauth2/authorize").accept(MediaType.TEXT_HTML)
				.queryParam("client_id", clientId).queryParam("response_type", "code")
				.queryParam("redirect_uri", redirectUri).queryParam("scope", "openid profile api.access")
				.queryParam("code_challenge", VERIFIER).queryParam("code_challenge_method", "S256"))
				.andExpect(status().isFound())
				.andExpect(header().string(HttpHeaders.LOCATION, "http://localhost/login"));
	}

	@Test
	void lanEndpointAliasDoesNotChangeDiscoveryIssuer() throws Exception {
		assertThat(securityProperties.issuer()).isEqualTo(ISSUER);
		mvc.perform(get("/.well-known/openid-configuration")
				.with(request -> {
					request.setServerName("192.168.1.42");
					request.setServerPort(8080);
					return request;
				}).header(HttpHeaders.HOST, "192.168.1.42:8080"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.issuer").value(ISSUER))
				.andExpect(jsonPath("$.authorization_endpoint").value(ISSUER + "/oauth2/authorize"))
				.andExpect(jsonPath("$.token_endpoint").value(ISSUER + "/oauth2/token"))
				.andExpect(jsonPath("$.userinfo_endpoint").value(ISSUER + "/userinfo"))
				.andExpect(jsonPath("$.end_session_endpoint").value(ISSUER + "/connect/logout"));
	}

	@Test
	void userInfoRejectsTamperedMobileAccessToken() throws Exception {
		String redirectUri = "com.arena.mobile:/oauth/callback";
		JsonNode tokens = objectMapper.readTree(exchange(
				authorize("openid profile api.access", login(), "arena-mobile", redirectUri),
				VERIFIER, "arena-mobile", redirectUri)
				.andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
		String token = tokens.get("access_token").asText();
		mvc.perform(get("/userinfo").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
				.andExpect(status().isOk());
		String[] parts = token.split("\\.");
		parts[2] = (parts[2].startsWith("a") ? "b" : "a") + parts[2].substring(1);
		mvc.perform(get("/userinfo").header(HttpHeaders.AUTHORIZATION, "Bearer " + String.join(".", parts)))
				.andExpect(status().isUnauthorized());
	}

	private MockHttpSession login() throws Exception {
		return login("demo", "arena-demo");
	}

	private MockHttpSession login(String username, String password) throws Exception {
		return (MockHttpSession) mvc.perform(post("/login").with(csrf())
				.param("username", username).param("password", password))
				.andExpect(status().isFound()).andReturn().getRequest().getSession(false);
	}

	private String authorize() throws Exception {
		return authorize("api.access");
	}

	private String authorize(String scopes) throws Exception {
		return authorize(scopes, login());
	}

	private String authorize(String scopes, MockHttpSession session) throws Exception {
		return authorize(scopes, session, "scalar", REDIRECT_URI);
	}

	private String authorize(String scopes, MockHttpSession session, String clientId, String redirectUri) throws Exception {
		String challenge = Base64.getUrlEncoder().withoutPadding().encodeToString(
				MessageDigest.getInstance("SHA-256").digest(VERIFIER.getBytes(StandardCharsets.US_ASCII)));
		String redirect = mvc.perform(get("/oauth2/authorize").session(session)
				.queryParam("client_id", clientId).queryParam("response_type", "code")
				.queryParam("redirect_uri", redirectUri).queryParam("scope", scopes)
				.queryParam("nonce", "test-nonce").queryParam("state", "test-state")
				.queryParam("code_challenge", challenge).queryParam("code_challenge_method", "S256"))
				.andExpect(status().isFound()).andReturn().getResponse().getRedirectedUrl();
		assertThat(redirect).startsWith(redirectUri + "?");
		var parameters = UriComponentsBuilder.fromUriString(redirect).build().getQueryParams();
		assertThat(parameters.getFirst("state")).isEqualTo("test-state");
		String code = parameters.getFirst("code");
		assertThat(code).isNotBlank();
		return code;
	}

	private ResultActions exchange(String code, String verifier) throws Exception {
		return exchange(code, verifier, "scalar", REDIRECT_URI);
	}

	private ResultActions exchange(String code, String verifier, String clientId, String redirectUri) throws Exception {
		return mvc.perform(post("/oauth2/token").contentType(MediaType.APPLICATION_FORM_URLENCODED)
				.header(HttpHeaders.ORIGIN, WEB_ORIGIN)
				.param("grant_type", "authorization_code").param("client_id", clientId)
				.param("redirect_uri", redirectUri).param("code", code).param("code_verifier", verifier));
	}

	private String signedToken(String issuer, String scope, Instant expiresAt) {
		return signedToken(issuer, scope, expiresAt, List.of("USER"));
	}

	private String signedToken(String issuer, String scope, Instant expiresAt, List<String> roles) {
		JwtClaimsSet claims = JwtClaimsSet.builder().issuer(issuer).subject("demo")
				.issuedAt(expiresAt.minusSeconds(600)).expiresAt(expiresAt).claim("scope", scope)
				.claim("roles", roles).build();
		return jwtEncoder.encode(JwtEncoderParameters.from(
				JwsHeader.with(SignatureAlgorithm.RS256).build(), claims)).getTokenValue();
	}

	static Stream<String> maximumLengthPasswords() {
		return Stream.of("a".repeat(72), "é".repeat(36));
	}
}
