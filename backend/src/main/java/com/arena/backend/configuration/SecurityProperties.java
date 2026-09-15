package com.arena.backend.configuration;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties("app.security")
public record SecurityProperties(
		@NotBlank String issuer,
		@NotBlank String clientId,
		@NotBlank String webOrigin,
		@NotBlank String demoUsername,
		@NotBlank String demoPassword,
		@NotBlank String demoAdminUsername,
		@NotBlank String demoAdminPassword) {

	@Override
	public String toString() {
		return "SecurityProperties[issuer=" + issuer + ", clientId=" + clientId + ", webOrigin=" + webOrigin
				+ ", demoUsername=" + demoUsername + ", demoPassword=[REDACTED]"
				+ ", demoAdminUsername=" + demoAdminUsername + ", demoAdminPassword=[REDACTED]]";
	}
}
