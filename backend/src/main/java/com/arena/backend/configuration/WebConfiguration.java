package com.arena.backend.configuration;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration(proxyBeanMethods = false)
public class WebConfiguration {

	private final List<String> allowedOrigins;

	public WebConfiguration(@Value("${app.cors.allowed-origins}") List<String> allowedOrigins) {
		this.allowedOrigins = List.copyOf(allowedOrigins);
	}

	@Bean
	CorsConfigurationSource corsConfigurationSource() {
		CorsConfiguration policy = new CorsConfiguration();
		policy.setAllowedOrigins(allowedOrigins);
		policy.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
		policy.setAllowedHeaders(List.of("Accept", "Content-Type", "Authorization"));
		policy.setExposedHeaders(List.of("Location"));
		policy.setAllowCredentials(false);
		UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
		for (String path : List.of("/api/**", "/.well-known/openid-configuration",
				"/.well-known/oauth-authorization-server", "/oauth2/jwks", "/oauth2/token", "/userinfo")) {
			source.registerCorsConfiguration(path, policy);
		}
		return source;
	}
}
