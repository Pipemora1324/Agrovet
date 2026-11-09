"""Arma el conjunto de entrenamiento de la CNN con las fotos que los ganaderos permitieron usar.

Solo entra una foto si cumple TODO esto:
  - research_consent = true (el ganadero activó "Permitir usar esta foto para investigación"),
  - vet_confirmed = YES (un veterinario confirmó el diagnóstico),
  - diagnosis = MASTITIS o HEALTHY (los "OTHER" no tienen una clase clara),
  - no está borrada y su archivo ya se subió (stored = true).

Entrada:
  --manifest  CSV exportado de PostgreSQL con la consulta de abajo (no se versiona: tiene datos reales).
  --photos    carpeta de fotos del backend (PHOTO_STORAGE_DIR); cada archivo es <id>.jpg.
Salida (--out): healthy/ y mastitis/ con las fotos copiadas, nombradas solo con el id de la foto
(sin datos del ganadero), y dataset_summary.json con los conteos.

Consulta para el manifiesto (desde la carpeta backend/):
  docker compose exec -T db psql -U agrovet -d agrovet -c "\\copy (SELECT id, vet_confirmed, diagnosis,
    research_consent, deleted, stored FROM cow_photos) TO STDOUT CSV HEADER" > fotos.csv

El script vuelve a aplicar los filtros aunque el CSV venga sin filtrar.
"""

import argparse
import csv
import json
import re
import shutil
from pathlib import Path

ML_DIR = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ML_DIR / "data" / "udder_images"
LABELS = {"MASTITIS": "mastitis", "HEALTHY": "healthy"}
REQUIRED_COLUMNS = {"id", "vet_confirmed", "diagnosis", "research_consent", "deleted", "stored"}
UUID_PATTERN = re.compile(r"^[0-9a-fA-F-]{36}$")


def is_true(value):
    return str(value).strip().lower() in {"t", "true", "1", "yes"}


def eligible(row):
    """Etiqueta ("healthy" o "mastitis") si la foto se puede usar; None si no."""
    if not is_true(row["research_consent"]) or is_true(row["deleted"]) or not is_true(row["stored"]):
        return None
    if row["vet_confirmed"].strip().upper() != "YES":
        return None
    return LABELS.get(row["diagnosis"].strip().upper())


def build_dataset(manifest, photos_dir, out_dir):
    with open(manifest, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = REQUIRED_COLUMNS - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Al manifiesto le faltan columnas: {sorted(missing)}")
        rows = list(reader)

    counts = {"healthy": 0, "mastitis": 0}
    skipped = {"sin_permiso_o_sin_confirmar": 0, "archivo_faltante": 0, "id_invalido": 0}
    for name in counts:
        (out_dir / name).mkdir(parents=True, exist_ok=True)
    for row in rows:
        label = eligible(row)
        if label is None:
            skipped["sin_permiso_o_sin_confirmar"] += 1
            continue
        photo_id = row["id"].strip()
        # El id va al nombre del archivo: se valida para no salir de la carpeta
        if not UUID_PATTERN.match(photo_id):
            skipped["id_invalido"] += 1
            continue
        source = photos_dir / f"{photo_id}.jpg"
        if not source.exists():
            skipped["archivo_faltante"] += 1
            continue
        shutil.copyfile(source, out_dir / label / f"{photo_id}.jpg")
        counts[label] += 1

    summary = {"images": counts, "skipped": skipped, "total_rows": len(rows)}
    (out_dir / "dataset_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary


def main():
    parser = argparse.ArgumentParser(
        description="Arma el conjunto de la CNN solo con fotos consentidas y confirmadas.")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--photos", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    summary = build_dataset(args.manifest, args.photos, args.out)
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
