"""Más casos del armado del dataset de fotos: conteos, filas inválidas seguidas de válidas,
repetir la corrida y la línea de comandos."""

import csv
import json
import sys
import uuid

import pytest

import build_cnn_dataset
from build_cnn_dataset import build_dataset, eligible, main

FIELDS = ["id", "vet_confirmed", "diagnosis", "research_consent", "deleted", "stored"]


def write_manifest(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def row(photo_id, diagnosis="MASTITIS", consent="t"):
    return {"id": photo_id, "vet_confirmed": "YES", "diagnosis": diagnosis, "research_consent": consent,
            "deleted": "f", "stored": "t"}


@pytest.fixture
def photos(tmp_path):
    folder = tmp_path / "fotos"
    folder.mkdir()
    return folder


def add_photo(folder):
    photo_id = str(uuid.uuid4())
    (folder / f"{photo_id}.jpg").write_bytes(b"\xff\xd8\xff" + photo_id.encode())
    return photo_id


def test_yes_is_accepted_as_consent():
    assert eligible(row("x", consent="yes")) == "mastitis"
    assert eligible(row("x", consent=" YES ")) == "mastitis"


def test_counts_add_up_and_bad_rows_do_not_stop_the_rest(tmp_path, photos):
    good = [add_photo(photos) for _ in range(3)]
    rows = [
        row("../../etc/passwd"),          # id inválido...
        row("no-es-un-uuid"),
        row(str(uuid.uuid4())),           # ...archivo que no existe...
        row(str(uuid.uuid4())),
        row(good[0]),                     # ...y después las válidas igual entran
        row(good[1]),
        row(good[2], diagnosis="HEALTHY"),
    ]
    write_manifest(tmp_path / "fotos.csv", rows)

    summary = build_dataset(tmp_path / "fotos.csv", photos, tmp_path / "out")

    assert summary == {
        "images": {"healthy": 1, "mastitis": 2},
        "skipped": {"sin_permiso_o_sin_confirmar": 0, "archivo_faltante": 2, "id_invalido": 2},
        "total_rows": 7,
    }
    written = (tmp_path / "out" / "dataset_summary.json").read_text(encoding="utf-8")
    assert written == json.dumps(summary, indent=2)


def test_running_twice_on_the_same_folder_works(tmp_path, photos):
    write_manifest(tmp_path / "fotos.csv", [row(add_photo(photos))])
    build_dataset(tmp_path / "fotos.csv", photos, tmp_path / "out")
    summary = build_dataset(tmp_path / "fotos.csv", photos, tmp_path / "out")
    assert summary["images"]["mastitis"] == 1


def test_command_line_builds_and_prints_the_summary(tmp_path, photos, monkeypatch, capsys):
    write_manifest(tmp_path / "fotos.csv", [row(add_photo(photos))])
    # Sin --out se usa la carpeta por defecto (aquí, una temporal)
    monkeypatch.setattr(build_cnn_dataset, "DEFAULT_OUT", tmp_path / "por_defecto")
    monkeypatch.setattr(sys, "argv", ["build_cnn_dataset.py", "--manifest", str(tmp_path / "fotos.csv"),
                                      "--photos", str(photos)])

    assert main() == 0

    printed = capsys.readouterr().out
    summary = json.loads(printed)
    assert printed == json.dumps(summary, indent=2, ensure_ascii=False) + "\n"
    assert summary["images"] == {"healthy": 0, "mastitis": 1}
    assert len(list((tmp_path / "por_defecto" / "mastitis").iterdir())) == 1


def test_command_line_with_explicit_output(tmp_path, photos, monkeypatch, capsys):
    write_manifest(tmp_path / "fotos.csv", [row(add_photo(photos), diagnosis="HEALTHY")])
    monkeypatch.setattr(sys, "argv", ["build_cnn_dataset.py", "--manifest", str(tmp_path / "fotos.csv"),
                                      "--photos", str(photos), "--out", str(tmp_path / "salida")])

    assert main() == 0
    assert len(list((tmp_path / "salida" / "healthy").iterdir())) == 1


def test_help_explains_the_consent_filter(monkeypatch, capsys):
    monkeypatch.setattr(sys, "argv", ["build_cnn_dataset.py", "--help"])
    with pytest.raises(SystemExit):
        main()
    assert "Arma el conjunto de la CNN solo con fotos consentidas y confirmadas." in capsys.readouterr().out


@pytest.mark.parametrize("missing", ["--manifest", "--photos"])
def test_command_line_requires_manifest_and_photos(tmp_path, monkeypatch, missing):
    args = {"--manifest": str(tmp_path / "fotos.csv"), "--photos": str(tmp_path)}
    del args[missing]
    monkeypatch.setattr(sys, "argv", ["build_cnn_dataset.py", *[x for pair in args.items() for x in pair]])
    with pytest.raises(SystemExit) as error:
        main()
    assert error.value.code == 2
