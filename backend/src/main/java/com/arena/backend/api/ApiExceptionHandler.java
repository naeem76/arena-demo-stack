package com.arena.backend.api;

import java.util.Comparator;
import java.util.List;

import com.arena.backend.application.common.ResourceNotFoundException;
import com.arena.backend.domain.common.InvalidInputException;
import com.arena.backend.domain.common.StateConflictException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.TypeMismatchException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {

	private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);
	private static final String SERVER_ERROR_DETAIL = "The request could not be completed. Please try again later.";

	@Override
	protected ResponseEntity<Object> handleMethodArgumentNotValid(
			MethodArgumentNotValidException ex, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
		List<Violation> errors = ex.getBindingResult().getFieldErrors().stream()
				.map(error -> new Violation(error.getField(), error.getDefaultMessage()))
				.toList();
		return handleValidation(ex, errors, headers, status, request);
	}

	@Override
	protected ResponseEntity<Object> handleHandlerMethodValidationException(
			HandlerMethodValidationException ex, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
		List<Violation> errors = ex.getParameterValidationResults().stream()
				.flatMap(result -> result.getResolvableErrors().stream()
						.map(error -> new Violation(result.getMethodParameter().getParameterName(),
								error.getDefaultMessage())))
				.toList();
		return handleValidation(ex, errors, headers, status, request);
	}

	@Override
	protected ResponseEntity<Object> handleHttpMessageNotReadable(
			HttpMessageNotReadableException ex, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
		ProblemDetail problem = ProblemDetail.forStatusAndDetail(status,
				"Request body must contain valid JSON with the expected field types.");
		return handleExceptionInternal(ex, problem, headers, status, request);
	}

	@Override
	protected ResponseEntity<Object> handleTypeMismatch(
			TypeMismatchException ex, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
		ProblemDetail problem = ProblemDetail.forStatusAndDetail(status,
				"A request parameter has an invalid type.");
		return handleExceptionInternal(ex, problem, headers, status, request);
	}

	@ExceptionHandler({ResourceNotFoundException.class, StateConflictException.class, InvalidInputException.class})
	ResponseEntity<Object> handleBusinessException(RuntimeException ex, WebRequest request) {
		HttpStatus status = switch (ex) {
			case ResourceNotFoundException ignored -> HttpStatus.NOT_FOUND;
			case StateConflictException ignored -> HttpStatus.CONFLICT;
			default -> HttpStatus.BAD_REQUEST;
		};
		return handleExceptionInternal(ex, ProblemDetail.forStatusAndDetail(status, ex.getMessage()),
				new HttpHeaders(), status, request);
	}

	@ExceptionHandler(AccessDeniedException.class)
	void handleAccessDenied(AccessDeniedException ex) {
		// Preserve Spring Security's shared forbidden response for service-level authorization.
		throw ex;
	}

	@ExceptionHandler(Exception.class)
	ResponseEntity<Object> handleUnexpectedException(Exception ex, WebRequest request) {
		return handleExceptionInternal(ex, null, new HttpHeaders(), HttpStatus.INTERNAL_SERVER_ERROR, request);
	}

	@Override
	protected ResponseEntity<Object> handleExceptionInternal(
			Exception ex, Object body, HttpHeaders headers, HttpStatusCode statusCode, WebRequest request) {
		if (statusCode.is5xxServerError()) {
			log.error("Request failed with HTTP status {}", statusCode.value(), ex);
			body = ProblemDetail.forStatusAndDetail(statusCode, SERVER_ERROR_DETAIL);
		}
		return super.handleExceptionInternal(ex, body, headers, statusCode, request);
	}

	private ResponseEntity<Object> handleValidation(Exception ex, List<Violation> errors,
			HttpHeaders headers, HttpStatusCode status, WebRequest request) {
		ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, "Request validation failed.");
		problem.setProperty("errors", errors.stream()
				.sorted(Comparator.comparing(Violation::field, Comparator.nullsLast(Comparator.naturalOrder()))
						.thenComparing(Violation::message, Comparator.nullsLast(Comparator.naturalOrder())))
				.toList());
		return handleExceptionInternal(ex, problem, headers, status, request);
	}

	public record Violation(String field, String message) {
	}
}
