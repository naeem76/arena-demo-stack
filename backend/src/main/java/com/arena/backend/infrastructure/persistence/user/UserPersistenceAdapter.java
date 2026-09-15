package com.arena.backend.infrastructure.persistence.user;

import java.util.Optional;
import java.util.UUID;

import com.arena.backend.domain.user.User;
import com.arena.backend.domain.user.UserRepository;
import org.springframework.stereotype.Repository;

@Repository
public class UserPersistenceAdapter implements UserRepository {

	private final JpaUserRepository repository;

	public UserPersistenceAdapter(JpaUserRepository repository) {
		this.repository = repository;
	}

	@Override
	public User save(User user) {
		return repository.save(user);
	}

	@Override
	public Optional<User> findById(UUID id) {
		return repository.findById(id);
	}

	@Override
	public Optional<User> findByUsername(String username) {
		return repository.findByUsernameIgnoreCase(username);
	}
}
