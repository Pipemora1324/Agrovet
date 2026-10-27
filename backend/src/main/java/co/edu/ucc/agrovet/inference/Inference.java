package co.edu.ucc.agrovet.inference;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Resultado del modelo LSTM ejecutado en el celular. */
@Entity
@Table(name = "inferences")
public class Inference {

    @Id
    private UUID id;

    @Column(name = "cow_id", nullable = false)
    private UUID cowId;

    @Column(name = "window_end_date", nullable = false)
    private LocalDate windowEndDate;

    @Column(nullable = false)
    private double probability;

    @Enumerated(EnumType.STRING)
    @Column(name = "risk_level", nullable = false, length = 10)
    private RiskLevel riskLevel;

    @Column(name = "model_version", nullable = false, length = 40)
    private String modelVersion;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(nullable = false)
    private boolean deleted;

    protected Inference() {
    }

    public Inference(UUID id, Instant createdAt) {
        this.id = id;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public void update(UUID cowId, LocalDate windowEndDate, double probability, RiskLevel riskLevel,
            String modelVersion, boolean deleted, Instant updatedAt) {
        this.cowId = cowId;
        this.windowEndDate = windowEndDate;
        this.probability = probability;
        this.riskLevel = riskLevel;
        this.modelVersion = modelVersion;
        this.deleted = deleted;
        this.updatedAt = updatedAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCowId() {
        return cowId;
    }

    public LocalDate getWindowEndDate() {
        return windowEndDate;
    }

    public double getProbability() {
        return probability;
    }

    public RiskLevel getRiskLevel() {
        return riskLevel;
    }

    public String getModelVersion() {
        return modelVersion;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
