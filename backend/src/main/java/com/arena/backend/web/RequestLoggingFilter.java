package com.arena.backend.web;

import java.io.IOException;
import java.util.UUID;

import jakarta.servlet.DispatcherType;
import jakarta.servlet.FilterChain;
import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpServletResponseWrapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.web.filter.OncePerRequestFilter;

public class RequestLoggingFilter extends OncePerRequestFilter {

	private static final Logger log = LoggerFactory.getLogger(RequestLoggingFilter.class);
	private static final String STATE = RequestLoggingFilter.class.getName() + ".state";
	private static final String REQUEST_ID = "requestId";
	private static final String HEADER = "X-Request-ID";

	@Override
	protected boolean shouldNotFilterErrorDispatch() {
		return false;
	}

	@Override
	protected void doFilterNestedErrorDispatch(HttpServletRequest request, HttpServletResponse response,
			FilterChain chain) throws ServletException, IOException {
		doFilterInternal(request, response, chain);
	}

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
			throws ServletException, IOException {
		State state = (State) request.getAttribute(STATE);
		if (state == null) {
			state = new State(safe(request.getMethod(), 16), safe(request.getRequestURI(), 512));
			request.setAttribute(STATE, state);
		}
		String previousId = MDC.get(REQUEST_ID);
		MDC.put(REQUEST_ID, state.id);
		response.setHeader(HEADER, state.id);
		var tracked = new ErrorTrackingResponse(response);
		boolean errorDispatch = request.getDispatcherType() == DispatcherType.ERROR;
		try {
			chain.doFilter(request, tracked);
		}
		catch (IOException | ServletException | RuntimeException | Error exception) {
			// Never log exception messages/causes: SDK errors can contain credentials or URLs.
			failure(state, request, 500, "escaped_exception");
			throw exception;
		}
		finally {
			try {
				if (errorDispatch) {
					Object originalStatus = request.getAttribute(RequestDispatcher.ERROR_STATUS_CODE);
					int status = originalStatus instanceof Integer code ? code : response.getStatus();
					failure(state, request, status, "ERROR");
				}
				else if (!tracked.errorSent) {
					failure(state, request, response.getStatus(), "REQUEST");
				}
			}
			finally {
				if (previousId == null) {
					MDC.remove(REQUEST_ID);
				}
				else {
					MDC.put(REQUEST_ID, previousId);
				}
			}
		}
	}

	private void failure(State state, HttpServletRequest request, int status, String source) {
		if (status < 400 || state.logged) {
			return;
		}
		state.logged = true;
		Object originalUri = request.getAttribute(RequestDispatcher.ERROR_REQUEST_URI);
		String path = originalUri instanceof String uri ? safe(uri, 512) : state.path;
		String message = "HTTP failure method={} path={} status={} requestId={} source={}";
		if (status >= 500) {
			log.error(message, state.method, path, status, state.id, source);
		}
		else {
			log.warn(message, state.method, path, status, state.id, source);
		}
	}

	private static String safe(String value, int limit) {
		if (value == null) {
			return "-";
		}
		// URI normally excludes queries; strip defensively for servlet error attributes too.
		int query = value.indexOf('?');
		int end = Math.min(query < 0 ? value.length() : query, limit);
		StringBuilder result = new StringBuilder(end);
		for (int i = 0; i < end; i++) {
			char character = value.charAt(i);
			result.append(character <= ' ' || character >= 127 ? '_' : character);
		}
		return result.toString();
	}

	private static final class State {
		private final String id = UUID.randomUUID().toString();
		private final String method;
		private final String path;
		private boolean logged;

		private State(String method, String path) {
			this.method = method;
			this.path = path;
		}
	}

	private static final class ErrorTrackingResponse extends HttpServletResponseWrapper {
		private boolean errorSent;

		private ErrorTrackingResponse(HttpServletResponse response) {
			super(response);
		}

		@Override
		public void sendError(int status) throws IOException {
			super.sendError(status);
			errorSent = true;
		}

		@Override
		public void sendError(int status, String message) throws IOException {
			super.sendError(status, message);
			errorSent = true;
		}
	}
}
