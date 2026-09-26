"""Check repository layout without running photographic campaigns or changing files."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
mapping = json.loads((ROOT / "Validation/relocation-map.json").read_text())
errors = []
for old, new in mapping.items():
    if (ROOT / old).exists():
        errors.append(f"Old validation location recreated: {old}")
    if not (ROOT / new).exists():
        errors.append(f"Missing relocated content: {new}")
package = (ROOT / "Package.swift").read_text()
for target in ("LumoraCoreTests", "LumoraVisualTestLab"):
    expected = f'path: "Validation/Tests/{target}"'
    if expected not in package:
        errors.append(f"Missing SwiftPM path: {expected}")
project = (ROOT / "Lumora.xcodeproj/project.pbxproj").read_text()
if "path = Validation/LumoraUITests;" not in project:
    errors.append("Xcode UI test group points outside Validation")
for resource in ("Baselines", "Fixtures"):
    if not (ROOT / "Validation/Tests/LumoraVisualTestLab" / resource).is_dir():
        errors.append(f"Missing Lab resource: {resource}")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"PASS: {len(mapping)} relocated roots, SwiftPM/Xcode targets and Lab resources.")
