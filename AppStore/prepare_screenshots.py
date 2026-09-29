#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

directory = Path(sys.argv[1])
expected = tuple(map(int, sys.argv[2].split("x")))
names = ("01-development", "02-color", "03-creative", "04-beauty", "05-exif")

for name in names:
    path = directory / f"{name}.png"
    if not path.exists():
        raise SystemExit(f"Missing screenshot: {path}")
    opaque = directory / f".{name}-opaque.png"
    subprocess.run(["magick", str(path), "-alpha", "off", f"PNG24:{opaque}"], check=True)
    opaque.replace(path)
    metadata = subprocess.check_output(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(path)],
        text=True,
    )
    width = int(next(line.split(":", 1)[1] for line in metadata.splitlines() if "pixelWidth:" in line))
    height = int(next(line.split(":", 1)[1] for line in metadata.splitlines() if "pixelHeight:" in line))
    if (width, height) != expected:
        raise SystemExit(f"{path.name}: expected {expected}, found {(width, height)}")
    if "hasAlpha: yes" in metadata:
        raise SystemExit(f"{path.name}: screenshot contains an alpha channel")

print(f"Validated {len(names)} screenshots at {expected[0]} × {expected[1]} in {directory}")
