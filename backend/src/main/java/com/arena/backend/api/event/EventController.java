package com.arena.backend.api.event;

import java.util.List;
import java.util.UUID;

import com.arena.backend.application.event.EventService;
import com.arena.backend.domain.event.Event;
import com.arena.backend.domain.event.EventStatus;
import com.arena.backend.security.ApiScopes;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.headers.Header;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/events")
@Tag(name = "Events", description = "Sports event management")
public class EventController {

	private final EventService service;

	public EventController(EventService service) {
		this.service = service;
	}

	@GetMapping
	@Operation(summary = "List events, optionally filtering by sport and status")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.READ)
	public List<EventResponse> list(
			@RequestParam(required = false) @Size(max = Event.MAX_SPORT_LENGTH) String sport,
			@RequestParam(required = false) EventStatus status) {
		return service.list(sport, status).stream().map(EventMapper::toResponse).toList();
	}

	@GetMapping("/{id}")
	@Operation(summary = "Get event details")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.READ)
	public EventResponse get(@PathVariable UUID id) {
		return EventMapper.toResponse(service.findById(id));
	}

	@PostMapping
	@Operation(summary = "Create a scheduled event")
	@ApiResponse(responseCode = "201", description = "Event created",
			headers = @Header(name = "Location", description = "URL of the created event"))
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.WRITE)
	public ResponseEntity<EventResponse> create(@Valid @RequestBody EventRequest request) {
		Event event = service.create(request.title(), request.description(), request.sport(), request.location(),
				request.startsAt(), request.endsAt(), request.capacity());
		return ResponseEntity.created(ServletUriComponentsBuilder.fromCurrentRequestUri()
				.path("/{id}").buildAndExpand(event.getId()).toUri()).body(EventMapper.toResponse(event));
	}

	@PutMapping("/{id}")
	@Operation(summary = "Replace the editable details of a scheduled event")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.WRITE)
	public EventResponse update(@PathVariable UUID id, @Valid @RequestBody EventRequest request) {
		return EventMapper.toResponse(service.update(id, request.title(), request.description(), request.sport(),
				request.location(), request.startsAt(), request.endsAt(), request.capacity()));
	}

	@PatchMapping("/{id}/status")
	@Operation(summary = "Change event status through an allowed lifecycle transition")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.WRITE)
	public EventResponse changeStatus(@PathVariable UUID id, @Valid @RequestBody EventStatusRequest request) {
		return EventMapper.toResponse(service.changeStatus(id, request.status()));
	}

	@DeleteMapping("/{id}")
	@Operation(summary = "Delete an event")
	@ApiResponse(responseCode = "204", description = "Event deleted")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.WRITE)
	public ResponseEntity<Void> delete(@PathVariable UUID id) {
		service.delete(id);
		return ResponseEntity.noContent().build();
	}
}
