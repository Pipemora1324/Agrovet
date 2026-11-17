package co.edu.ucc.agrovet.user;

import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import co.edu.ucc.agrovet.photo.CowPhotoRepository;
import co.edu.ucc.agrovet.photo.PhotoStorage;

/**
 * Borrado definitivo de una cuenta y de todo lo que le pertenece (derecho de supresión, Ley 1581 de
 * 2012). No es un borrado lógico: las filas desaparecen. El orden respeta las llaves foráneas.
 * Solo consultas parametrizadas.
 */
@Service
public class AccountDeletionService {

    private static final Logger log = LoggerFactory.getLogger(AccountDeletionService.class);

    /**
     * Borrado de lo que cuelga de las vacas, de lo más dependiente a lo menos. Cada sentencia está
     * escrita completa (sin armar el SQL con concatenación); el id va como parámetro.
     */
    private static final List<String> DELETE_COW_CHILDREN = List.of(
            "DELETE FROM alerts WHERE cow_id IN (SELECT id FROM cows WHERE owner_id = ?)",
            "DELETE FROM inferences WHERE cow_id IN (SELECT id FROM cows WHERE owner_id = ?)",
            "DELETE FROM daily_records WHERE cow_id IN (SELECT id FROM cows WHERE owner_id = ?)",
            "DELETE FROM cow_photos WHERE cow_id IN (SELECT id FROM cows WHERE owner_id = ?)");

    private final JdbcTemplate jdbc;
    private final CowPhotoRepository photos;
    private final PhotoStorage photoStorage;

    public AccountDeletionService(JdbcTemplate jdbc, CowPhotoRepository photos, PhotoStorage photoStorage) {
        this.jdbc = jdbc;
        this.photos = photos;
        this.photoStorage = photoStorage;
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void deleteEverything(UUID userId) {
        List<UUID> photoIds = photos.findIdsByOwner(userId);
        int rows = 0;
        for (String sql : DELETE_COW_CHILDREN) {
            rows += jdbc.update(sql, userId);
        }
        rows += jdbc.update("DELETE FROM cows WHERE owner_id = ?", userId);
        rows += jdbc.update("DELETE FROM refresh_tokens WHERE user_id = ?", userId);
        rows += jdbc.update("DELETE FROM email_codes WHERE user_id = ?", userId);
        rows += jdbc.update("DELETE FROM users WHERE id = ?", userId);
        log.info("Cuenta {} eliminada con todos sus datos ({} filas, {} fotos)", userId, rows, photoIds.size());
        // Los archivos se borran solo si la transacción se confirma
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                photoIds.forEach(photoStorage::delete);
            }
        });
    }
}
