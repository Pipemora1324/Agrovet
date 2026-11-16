"""requirements.lock y requirements-mutmut.lock tienen que coincidir con requirements.txt.

El CI instala desde los .lock (todas las dependencias fijadas por hash, solo wheels). Si Dependabot o
alguien cambia una versión en requirements.txt sin regenerarlos, esta prueba falla. Cómo regenerarlos:
ml/README.md, sección "Dependencias fijadas por hash".
"""

import re
from pathlib import Path

import pytest

ML_DIR = Path(__file__).resolve().parents[1]
PIN = re.compile(r"^([A-Za-z0-9_.\-]+)==([^\s\\;]+)", re.MULTILINE)
MUTMUT_PACKAGES = {"numpy", "pandas", "scikit-learn", "pytest", "mutmut"}


def pins(name):
    text = (ML_DIR / name).read_text(encoding="utf-8")
    return {package.lower(): version for package, version in PIN.findall(text)}


def test_pin_parser():
    text = "numpy==2.5.4 \\\n    --hash=sha256:abc\npandas-stubs==3.1.0.261029\n# via x\n"
    assert {p.lower(): v for p, v in PIN.findall(text)} == {"numpy": "2.5.4", "pandas-stubs": "3.1.0.261029"}


@pytest.mark.parametrize(("lock", "packages"), [
    ("requirements.lock", None),
    ("requirements-mutmut.lock", MUTMUT_PACKAGES),
])
def test_lock_matches_requirements(lock, packages):
    required = pins("requirements.txt")
    if packages is not None:
        required = {p: v for p, v in required.items() if p in packages}
    locked = pins(lock)
    assert required, "requirements.txt sin versiones fijas"
    assert {p: locked.get(p) for p in required} == required


@pytest.mark.parametrize("lock", ["requirements.lock", "requirements-mutmut.lock"])
def test_every_locked_package_has_hashes_and_no_local_paths(lock):
    text = (ML_DIR / lock).read_text(encoding="utf-8")
    entries = re.split(r"\n(?=[A-Za-z0-9_.\-]+==)", text.strip())
    assert len(entries) == len(PIN.findall(text))
    assert all("--hash=sha256:" in entry for entry in entries)
    assert ":\\" not in text
    assert "C:/" not in text
