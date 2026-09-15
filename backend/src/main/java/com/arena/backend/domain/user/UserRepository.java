package com.arena.backend.domain.user;

import java.util.Optional;
import java.util.UUID;

public interface UserRepository {

	User save(User user);

	Optional<User> findById(UUID id);

	Optional<User> findByUsername(String username);
}
