package com.arena.backend.domain.event;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

@Entity
@Table(name = "events")
@EntityListeners(AuditingEntityListener.class)
public class Event {

	@Id
	@GeneratedValue(strategy = GenerationType.UUID)
	@Column(nullable = false, updatable = false)
	private UUID id;

	@NotBlank
	@Size(max = 150)
	@Column(nullable = false, length = 150)
	private String title;

	@Size(max = 2000)
	@Column(length = 2000)
	private String description;

	@NotBlank
	@Size(max = 50)
	@Column(nullable = false, length = 50)
	private String sport;

	@NotBlank
	@Size(max = 200)
	@Column(nullable = false, length = 200)
	private String location;

	@NotNull
	@Column(name = "starts_at", nullable = false)
	private Instant startsAt;

	@NotNull
	@Column(name = "ends_at", nullable = false)
	private Instant endsAt;

	@Min(1)
	@Column(nullable = false)
	private int capacity;

	@NotNull
	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 20)
	private EventStatus status = EventStatus.SCHEDULED;

	@CreatedDate
	@Column(name = "created_at", nullable = false, updatable = false)
	private Instant createdAt;

	@LastModifiedDate
	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	protected Event() {
	}

	public Event(String title, String description, String sport, String location,
			Instant startsAt, Instant endsAt, int capacity) {
		updateDetails(title, description, sport, location, startsAt, endsAt, capacity);
	}

	public void updateDetails(String title, String description, String sport, String location,
			Instant startsAt, Instant endsAt, int capacity) {
		this.title = title;
		this.description = description;
		this.sport = sport;
		this.location = location;
		this.startsAt = startsAt;
		this.endsAt = endsAt;
		this.capacity = capacity;
	}

	public void setStatus(EventStatus status) {
		this.status = status;
	}

	public UUID getId() {
		return id;
	}

	public String getTitle() {
		return title;
	}

	public String getDescription() {
		return description;
	}

	public String getSport() {
		return sport;
	}

	public String getLocation() {
		return location;
	}

	public Instant getStartsAt() {
		return startsAt;
	}

	public Instant getEndsAt() {
		return endsAt;
	}

	public int getCapacity() {
		return capacity;
	}

	public EventStatus getStatus() {
		return status;
	}

	public Instant getCreatedAt() {
		return createdAt;
	}

	public Instant getUpdatedAt() {
		return updatedAt;
	}
}
