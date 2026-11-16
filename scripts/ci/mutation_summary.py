"""Resumen de las pruebas de mutación (PIT en el backend, mutmut en ml) en Markdown.

    python scripts/ci/mutation_summary.py --pit backend/target/pit-reports/mutations.xml
    mutmut results --all true > mutmut.txt
    python scripts/ci/mutation_summary.py --mutmut mutmut.txt --min 90

Con --min el script termina con código 1 si el porcentaje de mutantes eliminados queda por debajo.
"""

from __future__ import annotations

import argparse
import io
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

# Estados que cuentan como mutante eliminado
PIT_KILLED = {"KILLED", "TIMED_OUT", "MEMORY_ERROR"}
MUTMUT_KILLED = {"killed", "timeout", "segfault"}
# No son mutantes válidos: no entran en el porcentaje
MUTMUT_IGNORED = {"skipped", "not checked", "check was interrupted by user"}


def pit(path: Path) -> tuple[Counter[str], Counter[str]]:
    per_class: Counter[str] = Counter()
    statuses: Counter[str] = Counter()
    for mutation in ET.parse(path).getroot().iter("mutation"):
        status = mutation.get("status", "")
        statuses[status] += 1
        if status not in PIT_KILLED:
            per_class[mutation.findtext("mutatedClass", "").rsplit(".", 1)[-1]] += 1
    return statuses, per_class


def mutmut(path: Path) -> tuple[Counter[str], Counter[str]]:
    per_module: Counter[str] = Counter()
    statuses: Counter[str] = Counter()
    for raw in path.read_text(encoding="utf-8").splitlines():
        name, sep, status = raw.strip().rpartition(": ")
        if not sep or status in MUTMUT_IGNORED:
            continue
        statuses[status] += 1
        if status not in MUTMUT_KILLED:
            per_module[name.split(".", 1)[0]] += 1
    return statuses, per_module


def score(statuses: Counter[str], killed: set[str]) -> tuple[int, int, float]:
    total = sum(statuses.values())
    dead = sum(n for status, n in statuses.items() if status in killed)
    return dead, total, (100 * dead / total if total else 0.0)


def section(title: str, statuses: Counter[str], killed: set[str], alive: Counter[str]) -> tuple[str, float]:
    dead, total, pct = score(statuses, killed)
    lines = [f"#### {title}", "", f"**{pct:.1f} %** de mutantes eliminados ({dead}/{total}).", "",
             "| Estado | Mutantes |", "|---|---|"]
    lines += [f"| {status} | {n} |" for status, n in sorted(statuses.items())]
    if alive:
        lines += ["", "Sobreviven en: " + ", ".join(f"`{name}` ({n})" for name, n in alive.most_common())]
    return "\n".join(lines) + "\n", pct


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--pit", type=Path)
    parser.add_argument("--mutmut", type=Path)
    parser.add_argument("--min", type=float, default=0.0, help="porcentaje mínimo de mutantes eliminados")
    args = parser.parse_args()

    parts, scores = ["### Pruebas de mutación", ""], []
    if args.pit:
        statuses, alive = pit(args.pit)
        text, pct = section("Backend: PIT (auth y sync)", statuses, PIT_KILLED, alive)
        parts.append(text)
        scores.append(pct)
    if args.mutmut:
        statuses, alive = mutmut(args.mutmut)
        text, pct = section("ml: mutmut (módulos en [tool.mutmut] de ml/pyproject.toml)", statuses,
                            MUTMUT_KILLED, alive)
        parts.append(text)
        scores.append(pct)
    if isinstance(sys.stdout, io.TextIOWrapper):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.stdout.write("\n".join(parts))
    if any(pct < args.min for pct in scores):
        sys.stderr.write(f"El porcentaje de mutantes eliminados quedó por debajo de {args.min} %.\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
