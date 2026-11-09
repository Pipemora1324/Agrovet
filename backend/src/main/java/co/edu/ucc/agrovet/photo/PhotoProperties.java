package co.edu.ucc.agrovet.photo;

import java.nio.file.Path;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.util.unit.DataSize;

/**
 * @param storageDir   carpeta donde se guardan los archivos (variable PHOTO_STORAGE_DIR)
 * @param maxSize      tamaño máximo del archivo recibido
 * @param maxDimension lado máximo en píxeles; se revisa antes de decodificar para no agotar memoria
 */
@ConfigurationProperties("agrovet.photos")
public record PhotoProperties(Path storageDir, DataSize maxSize, int maxDimension) {
}
