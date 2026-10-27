package co.edu.ucc.agrovet.record;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "daily_records")
public class DailyRecord {

    @Id
    private UUID id;

    @Column(name = "cow_id", nullable = false)
    private UUID cowId;

    @Column(name = "record_date", nullable = false)
    private LocalDate recordDate;

    @Column(name = "temperature_c")
    private Double temperatureC;

    @Column(name = "milk_l")
    private Double milkL;

    @Column(name = "feed_kg")
    private Double feedKg;

    @Column(name = "udder_swelling", nullable = false)
    private boolean udderSwelling;

    @Column(name = "abnormal_milk", nullable = false)
    private boolean abnormalMilk;

    @Column(name = "udder_pain", nullable = false)
    private boolean udderPain;

    @Column(nullable = false)
    private boolean lethargy;

    @Column(length = 500)
    private String notes;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(nullable = false)
    private boolean deleted;

    protected DailyRecord() {
    }

    public DailyRecord(UUID id, Instant createdAt) {
        this.id = id;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public void update(UUID cowId, LocalDate recordDate, Double temperatureC, Double milkL, Double feedKg,
            Symptoms symptoms, String notes, boolean deleted, Instant updatedAt) {
        this.cowId = cowId;
        this.recordDate = recordDate;
        this.temperatureC = temperatureC;
        this.milkL = milkL;
        this.feedKg = feedKg;
        this.udderSwelling = symptoms.udderSwelling();
        this.abnormalMilk = symptoms.abnormalMilk();
        this.udderPain = symptoms.udderPain();
        this.lethargy = symptoms.lethargy();
        this.notes = notes;
        this.deleted = deleted;
        this.updatedAt = updatedAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCowId() {
        return cowId;
    }

    public LocalDate getRecordDate() {
        return recordDate;
    }

    public Double getTemperatureC() {
        return temperatureC;
    }

    public Double getMilkL() {
        return milkL;
    }

    public Double getFeedKg() {
        return feedKg;
    }

    public Symptoms getSymptoms() {
        return new Symptoms(udderSwelling, abnormalMilk, udderPain, lethargy);
    }

    public String getNotes() {
        return notes;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
