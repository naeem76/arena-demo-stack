package com.arena.backend.infrastructure.persistence.user;

import java.util.Optional;
import java.util.UUID;

import com.arena.backend.domain.user.User;
import org.springframework.data.jpa.repository.JpaRepository;

public interface JpaUserRepository extends JpaRepository<User, UUID> {

	Optional<User> findByUsernameIgnoreCase(String username);
}
