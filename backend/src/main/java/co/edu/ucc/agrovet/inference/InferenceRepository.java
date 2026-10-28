package co.edu.ucc.agrovet.inference;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

public interface InferenceRepository extends JpaRepository<Inference, UUID> {

    List<Inference> findAllByCowIdAndDeletedFalseAndWindowEndDateBetweenOrderByWindowEndDateAsc(UUID cowId,
            LocalDate from, LocalDate to);
}
