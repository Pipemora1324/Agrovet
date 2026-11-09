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

    @Column(name = "udder_redness", nullable = false)
    private boolean udderRedness;

    @Column(name = "udder_heat", nullable = false)
    private boolean udderHeat;

    @Column(name = "ate_normally")
    private Boolean ateNormally;

    @Column(name = "milk_drop")
    private Boolean milkDrop;

    @Column(name = "temperature_source", length = 10)
    private String temperatureSource;

    @Column(name = "milk_source", length = 10)
    private String milkSource;

    @Column(name = "feed_source", length = 10)
    private String feedSource;

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
            Symptoms symptoms, ValueSources sources, String notes, boolean deleted, Instant updatedAt) {
        this.temperatureSource = sources.temperature();
        this.milkSource = sources.milk();
        this.feedSource = sources.feed();
        this.cowId = cowId;
        this.recordDate = recordDate;
        this.temperatureC = temperatureC;
        this.milkL = milkL;
        this.feedKg = feedKg;
        this.udderSwelling = symptoms.udderSwelling();
        this.abnormalMilk = symptoms.abnormalMilk();
        this.udderPain = symptoms.udderPain();
        this.lethargy = symptoms.lethargy();
        this.udderRedness = symptoms.udderRedness();
        this.udderHeat = symptoms.udderHeat();
        this.ateNormally = symptoms.ateNormally();
        this.milkDrop = symptoms.milkDrop();
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
        return new Symptoms(udderSwelling, abnormalMilk, udderPain, lethargy, udderRedness, udderHeat, ateNormally,
                milkDrop);
    }

    public ValueSources getSources() {
        return new ValueSources(temperatureSource, milkSource, feedSource);
    }

    public String getNotes() {
        return notes;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
