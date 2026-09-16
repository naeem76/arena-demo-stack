package com.arena.backend.web;

import java.util.UUID;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import jakarta.servlet.DispatcherType;
import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.ServletException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RequestLoggingFilterTests {

	private static final String SECRET = "password-token-sentinel-DO-NOT-LOG";
	private final RequestLoggingFilter filter = new RequestLoggingFilter();
	private final Logger logger = (Logger) LoggerFactory.getLogger(RequestLoggingFilter.class);
	private final ListAppender<ILoggingEvent> logs = new ListAppender<>();

	@BeforeEach
	void captureLogs() {
		logs.start();
		logger.addAppender(logs);
	}

	@AfterEach
	void stopCapture() {
		logger.detachAppender(logs);
		logs.stop();
		MDC.clear();
	}

	@Test
	void escapedExceptionIsRethrownWithoutLeakingItsMessageAndRedispatchReusesId() throws Exception {
		var request = new MockHttpServletRequest("POST", "/oauth2/token");
		request.setQueryString("token=" + SECRET);
		request.setContent(SECRET.getBytes());
		request.addHeader("Authorization", "Bearer " + SECRET);
		request.addHeader("X-Request-ID", SECRET);
		var response = new MockHttpServletResponse();
		var exception = new ServletException(SECRET, new IllegalArgumentException(SECRET));
		MDC.put("requestId", "outer-context");
		assertThatThrownBy(() -> filter.doFilter(request, response, (req, res) -> {
			assertThat(MDC.get("requestId")).isEqualTo(response.getHeader("X-Request-ID"));
			throw exception;
		})).isSameAs(exception);
		String id = response.getHeader("X-Request-ID");
		assertThat(UUID.fromString(id).toString()).isEqualTo(id);
		assertThat(MDC.get("requestId")).isEqualTo("outer-context");
		request.setDispatcherType(DispatcherType.ERROR);
		request.setRequestURI("/error");
		request.setAttribute(RequestDispatcher.ERROR_REQUEST_URI, "/oauth2/token");
		request.setAttribute(RequestDispatcher.ERROR_STATUS_CODE, 500);
		request.setAttribute(RequestDispatcher.ERROR_EXCEPTION, exception);
		var errorResponse = new MockHttpServletResponse();
		filter.doFilter(request, errorResponse, (req, res) -> res.setContentType("text/html"));
		assertThat(errorResponse.getHeader("X-Request-ID")).isEqualTo(id);
		assertThat(logs.list).hasSize(1);
		assertThat(logs.list.getFirst().getFormattedMessage()).contains("method=POST", "path=/oauth2/token",
				"status=500", "requestId=" + id, "source=escaped_exception").doesNotContain(SECRET);
		assertThat(logs.list.getFirst().getThrowableProxy()).isNull();
	}

	@Test
	void errorAttributesAreUsedAndSanitizedEvenWhenErrorPageReturns200() throws Exception {
		var request = new MockHttpServletRequest("GET", "/error");
		request.setDispatcherType(DispatcherType.ERROR);
		request.setAttribute(RequestDispatcher.ERROR_REQUEST_URI, "/original\r\n\t\u0085\u2028?token=" + SECRET);
		request.setAttribute(RequestDispatcher.ERROR_STATUS_CODE, 400);
		request.setAttribute(RequestDispatcher.ERROR_MESSAGE, SECRET);
		var response = new MockHttpServletResponse();
		filter.doFilter(request, response, (req, res) -> {});
		filter.doFilter(request, response, (req, res) -> {});
		assertThat(logs.list).hasSize(1);
		assertThat(logs.list.getFirst().getFormattedMessage()).contains("path=/original_____ ", "status=400",
				"requestId=" + response.getHeader("X-Request-ID"), "source=ERROR").doesNotContain(SECRET, "\n", "\r");
		assertThat(MDC.get("requestId")).isNull();
	}

	@Test
	void nestedErrorDispatchUsesSameIdAndLogsOnlyOriginalFailure() throws Exception {
		var request = new MockHttpServletRequest("POST", "/browser-action");
		var response = new MockHttpServletResponse();
		filter.doFilter(request, response, (req, res) -> {
			String id = MDC.get("requestId");
			request.setDispatcherType(DispatcherType.ERROR);
			request.setRequestURI("/error");
			request.setAttribute(RequestDispatcher.ERROR_REQUEST_URI, "/browser-action");
			request.setAttribute(RequestDispatcher.ERROR_STATUS_CODE, 403);
			filter.doFilter(request, response, (errorRequest, errorResponse) -> {
				assertThat(MDC.get("requestId")).isEqualTo(id);
				response.setStatus(403);
			});
			assertThat(MDC.get("requestId")).isEqualTo(id);
		});
		assertThat(logs.list).hasSize(1);
		assertThat(logs.list.getFirst().getFormattedMessage()).contains("method=POST path=/browser-action status=403",
				"requestId=" + response.getHeader("X-Request-ID"), "source=ERROR");
		assertThat(MDC.get("requestId")).isNull();
	}

	@Test
	void boundsUntrustedPathsAndLogsDirectStatusFailures() throws Exception {
		var request = new MockHttpServletRequest("GET", "/" + "a".repeat(2000));
		filter.doFilter(request, new MockHttpServletResponse(), (req, res) -> {
			((jakarta.servlet.http.HttpServletResponse) res).setStatus(404);
		});
		assertThat(logs.list).hasSize(1);
		assertThat(logs.list.getFirst().getFormattedMessage()).contains("path=/" + "a".repeat(511) + " status=404")
				.doesNotContain("a".repeat(512));
		assertThat(MDC.get("requestId")).isNull();
	}
}
