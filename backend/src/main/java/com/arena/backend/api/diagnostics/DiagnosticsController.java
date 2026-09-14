package com.arena.backend.api.diagnostics;

import com.arena.backend.security.ApiScopes;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@Profile("diagnostics")
@RestController
@RequestMapping("/api/diagnostics")
@Tag(name = "Diagnostics", description = "Manual error testing; available only with the diagnostics profile.")
public class DiagnosticsController {

	@GetMapping("/errors/{status}")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.READ)
	@Operation(summary = "Exercise an HTTP error status from 400 through 599")
	@ApiResponse(responseCode = "default", description = "Requested error, or 400 for invalid input",
			content = @Content(mediaType = "application/problem+json",
					schema = @Schema(implementation = ProblemDetail.class)))
	public ProblemDetail error(@PathVariable @Min(400) @Max(599) int status) {
		throw new ResponseStatusException(HttpStatusCode.valueOf(status), "Diagnostic error response.");
	}

	@GetMapping("/errors/unexpected")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.READ)
	@Operation(summary = "Trigger an unexpected exception to verify logging and error masking")
	@ApiResponse(responseCode = "500", description = "Masked internal server error",
			content = @Content(mediaType = "application/problem+json",
					schema = @Schema(implementation = ProblemDetail.class)))
	public ProblemDetail unexpectedError() {
		throw new IllegalStateException("Diagnostic exception: internal details must stay in server logs.");
	}

	@PostMapping("/validation")
	@SecurityRequirement(name = "arenaOAuth", scopes = ApiScopes.WRITE)
	@Operation(summary = "Validate a sample request; echo valid input")
	public ValidationRequest validate(@Valid @RequestBody ValidationRequest request) {
		return request;
	}

	public record ValidationRequest(
			@NotBlank @Size(max = 80) String name,
			@NotNull @Min(1) @Max(100) Integer quantity) {
	}
}
