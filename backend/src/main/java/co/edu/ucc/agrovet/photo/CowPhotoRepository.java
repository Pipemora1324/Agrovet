package co.edu.ucc.agrovet.photo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CowPhotoRepository extends JpaRepository<CowPhoto, UUID> {

    /** Ids de todas las fotos de un dueño (para borrar sus archivos al eliminar la cuenta). */
    @Query("SELECT p.id FROM CowPhoto p WHERE p.cowId IN (SELECT c.id FROM Cow c WHERE c.ownerId = :ownerId)")
    List<UUID> findIdsByOwner(@Param("ownerId") UUID ownerId);
}
