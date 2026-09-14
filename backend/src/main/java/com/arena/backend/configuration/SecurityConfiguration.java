package com.arena.backend.configuration;

import com.arena.backend.security.ApiScopes;
import com.arena.backend.security.SecurityProblemHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

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
		http.authorizeHttpRequests(authorize -> authorize
						.requestMatchers("/scalar", "/scalar/**", "/v3/api-docs", "/v3/api-docs/**",
								"/actuator/health", "/error").permitAll()
						.anyRequest().denyAll())
				.formLogin(form -> form.permitAll());
		return http.build();
	}
}
