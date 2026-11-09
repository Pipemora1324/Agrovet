package co.edu.ucc.agrovet.photo;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.file.Path;

import org.junit.jupiter.api.Test;
import org.springframework.util.unit.DataSize;

import co.edu.ucc.agrovet.common.BadRequestException;

class PhotoProcessorTest {

    private final PhotoProcessor processor =
            new PhotoProcessor(new PhotoProperties(Path.of("no-se-usa"), DataSize.ofMegabytes(5), 100));

    @Test
    void imagesLargerThanTheLimitAreRejectedBeforeDecoding() throws Exception {
        assertThatThrownBy(() -> processor.clean(co.edu.ucc.agrovet.TestImages.image("png", 101, 10)))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("100 píxeles");
        assertThat(processor.clean(co.edu.ucc.agrovet.TestImages.image("png", 100, 100))).isNotEmpty();
    }

    @Test
    void formatIsDetectedFromTheFirstBytes() {
        assertThat(PhotoProcessor.detectFormat(new byte[] { (byte) 0xFF, (byte) 0xD8, (byte) 0xFF })).isEqualTo("jpeg");
        assertThat(PhotoProcessor.detectFormat("GIF89a".getBytes())).isNull();
        assertThatThrownBy(() -> processor.clean(new byte[0])).hasMessage("El archivo está vacío.");
    }
}
