package com.arena.backend.configuration;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties("app.security")
public record SecurityProperties(
		@NotBlank String issuer,
		@NotBlank String clientId,
		@NotBlank String demoUsername,
		@NotBlank String demoPassword) {
}
