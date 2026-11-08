package co.edu.ucc.agrovet.photo;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;

import org.springframework.stereotype.Component;

import co.edu.ucc.agrovet.common.BadRequestException;

/**
 * Valida y limpia una foto recibida.
 * <ul>
 * <li>El tipo se decide por los primeros bytes del archivo (JPEG o PNG), no por el nombre ni por el
 * Content-Type que manda el cliente.</li>
 * <li>Las dimensiones se leen del encabezado antes de decodificar, para rechazar imágenes enormes.</li>
 * <li>La imagen se decodifica y se vuelve a codificar como JPEG: en el archivo guardado no queda
 * ningún metadato (EXIF con la ubicación, XMP, comentarios) ni contenido extra escondido.</li>
 * </ul>
 */
@Component
public class PhotoProcessor {

    static final String NOT_AN_IMAGE = "El archivo no es una foto JPEG o PNG.";
    private static final float JPEG_QUALITY = 0.85f;

    private final PhotoProperties properties;

    public PhotoProcessor(PhotoProperties properties) {
        this.properties = properties;
    }

    /** Devuelve la foto como JPEG sin metadatos, o lanza BadRequestException con el motivo. */
    public byte[] clean(byte[] input) {
        if (input.length == 0) {
            throw new BadRequestException("El archivo está vacío.");
        }
        if (input.length > properties.maxSize().toBytes()) {
            throw new BadRequestException("La foto pesa más de " + properties.maxSize().toMegabytes() + " MB.");
        }
        String format = detectFormat(input);
        if (format == null) {
            throw new BadRequestException(NOT_AN_IMAGE);
        }
        BufferedImage image = decode(input, format);
        return encodeJpeg(toRgb(image));
    }

    /** "jpeg" o "png" según la firma del archivo; null si no es ninguna. */
    static String detectFormat(byte[] bytes) {
        if (bytes.length >= 3 && (bytes[0] & 0xFF) == 0xFF && (bytes[1] & 0xFF) == 0xD8 && (bytes[2] & 0xFF) == 0xFF) {
            return "jpeg";
        }
        byte[] png = { (byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n' };
        if (bytes.length >= png.length) {
            for (int i = 0; i < png.length; i++) {
                if (bytes[i] != png[i]) {
                    return null;
                }
            }
            return "png";
        }
        return null;
    }

    private BufferedImage decode(byte[] input, String format) {
        try (ImageInputStream stream = ImageIO.createImageInputStream(new ByteArrayInputStream(input))) {
            Iterator<ImageReader> readers = ImageIO.getImageReadersByFormatName(format);
            if (!readers.hasNext()) {
                throw new BadRequestException(NOT_AN_IMAGE);
            }
            ImageReader reader = readers.next();
            try {
                reader.setInput(stream, true, true);
                int width = reader.getWidth(0);
                int height = reader.getHeight(0);
                if (width > properties.maxDimension() || height > properties.maxDimension()) {
                    throw new BadRequestException("La foto es demasiado grande (máximo "
                            + properties.maxDimension() + " píxeles por lado).");
                }
                return reader.read(0);
            } finally {
                reader.dispose();
            }
        } catch (IOException | RuntimeException e) {
            if (e instanceof BadRequestException bad) {
                throw bad;
            }
            throw new BadRequestException("La foto está dañada o no se puede leer.");
        }
    }

    /** JPEG no admite transparencia: se pasa a RGB sobre fondo blanco. */
    private static BufferedImage toRgb(BufferedImage image) {
        if (image.getType() == BufferedImage.TYPE_INT_RGB) {
            return image;
        }
        BufferedImage rgb = new BufferedImage(image.getWidth(), image.getHeight(), BufferedImage.TYPE_INT_RGB);
        var graphics = rgb.createGraphics();
        graphics.drawImage(image, 0, 0, java.awt.Color.WHITE, null);
        graphics.dispose();
        return rgb;
    }

    private static byte[] encodeJpeg(BufferedImage image) {
        ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (ImageOutputStream stream = ImageIO.createImageOutputStream(out)) {
            writer.setOutput(stream);
            ImageWriteParam param = writer.getDefaultWriteParam();
            param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            param.setCompressionQuality(JPEG_QUALITY);
            // Sin metadatos de entrada: solo se escriben los píxeles
            writer.write(null, new IIOImage(image, null, null), param);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo codificar la foto", e);
        } finally {
            writer.dispose();
        }
        return out.toByteArray();
    }
}
