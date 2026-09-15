package com.arena.backend.configuration;

import com.arena.backend.security.ApiScopes;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.OAuthFlow;
import io.swagger.v3.oas.models.security.OAuthFlows;
import io.swagger.v3.oas.models.security.Scopes;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.oidc.OidcScopes;

@Configuration(proxyBeanMethods = false)
public class OpenApiConfiguration {

	@Bean
	OpenAPI arenaOpenApi(SecurityProperties properties) {
		return new OpenAPI().info(new Info()
				.title("Arena Assessment API")
				.version("0.0.1")
				.description("Backend API for the Arena full-stack developer assessment."))
				.components(new Components().addSecuritySchemes("arenaOAuth", new SecurityScheme()
						.type(SecurityScheme.Type.OAUTH2)
						.flows(new OAuthFlows().authorizationCode(new OAuthFlow()
								.authorizationUrl(properties.issuer() + "/oauth2/authorize")
								.tokenUrl(properties.issuer() + "/oauth2/token")
								.scopes(new Scopes().addString(ApiScopes.ACCESS, "Access the API; roles and ownership determine permitted actions")
										.addString(OidcScopes.OPENID, "Request an OpenID Connect ID token")
										.addString(OidcScopes.PROFILE, "Include the user's display name"))))))
				.addSecurityItem(new SecurityRequirement().addList("arenaOAuth"));
	}
}
