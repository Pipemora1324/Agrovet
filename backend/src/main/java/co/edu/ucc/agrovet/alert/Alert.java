package co.edu.ucc.agrovet.alert;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import co.edu.ucc.agrovet.inference.RiskLevel;

@Entity
@Table(name = "alerts")
public class Alert {

    @Id
    private UUID id;

    @Column(name = "cow_id", nullable = false)
    private UUID cowId;

    @Column(name = "inference_id")
    private UUID inferenceId;

    @Enumerated(EnumType.STRING)
    @Column(name = "risk_level", nullable = false, length = 10)
    private RiskLevel riskLevel;

    @Column(nullable = false)
    private boolean attended;

    @Column(name = "attended_at")
    private Instant attendedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(nullable = false)
    private boolean deleted;

    protected Alert() {
    }

    public Alert(UUID id, Instant createdAt) {
        this.id = id;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public void update(UUID cowId, UUID inferenceId, RiskLevel riskLevel, boolean attended, Instant attendedAt,
            boolean deleted, Instant updatedAt) {
        this.cowId = cowId;
        this.inferenceId = inferenceId;
        this.riskLevel = riskLevel;
        this.attended = attended;
        this.attendedAt = attendedAt;
        this.deleted = deleted;
        this.updatedAt = updatedAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCowId() {
        return cowId;
    }

    public UUID getInferenceId() {
        return inferenceId;
    }

    public RiskLevel getRiskLevel() {
        return riskLevel;
    }

    public boolean isAttended() {
        return attended;
    }

    public Instant getAttendedAt() {
        return attendedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
