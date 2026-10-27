package co.edu.ucc.agrovet.cow;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "cows")
public class Cow {

    @Id
    private UUID id;

    @Column(name = "owner_id", nullable = false)
    private UUID ownerId;

    @Column(nullable = false, length = 40)
    private String tag;

    @Column(length = 80)
    private String name;

    @Column(length = 60)
    private String breed;

    @Column(name = "birth_date")
    private LocalDate birthDate;

    private Integer calvings;

    @Enumerated(EnumType.STRING)
    @Column(name = "production_status", nullable = false, length = 20)
    private ProductionStatus productionStatus;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(nullable = false)
    private boolean deleted;

    protected Cow() {
    }

    public Cow(UUID id, UUID ownerId, Instant createdAt) {
        this.id = id;
        this.ownerId = ownerId;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public void update(String tag, String name, String breed, LocalDate birthDate, Integer calvings,
            ProductionStatus productionStatus, Instant updatedAt) {
        this.tag = tag;
        this.name = name;
        this.breed = breed;
        this.birthDate = birthDate;
        this.calvings = calvings;
        this.productionStatus = productionStatus;
        this.updatedAt = updatedAt;
    }

    public void setDeleted(boolean deleted, Instant updatedAt) {
        this.deleted = deleted;
        this.updatedAt = updatedAt;
    }

    public boolean isOwnedBy(UUID userId) {
        return ownerId.equals(userId);
    }

    public UUID getId() {
        return id;
    }

    public UUID getOwnerId() {
        return ownerId;
    }

    public String getTag() {
        return tag;
    }

    public String getName() {
        return name;
    }

    public String getBreed() {
        return breed;
    }

    public LocalDate getBirthDate() {
        return birthDate;
    }

    public Integer getCalvings() {
        return calvings;
    }

    public ProductionStatus getProductionStatus() {
        return productionStatus;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public boolean isDeleted() {
        return deleted;
    }
}
