package com.arena.backend.domain.event;

import java.time.Instant;
import java.util.UUID;

import com.arena.backend.domain.common.InvalidInputException;
import com.arena.backend.domain.common.StateConflictException;
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

	public static final int MAX_TITLE_LENGTH = 150;
	public static final int MAX_DESCRIPTION_LENGTH = 2000;
	public static final int MAX_SPORT_LENGTH = 50;
	public static final int MAX_LOCATION_LENGTH = 200;

	@Id
	@GeneratedValue(strategy = GenerationType.UUID)
	@Column(nullable = false, updatable = false)
	private UUID id;

	@NotBlank
	@Size(max = MAX_TITLE_LENGTH)
	@Column(nullable = false, length = MAX_TITLE_LENGTH)
	private String title;

	@Size(max = MAX_DESCRIPTION_LENGTH)
	@Column(length = MAX_DESCRIPTION_LENGTH)
	private String description;

	@NotBlank
	@Size(max = MAX_SPORT_LENGTH)
	@Column(nullable = false, length = MAX_SPORT_LENGTH)
	private String sport;

	@NotBlank
	@Size(max = MAX_LOCATION_LENGTH)
	@Column(nullable = false, length = MAX_LOCATION_LENGTH)
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
		if (status != EventStatus.SCHEDULED) {
			throw new StateConflictException("Only scheduled events can have their details edited.");
		}
		if (startsAt == null || endsAt == null || !endsAt.isAfter(startsAt)) {
			throw new InvalidInputException("Event end time must be after its start time.");
		}
		if (capacity < 1) {
			throw new InvalidInputException("Event capacity must be greater than zero.");
		}
		this.title = title;
		this.description = description;
		this.sport = sport;
		this.location = location;
		this.startsAt = startsAt;
		this.endsAt = endsAt;
		this.capacity = capacity;
	}

	public void changeStatus(EventStatus nextStatus) {
		if (nextStatus == null) {
			throw new InvalidInputException("Event status is required.");
		}
		if (status == nextStatus) {
			return;
		}
		boolean allowed = switch (status) {
			case SCHEDULED -> nextStatus == EventStatus.LIVE || nextStatus == EventStatus.CANCELLED;
			case LIVE -> nextStatus == EventStatus.COMPLETED || nextStatus == EventStatus.CANCELLED;
			case COMPLETED, CANCELLED -> false;
		};
		if (!allowed) {
			throw new StateConflictException("Event cannot change from " + status + " to " + nextStatus + ".");
		}
		status = nextStatus;
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
