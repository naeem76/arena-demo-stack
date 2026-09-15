package com.arena.backend.api.booking;

import java.util.List;
import java.util.UUID;

import com.arena.backend.application.booking.BookingService;
import com.arena.backend.domain.booking.Booking;
import com.arena.backend.security.ApiScopes;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.headers.Header;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/bookings")
@Tag(name = "Bookings", description = "Reservations and booking history for the signed-in user")
public class BookingController {

	private final BookingService service;

	public BookingController(BookingService service) {
		this.service = service;
	}

	@GetMapping
	@Operation(summary = "List your bookings, including cancelled reservations")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.READ)
	public List<BookingResponse> list(@AuthenticationPrincipal Jwt principal) {
		return service.list(UUID.fromString(principal.getSubject())).stream().map(BookingMapper::toResponse).toList();
	}

	@GetMapping("/{id}")
	@Operation(summary = "Read one of your bookings")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.READ)
	public BookingResponse get(@PathVariable UUID id, @AuthenticationPrincipal Jwt principal) {
		return BookingMapper.toResponse(service.findById(id, UUID.fromString(principal.getSubject())));
	}

	@PostMapping
	@Operation(summary = "Reserve one place at an event")
	@ApiResponse(responseCode = "201", description = "Booking created",
			headers = @Header(name = "Location", description = "URL of the created booking"))
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.WRITE)
	public ResponseEntity<BookingResponse> create(@Valid @RequestBody BookingRequest request,
			@AuthenticationPrincipal Jwt principal) {
		Booking booking = service.create(request.eventId(), UUID.fromString(principal.getSubject()));
		return ResponseEntity.created(ServletUriComponentsBuilder.fromCurrentRequestUri()
				.path("/{id}").buildAndExpand(booking.getId()).toUri()).body(BookingMapper.toResponse(booking));
	}

	@PostMapping("/{id}/cancel")
	@Operation(summary = "Cancel your booking before the event starts")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.WRITE)
	public BookingResponse cancel(@PathVariable UUID id, @AuthenticationPrincipal Jwt principal) {
		return BookingMapper.toResponse(service.cancel(id, UUID.fromString(principal.getSubject())));
	}
}
