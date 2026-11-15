"""Resumen de cobertura de los tres módulos en una tabla Markdown.

Lee los informes que dejan las pruebas y escribe la tabla en la salida estándar. Se usa en el
resumen del job de GitHub Actions y en el comentario del pull request.

    python scripts/ci/coverage_summary.py \
        --jacoco backend/target/site/jacoco/jacoco.csv \
        --cobertura ml/coverage.xml \
        --lcov mobile/coverage/lcov.info

Un informe que falta aparece como "sin informe" en vez de detener el script.
"""

from __future__ import annotations

import argparse
import csv
import io
import sys
import xml.etree.ElementTree as ET
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

MARKER = "<!-- agrovet-coverage -->"


@dataclass(frozen=True)
class Coverage:
    lines_covered: int
    lines_total: int
    branches_covered: int
    branches_total: int


def jacoco(path: Path) -> Coverage:
    rows = list(csv.DictReader(path.open(encoding="utf-8")))

    def total(column: str) -> int:
        return sum(int(row[column]) for row in rows)

    return Coverage(total("LINE_COVERED"), total("LINE_COVERED") + total("LINE_MISSED"),
                    total("BRANCH_COVERED"), total("BRANCH_COVERED") + total("BRANCH_MISSED"))


def cobertura(path: Path) -> Coverage:
    root = ET.parse(path).getroot()
    return Coverage(int(root.get("lines-covered", 0)), int(root.get("lines-valid", 0)),
                    int(root.get("branches-covered", 0)), int(root.get("branches-valid", 0)))


def lcov(path: Path, exclude_suffix: str = ".g.dart") -> Coverage:
    lf = lh = brf = brh = 0
    skip = False
    for raw in path.open(encoding="utf-8"):
        line = raw.strip()
        if line.startswith("SF:"):
            # El código que genera Drift no se escribe a mano: no cuenta para la cobertura
            skip = line.endswith(exclude_suffix)
        elif skip:
            continue
        elif line.startswith("LF:"):
            lf += int(line[3:])
        elif line.startswith("LH:"):
            lh += int(line[3:])
        elif line.startswith("BRF:"):
            brf += int(line[4:])
        elif line.startswith("BRH:"):
            brh += int(line[4:])
    return Coverage(lh, lf, brh, brf)


def percent(covered: int, total: int) -> str:
    return "—" if total == 0 else f"{100 * covered / total:.1f} % ({covered}/{total})"


def table(results: dict[str, Coverage | None]) -> str:
    lines = [MARKER, "### Cobertura de pruebas", "", "| Módulo | Líneas | Ramas |", "|---|---|---|"]
    for name, cov in results.items():
        if cov is None:
            lines.append(f"| {name} | sin informe | sin informe |")
        else:
            lines.append(f"| {name} | {percent(cov.lines_covered, cov.lines_total)} | "
                         f"{percent(cov.branches_covered, cov.branches_total)} |")
    note = ("Backend con JaCoCo, ml con pytest-cov y mobile con `flutter test --coverage` "
            "(sin el código generado `*.g.dart`). Flutter no mide ramas.")
    lines += ["", note]
    return "\n".join(lines) + "\n"


def load(reader: Callable[[Path], Coverage], path: str | None) -> Coverage | None:
    if not path or not Path(path).is_file():
        return None
    return reader(Path(path))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--jacoco")
    parser.add_argument("--cobertura")
    parser.add_argument("--lcov")
    args = parser.parse_args()
    # Solo aparecen los módulos que se pidieron; el que se pidió y no tiene informe sale como tal
    requested = {
        "backend (Java)": (jacoco, args.jacoco),
        "ml (Python)": (cobertura, args.cobertura),
        "mobile (Dart)": (lcov, args.lcov),
    }
    results = {name: load(reader, path) for name, (reader, path) in requested.items() if path is not None}
    if isinstance(sys.stdout, io.TextIOWrapper):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.stdout.write(table(results))


if __name__ == "__main__":
    main()
