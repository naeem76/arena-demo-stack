package com.arena.backend.configuration;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.time.Duration;
import java.util.UUID;

import com.arena.backend.domain.user.User;
import com.arena.backend.domain.user.UserRepository;
import com.arena.backend.security.ApiScopes;
import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.proc.SecurityContext;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.security.oauth2.core.ClientAuthenticationMethod;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.authorization.OAuth2TokenType;
import org.springframework.security.oauth2.server.authorization.client.InMemoryRegisteredClientRepository;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClient;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClientRepository;
import org.springframework.security.oauth2.server.authorization.config.annotation.web.configurers.OAuth2AuthorizationServerConfigurer;
import org.springframework.security.oauth2.server.authorization.settings.AuthorizationServerSettings;
import org.springframework.security.oauth2.server.authorization.settings.ClientSettings;
import org.springframework.security.oauth2.server.authorization.settings.TokenSettings;
import org.springframework.security.oauth2.server.authorization.token.JwtEncodingContext;
import org.springframework.security.oauth2.server.authorization.token.OAuth2TokenCustomizer;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.LoginUrlAuthenticationEntryPoint;
import org.springframework.security.web.util.matcher.MediaTypeRequestMatcher;

@Configuration(proxyBeanMethods = false)
@EnableConfigurationProperties(SecurityProperties.class)
public class AuthorizationServerConfiguration {

	@Bean
	@Order(1)
	SecurityFilterChain authorizationServerChain(HttpSecurity http) throws Exception {
		var authorizationServer = OAuth2AuthorizationServerConfigurer.authorizationServer();
		http.securityMatcher(authorizationServer.getEndpointsMatcher())
				.with(authorizationServer, configurer -> {})
				.authorizeHttpRequests(authorize -> authorize.anyRequest().authenticated())
				.exceptionHandling(exceptions -> exceptions.defaultAuthenticationEntryPointFor(
						new LoginUrlAuthenticationEntryPoint("/login"),
						new MediaTypeRequestMatcher(MediaType.TEXT_HTML)));
		return http.build();
	}

	@Bean
	RegisteredClientRepository registeredClients(SecurityProperties properties) {
		RegisteredClient scalar = RegisteredClient.withId("scalar-ui")
				.clientId(properties.clientId())
				.clientName("Scalar API reference")
				.clientAuthenticationMethod(ClientAuthenticationMethod.NONE)
				.authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
				.redirectUri(properties.issuer() + "/scalar")
				.scope(ApiScopes.READ)
				.scope(ApiScopes.WRITE)
				.clientSettings(ClientSettings.builder().requireProofKey(true).build())
				.tokenSettings(TokenSettings.builder().accessTokenTimeToLive(Duration.ofMinutes(15)).build())
				.build();
		return new InMemoryRegisteredClientRepository(scalar);
	}

	@Bean
	AuthorizationServerSettings authorizationServerSettings(SecurityProperties properties) {
		return AuthorizationServerSettings.builder().issuer(properties.issuer()).build();
	}

	@Bean
	PasswordEncoder passwordEncoder() {
		return new BCryptPasswordEncoder(12);
	}

	@Bean
	UserDetailsService userDetailsService(UserRepository users) {
		return username -> users.findByUsername(username)
				.map(user -> org.springframework.security.core.userdetails.User.withUsername(user.getUsername())
						.password(user.getPasswordHash())
						.disabled(!user.isEnabled())
						.roles("USER")
						.build())
				.orElseThrow(() -> new UsernameNotFoundException("Invalid username or password."));
	}

	@Bean
	@ConditionalOnProperty(name = "app.security.seed-demo-user", havingValue = "true")
	ApplicationRunner demoUserInitializer(SecurityProperties properties, UserRepository users,
			PasswordEncoder passwordEncoder) {
		return args -> {
			if (users.findByUsername(properties.demoUsername()).isEmpty()) {
				users.save(new User(properties.demoUsername(), "Demo User",
						passwordEncoder.encode(properties.demoPassword())));
			}
		};
	}

	@Bean
	OAuth2TokenCustomizer<JwtEncodingContext> userSubjectCustomizer(UserRepository users) {
		return context -> {
			if (OAuth2TokenType.ACCESS_TOKEN.equals(context.getTokenType())) {
				User user = users.findByUsername(context.getPrincipal().getName()).orElseThrow();
				context.getClaims().subject(user.getId().toString());
			}
		};
	}

	@Bean
	RSAKey signingKey() throws NoSuchAlgorithmException {
		KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
		generator.initialize(2048);
		KeyPair pair = generator.generateKeyPair();
		return new RSAKey.Builder((RSAPublicKey) pair.getPublic())
				.privateKey((RSAPrivateKey) pair.getPrivate())
				.keyID(UUID.randomUUID().toString())
				.build();
	}

	@Bean
	JWKSource<SecurityContext> jwkSource(RSAKey signingKey) {
		return new ImmutableJWKSet<>(new JWKSet(signingKey));
	}

	@Bean
	JwtEncoder jwtEncoder(JWKSource<SecurityContext> jwkSource) {
		return new NimbusJwtEncoder(jwkSource);
	}

	@Bean
	JwtDecoder jwtDecoder(RSAKey signingKey, SecurityProperties properties) throws JOSEException {
		NimbusJwtDecoder decoder = NimbusJwtDecoder.withPublicKey(signingKey.toRSAPublicKey()).build();
		decoder.setJwtValidator(JwtValidators.createDefaultWithIssuer(properties.issuer()));
		return decoder;
	}
}
