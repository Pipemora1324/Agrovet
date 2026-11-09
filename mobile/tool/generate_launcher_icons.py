"""Genera el ícono de AgroVet y la imagen de la pantalla de arranque para Android.

El dibujo es el mismo logo de la app: el ícono "health_and_safety" de Material Icons (licencia
Apache 2.0, incluida en el SDK de Flutter) en blanco sobre el verde del tema (AppColors.primary).

Uso (requiere Pillow):
    python tool/generate_launcher_icons.py --flutter C:/src/flutter
Escribe en android/app/src/main/res/.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

GREEN = (0x1F, 0x6B, 0x45, 255)
WHITE = (255, 255, 255, 255)
GLYPH = chr(0xE305)  # Icons.health_and_safety
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
RES = Path(__file__).resolve().parents[1] / "android" / "app" / "src" / "main" / "res"


def glyph_layer(font_path, canvas, em):
    """Glifo blanco centrado en un lienzo transparente de canvas x canvas píxeles."""
    image = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    font = ImageFont.truetype(str(font_path), em)
    draw = ImageDraw.Draw(image)
    left, top, right, bottom = draw.textbbox((0, 0), GLYPH, font=font)
    x = (canvas - (right - left)) / 2 - left
    y = (canvas - (bottom - top)) / 2 - top
    draw.text((x, y), GLYPH, font=font, fill=WHITE)
    return image


def main():
    parser = argparse.ArgumentParser(description="Ícono y pantalla de arranque de AgroVet.")
    parser.add_argument("--flutter", type=Path, required=True, help="Carpeta del SDK de Flutter")
    args = parser.parse_args()
    font = args.flutter / "bin" / "cache" / "artifacts" / "material_fonts" / "materialicons-regular.otf"

    for name, scale in DENSITIES.items():
        mipmap = RES / f"mipmap-{name}"
        drawable = RES / f"drawable-{name}"
        mipmap.mkdir(exist_ok=True)
        drawable.mkdir(exist_ok=True)

        # Ícono adaptativo: lienzo de 108 dp; el glifo (64 dp de em) queda dentro de la zona segura de 66 dp
        side = round(108 * scale)
        glyph_layer(font, side, round(64 * scale)).save(mipmap / "ic_launcher_foreground.png")

        # Ícono clásico (Android 7): círculo verde de 44 dp en 48 dp con el glifo blanco
        side = round(48 * scale)
        legacy = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        margin = round(2 * scale)
        ImageDraw.Draw(legacy).ellipse((margin, margin, side - margin, side - margin), fill=GREEN)
        legacy.alpha_composite(glyph_layer(font, side, round(30 * scale)))
        legacy.save(mipmap / "ic_launcher.png")
        legacy.save(mipmap / "ic_launcher_round.png")

        # Pantalla de arranque de Android 12+: lienzo de 288 dp; el ícono debe caber en un círculo de 192 dp
        side = round(288 * scale)
        glyph_layer(font, side, round(150 * scale)).save(drawable / "splash_icon.png")
    print(f"Listo: {RES}")


if __name__ == "__main__":
    main()
