package com.arena.backend.configuration;

import java.nio.charset.StandardCharsets;

import com.arena.backend.security.ApiScopes;
import com.arena.backend.security.SecurityProblemHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.SimpleUrlAuthenticationFailureHandler;
import org.springframework.security.web.authentication.WebAuthenticationDetails;

@Configuration(proxyBeanMethods = false)
public class SecurityConfiguration {

	@Bean
	@Order(2)
	SecurityFilterChain apiChain(HttpSecurity http, SecurityProblemHandler problems) throws Exception {
		http.securityMatcher("/api/**")
				.cors(Customizer.withDefaults())
				.csrf(csrf -> csrf.disable())
				.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(authorize -> authorize
						.requestMatchers(HttpMethod.GET, "/api/**").hasAuthority("SCOPE_" + ApiScopes.READ)
						.requestMatchers(HttpMethod.HEAD, "/api/**").hasAuthority("SCOPE_" + ApiScopes.READ)
						.anyRequest().hasAuthority("SCOPE_" + ApiScopes.WRITE))
				.oauth2ResourceServer(resourceServer -> resourceServer.jwt(Customizer.withDefaults())
						.authenticationEntryPoint(problems).accessDeniedHandler(problems))
				.exceptionHandling(exceptions -> exceptions
						.authenticationEntryPoint(problems).accessDeniedHandler(problems));
		return http.build();
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
