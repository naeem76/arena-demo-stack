package com.arena.backend.configuration;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
public class OpenApiConfiguration {

	@Bean
	OpenAPI arenaOpenApi() {
		return new OpenAPI().info(new Info()
				.title("Arena Assessment API")
				.version("0.0.1")
				.description("Backend API for the Arena full-stack developer assessment."));
	}
}
