package com.arena.backend.configuration;

import java.nio.charset.StandardCharsets;

import com.arena.backend.domain.user.UserRole;
import com.arena.backend.security.ApiScopes;
import com.arena.backend.security.SecurityProblemHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authorization.AuthorizationManager;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.DelegatingJwtGrantedAuthoritiesConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.intercept.RequestAuthorizationContext;
import org.springframework.security.web.authentication.SimpleUrlAuthenticationFailureHandler;
import org.springframework.security.web.authentication.WebAuthenticationDetails;

import static org.springframework.security.authorization.AuthorizationManagers.allOf;
import static org.springframework.security.authorization.AuthorityAuthorizationManager.hasAnyRole;
import static org.springframework.security.authorization.AuthorityAuthorizationManager.hasAuthority;
import static org.springframework.security.authorization.AuthorityAuthorizationManager.hasRole;

@Configuration(proxyBeanMethods = false)
public class SecurityConfiguration {

	@Bean
	@Order(2)
	SecurityFilterChain apiChain(HttpSecurity http, SecurityProblemHandler problems,
			JwtAuthenticationConverter jwtAuthenticationConverter) throws Exception {
		AuthorizationManager<RequestAuthorizationContext> apiAccess = allOf(
				hasAuthority("SCOPE_" + ApiScopes.ACCESS), hasAnyRole(UserRole.USER.name(), UserRole.ADMIN.name()));
		http.securityMatcher("/api/**")
				.cors(Customizer.withDefaults())
				.csrf(csrf -> csrf.disable())
				.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(authorize -> authorize
						.requestMatchers(HttpMethod.GET, "/api/**").access(apiAccess)
						.requestMatchers(HttpMethod.HEAD, "/api/**").access(apiAccess)
						.requestMatchers("/api/events", "/api/events/**").access(allOf(apiAccess, hasRole(UserRole.ADMIN.name())))
						.anyRequest().access(apiAccess))
				.oauth2ResourceServer(resourceServer -> resourceServer
						.jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter))
						.authenticationEntryPoint(problems).accessDeniedHandler(problems))
				.exceptionHandling(exceptions -> exceptions
						.authenticationEntryPoint(problems).accessDeniedHandler(problems));
		return http.build();
	}

	@Bean
	JwtAuthenticationConverter jwtAuthenticationConverter() {
		JwtGrantedAuthoritiesConverter scopes = new JwtGrantedAuthoritiesConverter();
		JwtGrantedAuthoritiesConverter roles = new JwtGrantedAuthoritiesConverter();
		roles.setAuthoritiesClaimName("roles");
		roles.setAuthorityPrefix("ROLE_");
		JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
		converter.setJwtGrantedAuthoritiesConverter(new DelegatingJwtGrantedAuthoritiesConverter(scopes, roles));
		return converter;
	}

	@Bean
	@Order(3)
	SecurityFilterChain webChain(HttpSecurity http) throws Exception {
		var loginFailure = new SimpleUrlAuthenticationFailureHandler("/login?error");
		http.authorizeHttpRequests(authorize -> authorize
						.requestMatchers("/scalar", "/scalar/**", "/v3/api-docs", "/v3/api-docs/**",
								"/actuator/health", "/error").permitAll()
						.anyRequest().denyAll())
				.formLogin(form -> form.permitAll()
						.authenticationDetailsSource(request -> {
							String password = request.getParameter("password");
							// Reject over-limit input before BCrypt verification can ignore its suffix.
							if (password != null && password.getBytes(StandardCharsets.UTF_8).length > 72) {
								throw new BadCredentialsException("Invalid username or password.");
							}
							return new WebAuthenticationDetails(request);
						})
						.failureHandler((request, response, exception) ->
								loginFailure.onAuthenticationFailure(request, response,
										new BadCredentialsException("Invalid username or password."))));
		return http.build();
	}
}
