package com.arena.backend;

import java.io.IOException;
import java.net.CookieManager;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.UUID;
import java.util.regex.Pattern;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import com.arena.backend.web.RequestLoggingFilter;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.slf4j.LoggerFactory;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.web.servlet.ServletRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Import({PostgresTestConfiguration.class, RequestLoggingIntegrationTests.ErrorServletConfiguration.class})
class RequestLoggingIntegrationTests {

	private static final String SECRET = "password-token-sentinel-DO-NOT-LOG";
	private final Logger logger = (Logger) LoggerFactory.getLogger(RequestLoggingFilter.class);
	private final ListAppender<ILoggingEvent> logs = new ListAppender<>();
	private final HttpClient client = HttpClient.newHttpClient();

	@LocalServerPort
	private int port;

	@BeforeEach
	void captureLogs() {
		logs.start();
		logger.addAppender(logs);
	}

	@AfterEach
	void stopCapture() {
		logger.detachAppender(logs);
		logs.stop();
	}

	@ParameterizedTest
	@CsvSource({
			"POST, /login, 403, ERROR",
			"GET, /scalar/unmapped-observability-check, 404, REQUEST",
			"GET, /scalar/observability-server-error, 500, ERROR",
			"POST, /oauth2/token, 401, REQUEST",
			"GET, /oauth2/authorize, 400, ERROR",
			"GET, /api/events, 401, REQUEST"
	})
	void logsRealSecurityAndContainerFailuresOnce(String method, String path, int status, String source)
			throws Exception {
		var request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path
				+ "?password=" + SECRET + "&token=" + SECRET))
				.header("Accept", "application/json")
				.header("X-Request-ID", SECRET)
				.header("Cookie", "secret=" + SECRET)
				.method(method, method.equals("POST") ? HttpRequest.BodyPublishers.ofString(SECRET)
						: HttpRequest.BodyPublishers.noBody()).build();
		var response = client.send(request, HttpResponse.BodyHandlers.ofString());
		assertThat(response.statusCode()).isEqualTo(status);
		String id = response.headers().firstValue("X-Request-ID").orElseThrow();
		assertThat(UUID.fromString(id).toString()).isEqualTo(id);
		assertThat(logs.list).hasSize(1);
		ILoggingEvent event = logs.list.getFirst();
		assertThat(event.getFormattedMessage()).contains("method=" + method, "path=" + path + " ",
				"status=" + status, "requestId=" + id, "source=" + source)
				.doesNotContain(SECRET, "?", "path=/error ");
		assertThat(event.getMDCPropertyMap()).containsEntry("requestId", id);
		assertThat(event.getThrowableProxy()).isNull();
	}

	@Test
	void directLoginDefaultsToDeniedRootAndLogsOriginalPath() throws Exception {
		var browser = HttpClient.newBuilder().cookieHandler(new CookieManager()).build();
		String base = "http://localhost:" + port;
		var loginPage = browser.send(HttpRequest.newBuilder(URI.create(base + "/login")).build(),
				HttpResponse.BodyHandlers.ofString());
		var csrf = Pattern.compile("name=\"_csrf\"[^>]*value=\"([^\"]+)\"").matcher(loginPage.body());
		assertThat(csrf.find()).isTrue();
		var login = browser.send(HttpRequest.newBuilder(URI.create(base + "/login"))
				.header("Content-Type", "application/x-www-form-urlencoded")
				.POST(HttpRequest.BodyPublishers.ofString("username=demo&password=arena-demo&_csrf=" + csrf.group(1)))
				.build(), HttpResponse.BodyHandlers.ofString());
		assertThat(login.statusCode()).isEqualTo(302);
		assertThat(login.headers().firstValue("Location")).contains(base + "/");
		var denied = browser.send(HttpRequest.newBuilder(URI.create(base + "/"))
				.header("Accept", "text/html").build(), HttpResponse.BodyHandlers.ofString());
		assertThat(denied.statusCode()).isEqualTo(403);
		assertThat(logs.list).hasSize(1);
		assertThat(logs.list.getFirst().getFormattedMessage()).contains("method=GET path=/ status=403",
				"source=ERROR", "requestId=" + denied.headers().firstValue("X-Request-ID").orElseThrow())
				.doesNotContain("arena-demo", csrf.group(1));
	}

	@Test
	void successfulRequestsReceiveFreshIdsWithoutFailureLogs() throws Exception {
		var request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/actuator/health"))
				.header("X-Request-ID", SECRET).build();
		var first = client.send(request, HttpResponse.BodyHandlers.ofString());
		var second = client.send(request, HttpResponse.BodyHandlers.ofString());
		assertThat(first.statusCode()).isEqualTo(200);
		assertThat(second.statusCode()).isEqualTo(200);
		String firstId = first.headers().firstValue("X-Request-ID").orElseThrow();
		String secondId = second.headers().firstValue("X-Request-ID").orElseThrow();
		assertThat(UUID.fromString(firstId)).isNotEqualTo(UUID.fromString(secondId));
		assertThat(logs.list).isEmpty();
	}

	@TestConfiguration(proxyBeanMethods = false)
	static class ErrorServletConfiguration {
		@Bean
		ServletRegistrationBean<HttpServlet> errorServlet() {
			return new ServletRegistrationBean<>(new HttpServlet() {
				@Override
				protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
					response.sendError(500);
				}
			}, "/scalar/observability-server-error");
		}
	}
}
