import csv
import json
import uuid

import pytest

from build_cnn_dataset import build_dataset, eligible


def write_manifest(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["id", "vet_confirmed", "diagnosis", "research_consent",
                                                    "deleted", "stored"])
        writer.writeheader()
        writer.writerows(rows)


def row(photo_id, consent="t", vet="YES", diagnosis="MASTITIS", deleted="f", stored="t"):
    return {"id": photo_id, "vet_confirmed": vet, "diagnosis": diagnosis, "research_consent": consent,
            "deleted": deleted, "stored": stored}


def test_only_consented_and_vet_confirmed_photos_enter(tmp_path):
    photos = tmp_path / "fotos"
    photos.mkdir()
    ids = [str(uuid.uuid4()) for _ in range(8)]
    for photo_id in ids:
        (photos / f"{photo_id}.jpg").write_bytes(b"\xff\xd8\xff" + photo_id.encode())
    rows = [
        row(ids[0]),                                  # entra: mastitis
        row(ids[1], diagnosis="HEALTHY"),             # entra: sana
        row(ids[2], consent="f"),                     # sin permiso
        row(ids[3], vet="PENDING"),                   # sin confirmar
        row(ids[4], vet="NO"),                        # no la confirmó un veterinario
        row(ids[5], diagnosis="OTHER"),               # sin clase clara
        row(ids[6], deleted="t"),                     # borrada
        row(ids[7], stored="f"),                      # el archivo no se subió
    ]
    write_manifest(tmp_path / "fotos.csv", rows)

    summary = build_dataset(tmp_path / "fotos.csv", photos, tmp_path / "salida")

    assert summary["images"] == {"healthy": 1, "mastitis": 1}
    assert summary["skipped"]["sin_permiso_o_sin_confirmar"] == 6
    assert [p.name for p in (tmp_path / "salida" / "mastitis").iterdir()] == [f"{ids[0]}.jpg"]
    assert [p.name for p in (tmp_path / "salida" / "healthy").iterdir()] == [f"{ids[1]}.jpg"]
    saved = json.loads((tmp_path / "salida" / "dataset_summary.json").read_text(encoding="utf-8"))
    assert saved["total_rows"] == 8


def test_ids_that_could_escape_the_folder_are_ignored(tmp_path):
    photos = tmp_path / "fotos"
    photos.mkdir()
    write_manifest(tmp_path / "fotos.csv", [row("../../etc/passwd")])
    summary = build_dataset(tmp_path / "fotos.csv", photos, tmp_path / "salida")
    assert summary["skipped"]["id_invalido"] == 1
    assert summary["images"] == {"healthy": 0, "mastitis": 0}


def test_missing_files_are_counted_not_invented(tmp_path):
    photos = tmp_path / "fotos"
    photos.mkdir()
    write_manifest(tmp_path / "fotos.csv", [row(str(uuid.uuid4()))])
    summary = build_dataset(tmp_path / "fotos.csv", photos, tmp_path / "salida")
    assert summary["skipped"]["archivo_faltante"] == 1


def test_manifest_without_required_columns_fails(tmp_path):
    (tmp_path / "fotos.csv").write_text("id,diagnosis\nx,MASTITIS\n", encoding="utf-8")
    with pytest.raises(ValueError, match="faltan columnas"):
        build_dataset(tmp_path / "fotos.csv", tmp_path, tmp_path / "salida")


def test_eligibility_accepts_postgres_and_plain_booleans():
    assert eligible(row("x", consent="true", stored="1")) == "mastitis"
    assert eligible(row("x", vet="yes", diagnosis="healthy")) == "healthy"
    assert eligible(row("x", consent="false")) is None
