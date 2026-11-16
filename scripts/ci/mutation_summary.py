"""Resumen de las pruebas de mutación (PIT en el backend, mutmut en ml) en Markdown.

    python scripts/ci/mutation_summary.py --pit backend/target/pit-reports/mutations.xml
    mutmut results --all true | python scripts/ci/mutation_summary.py --mutmut --min 90

Los resultados de mutmut se leen de la entrada estándar: así ningún argumento se usa como ruta.
Con --min el script termina con código 1 si el porcentaje de mutantes eliminados queda por debajo.
"""

from __future__ import annotations

import argparse
import io
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from collections.abc import Iterable
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


def mutmut(lines: Iterable[str]) -> tuple[Counter[str], Counter[str]]:
    """Líneas de `mutmut results --all true`: "nombre.del.mutante: estado"."""
    per_module: Counter[str] = Counter()
    statuses: Counter[str] = Counter()
    for raw in lines:
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


def report_path(value: str) -> Path:
    """Ruta de un informe: tiene que ser un archivo dentro del directorio de trabajo (el repositorio en
    el CI). Evita leer archivos de otra parte del sistema con una ruta como ../../etc/passwd."""
    base = Path.cwd().resolve()
    path = (base / value).resolve()
    if not path.is_relative_to(base):
        raise argparse.ArgumentTypeError(f"el informe tiene que estar dentro de {base}: {value}")
    if not path.is_file():
        raise argparse.ArgumentTypeError(f"no existe el informe: {value}")
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--pit", type=report_path)
    parser.add_argument("--mutmut", action="store_true",
                        help="lee de la entrada estándar la salida de `mutmut results --all true`")
    parser.add_argument("--min", type=float, default=0.0, help="porcentaje mínimo de mutantes eliminados")
    args = parser.parse_args()

    parts, scores = ["### Pruebas de mutación", ""], []
    if args.pit:
        statuses, alive = pit(args.pit)
        text, pct = section("Backend: PIT (auth y sync)", statuses, PIT_KILLED, alive)
        parts.append(text)
        scores.append(pct)
    if args.mutmut:
        if isinstance(sys.stdin, io.TextIOWrapper):
            sys.stdin.reconfigure(encoding="utf-8")
        statuses, alive = mutmut(sys.stdin)
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
