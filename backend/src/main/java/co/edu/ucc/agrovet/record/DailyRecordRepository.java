package co.edu.ucc.agrovet.record;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface DailyRecordRepository extends JpaRepository<DailyRecord, UUID> {

    List<DailyRecord> findAllByCowIdAndDeletedFalseAndRecordDateBetweenOrderByRecordDateAsc(UUID cowId,
            LocalDate from, LocalDate to);

    boolean existsByCowIdAndRecordDateAndDeletedFalseAndIdNot(UUID cowId, LocalDate recordDate, UUID id);
}
