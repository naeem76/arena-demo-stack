package com.arena.backend.infrastructure.persistence.user;

import com.arena.backend.PostgresTestConfiguration;
import com.arena.backend.configuration.JpaAuditingConfiguration;
import com.arena.backend.domain.user.User;
import com.arena.backend.domain.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest(showSql = false)
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({PostgresTestConfiguration.class, JpaAuditingConfiguration.class, UserPersistenceAdapter.class})
class UserRepositoryIntegrationTests {

	private static final String PASSWORD_HASH = new BCryptPasswordEncoder(12).encode("test-password");

	@Autowired
	private UserRepository repository;

	@Autowired
	private TestEntityManager entityManager;

	@Autowired
	private JdbcTemplate jdbc;

	@Test
	void savesAccountAndProfileWithIdentityAndAuditing() {
		User saved = saveAndReload(new User("Alex", "Alex Smith", PASSWORD_HASH));

		assertThat(saved.getId()).isNotNull();
		assertThat(saved.getUsername()).isEqualTo("Alex");
		assertThat(saved.getDisplayName()).isEqualTo("Alex Smith");
		assertThat(saved.getPasswordHash()).isEqualTo(PASSWORD_HASH);
		assertThat(saved.isEnabled()).isTrue();
		assertThat(saved.getCreatedAt()).isNotNull();
		assertThat(saved.getUpdatedAt()).isEqualTo(saved.getCreatedAt());
		assertThat(repository.findByUsername("aLeX")).get().extracting(User::getId).isEqualTo(saved.getId());
		assertThat(repository.findByUsername("missing-user")).isEmpty();
	}

	@Test
	void updatesProfileAndEnabledStatusWithoutChangingPasswordOrCreationTime() {
		User user = saveAndReload(new User("Alex", "Alex Smith", PASSWORD_HASH));
		var createdAt = user.getCreatedAt();
		user.setDisplayName("Alex Jones");
		user.setEnabled(false);
		User updated = saveAndReload(user);

		assertThat(updated.getDisplayName()).isEqualTo("Alex Jones");
		assertThat(updated.isEnabled()).isFalse();
		assertThat(updated.getCreatedAt()).isEqualTo(createdAt);
		assertThat(updated.getPasswordHash()).isEqualTo(PASSWORD_HASH);
	}

	@ParameterizedTest
	@ValueSource(strings = {"Alex", "aLeX"})
	void databaseRejectsDuplicateUsernamesIgnoringCase(String username) {
		saveAndReload(new User("Alex", "Alex Smith", PASSWORD_HASH));

		assertThatThrownBy(() -> {
			repository.save(new User(username, "Another user", PASSWORD_HASH));
			entityManager.flush();
		}).isInstanceOf(org.hibernate.exception.ConstraintViolationException.class);
	}

	@Test
	void databaseRejectsPlaintextInPasswordHashColumn() {
		User user = saveAndReload(new User("Alex", "Alex Smith", PASSWORD_HASH));

		assertThatThrownBy(() -> jdbc.update("UPDATE users SET password_hash = ? WHERE id = ?",
				"plaintext-password", user.getId())).isInstanceOf(DataIntegrityViolationException.class);
	}

	private User saveAndReload(User user) {
		User saved = repository.save(user);
		entityManager.flush();
		entityManager.clear();
		return repository.findById(saved.getId()).orElseThrow();
	}
}
