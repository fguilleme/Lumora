"""Flatten the Debug Lab's per-image halo metrics for independent inspection."""
import csv
import json
from collections import defaultdict
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "Validation/DebugLab/HaloCorpus/metrics.json"
OUTPUT = ROOT / "Validation/DebugLab/HaloDiagnostics/per_image_metrics.csv"
VARIANT_OUTPUT = ROOT / "Validation/DebugLab/HaloDiagnostics/per_variant_metrics.csv"


def field(metric, path):
    value = metric
    for part in path.split("."):
        value = value.get(part) if isinstance(value, dict) else None
    return value


FIELDS = [
    "meanAbsoluteY", "p95AbsoluteY", "meanAbsoluteChroma", "p95AbsoluteChroma",
    "changed2", "changed5", "changed10", "changed20",
    "shadows.meanAbsoluteY", "midtones.meanAbsoluteY", "highlights.meanAbsoluteY",
    "subjectSource", "subject.meanAbsoluteY", "background.meanAbsoluteY",
    "meanAbsoluteLocalContrastChange", "meanSignedLocalContrastChange",
    "introducedShadowClipping", "introducedHighlightClipping",
    "strongEdgeCount", "brightHaloCount", "darkHaloCount", "edgeEnhancementCount",
    "brightHaloBands", "darkHaloBands", "largestBandPixels",
    "brightHaloFraction", "darkHaloFraction",
    "left.excess", "right.excess", "top.excess", "bottom.excess",
    "leftRightExcessAsymmetry", "topBottomExcessAsymmetry",
    "worstX", "worstY", "worstResidual", "suspectedCause", "diagnosisConfidence",
]

rows = json.loads(SOURCE.read_text())
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
with OUTPUT.open("w", newline="") as destination:
    writer = csv.writer(destination, lineterminator="\n")
    writer.writerow(["image", "variant", "width", "height", *FIELDS])
    for row in sorted(rows, key=lambda item: (item["image"], item["variant"])):
        metric = row["metrics"]
        writer.writerow([row["image"], row["variant"], metric["width"], metric["height"],
                         *(field(metric, name) for name in FIELDS)])
print(f"{len(rows)} image/variant rows → {OUTPUT}")

groups = defaultdict(list)
for row in rows:
    groups[row["variant"]].append(row)

AVERAGES = [
    "meanAbsoluteY", "meanAbsoluteChroma", "changed2", "changed5", "changed10",
    "changed20", "shadows.meanAbsoluteY", "midtones.meanAbsoluteY",
    "highlights.meanAbsoluteY", "meanAbsoluteLocalContrastChange",
    "brightHaloFraction", "darkHaloFraction", "brightHaloBands", "darkHaloBands",
]
OPTIONAL = ["subject.meanAbsoluteY", "background.meanAbsoluteY"]
MAXIMA = ["p95AbsoluteY", "p95AbsoluteChroma", "introducedShadowClipping",
          "introducedHighlightClipping", "leftRightExcessAsymmetry",
          "topBottomExcessAsymmetry", "largestBandPixels"]
with VARIANT_OUTPUT.open("w", newline="") as destination:
    writer = csv.writer(destination, lineterminator="\n")
    writer.writerow(["variant", "images", *["mean_" + name for name in AVERAGES],
                     *["mean_" + name for name in OPTIONAL],
                     *["max_" + name for name in MAXIMA],
                     "worstDestructivenessImage", "worstResidualImage", "worstResidualX",
                     "worstResidualY", "worstResidual"])
    for variant, group in sorted(groups.items()):
        metrics = [row["metrics"] for row in group]
        worst_y = max(group, key=lambda row: row["metrics"]["meanAbsoluteY"])
        worst_residual = max(group, key=lambda row: row["metrics"]["worstResidual"])
        optional = [[field(item, name) for item in metrics] for name in OPTIONAL]
        writer.writerow([variant, len(group),
                         *(mean(field(item, name) for item in metrics) for name in AVERAGES),
                         *(mean(value for value in values if value is not None)
                           if any(value is not None for value in values) else "" for values in optional),
                         *(max(field(item, name) for item in metrics) for name in MAXIMA),
                         worst_y["image"], worst_residual["image"],
                         worst_residual["metrics"]["worstX"],
                         worst_residual["metrics"]["worstY"],
                         worst_residual["metrics"]["worstResidual"]])
print(f"{len(groups)} variant rows → {VARIANT_OUTPUT}")
