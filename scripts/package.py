#!/usr/bin/env python3
"""Créer une archive des sources sans données métier, secrets ni dépendances générées."""
import argparse
import hashlib
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=root.parent / "First-Bricks.zip")
args = parser.parse_args()
entries = ["mix.exs", "mix.lock", "README.md", "VALIDATION.md", "Dockerfile",
           "docker-entrypoint.sh", "railway.toml", ".gitignore", ".dockerignore",
           ".formatter.exs", ".gitattributes", "compose.yaml", "Demarrer-First-Bricks.cmd", "WINDOWS.md", "config", "lib", "priv", "test", "examples", "scripts"]
files = []
for entry in entries:
    source = root / entry
    if source.is_dir():
        files.extend(p for p in source.rglob("*") if p.is_file()
                     and "__pycache__" not in p.parts and p.suffix != ".pyc")
    else:
        files.append(source)
with ZipFile(args.output, "w", ZIP_DEFLATED) as archive:
    for path in sorted(files):
        archive.write(path, Path("First-Bricks") / path.relative_to(root))
with ZipFile(args.output) as archive:
    assert archive.testzip() is None
    assert all(".dets" not in name and "/.env" not in name and "/.git/" not in name for name in archive.namelist())
digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
args.output.with_suffix(args.output.suffix + ".sha256").write_text(digest + "  " + args.output.name + "\n")
print(f"{args.output} : {len(files)} fichiers, {args.output.stat().st_size} octets, archive vérifiée.")
