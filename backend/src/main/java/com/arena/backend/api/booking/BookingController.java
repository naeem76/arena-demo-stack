package com.arena.backend.api.booking;

import java.util.UUID;

import com.arena.backend.api.PaginationRequest;
import com.arena.backend.application.booking.BookingService;
import com.arena.backend.domain.booking.Booking;
import com.arena.backend.domain.booking.BookingStatus;
import com.arena.backend.security.ApiScopes;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.headers.Header;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping(value = "/api/bookings", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Bookings", description = "Personal reservations and administrator booking management")
public class BookingController {

	private final BookingService service;

	public BookingController(BookingService service) {
		this.service = service;
	}

	@GetMapping
	@Operation(summary = "List your bookings; administrators may request scope=all",
			description = "Defaults to scope=mine, including for administrators. Optional eventId and status filters apply to either scope.")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.ACCESS)
	public BookingPageResponse list(Authentication principal,
			@RequestParam(defaultValue = "mine") @Pattern(regexp = "mine|all") String scope,
			@RequestParam(required = false) UUID eventId,
			@RequestParam(required = false) BookingStatus status,
			@Valid @ModelAttribute @ParameterObject PaginationRequest pagination) {
		return new BookingPageResponse(service.list(principal, scope.equals("all"), eventId, status,
				pagination.toPageRequest()).map(BookingMapper::toResponse));
	}

	@GetMapping("/{id}")
	@Operation(summary = "Read a booking as its owner or an administrator")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.ACCESS)
	public BookingResponse get(@PathVariable UUID id, Authentication principal) {
		return BookingMapper.toResponse(service.findById(id, principal));
	}

	@PostMapping
	@Operation(summary = "Reserve one place at an event")
	@ApiResponse(responseCode = "201", description = "Booking created",
			headers = @Header(name = "Location", description = "URL of the created booking"))
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.ACCESS)
	public ResponseEntity<BookingResponse> create(@Valid @RequestBody BookingRequest request,
			@AuthenticationPrincipal Jwt principal) {
		Booking booking = service.create(request.eventId(), UUID.fromString(principal.getSubject()));
		return ResponseEntity.created(ServletUriComponentsBuilder.fromCurrentRequestUri()
				.path("/{id}").buildAndExpand(booking.getId()).toUri()).body(BookingMapper.toResponse(booking));
	}

	@PostMapping("/{id}/cancel")
	@Operation(summary = "Cancel a booking as its owner or an administrator before the event starts")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.ACCESS)
	public BookingResponse cancel(@PathVariable UUID id, Authentication principal) {
		return BookingMapper.toResponse(service.cancel(id, principal));
	}
}
