# Beauty V1 — one-pass Imperfections detector redesign

**Result: not ready for final visual review.** The single redesign protected freckles, wrinkles and beard and retained the cheek lesion, but it rejected the prominent chin lesion entirely. Per the stop rule, no second tuning pass was made. The failed design and its images are archived here; the production Imperfections detector was restored. Dark Circles, presets, the general skin mask and the blemish repair renderer remain unchanged.

## Prototype model

The archived [prototype source](BeautyBlemishDetectorPrototype.swift) separates a skin-relative inflammatory seed from bounded region growth. In sRGB analysis space, the red opponent coordinate is `R − (G+B)/2`; its local displacement is measured against 4 px and 11 px Gaussian neighborhoods. A correlated decrease across R, G and B contributes pigmentation confidence, while a positive red advantage reduces that confidence. Eight-connected seed components are filtered by area and by the count of nearby similar components; this cluster test applies whether a spot originally entered through chroma or luminance. Accepted components grow only within the existing skin matte, over a face-relative bounded radius, with color affinity and a gradual distance falloff. Analysis runs once per image/mask-cache miss, never per slider frame.

This formulation is **not** a validated production detector. Its component-level veto protects freckles but also rejects the chin lesion; the exact component descriptor responsible was not isolated in this pass. The current production path remains the previous GPU detector.

## Measurements

The tables below keep lesion and protection regions separate. Final matte and RGB values come from native source-pixel ROIs; full [numeric data](Redesign/blemish_region_metrics.md) include P95. Seed, pigmentation, accepted-seed and grown-area figures are **estimates from the rendered diagnostic maps** (a displayed raster, not raw floating-point values), used to locate the failed stage rather than to score appearance.

| Inflammatory ROI | Seed map mean | Accepted-seed fraction | Grown-area fraction | Final matte mean / P95 | RGB MAE at 100 | Verdict |
|---|---:|---:|---:|---:|---:|---|
| 03 cheek | ~0.231 | ~28.9% | ~37.2% | 0.166 / 0.651 | 0.01042 | Captured, progressive attenuation; below the previous 0.01863 MAE. |
| 03 chin | ~0.206 | **0%** | **0%** | **0 / 0** | **0** | **FAIL:** visible lesion unchanged at every sweep value. |

| Protection ROI | Pigmentation map mean | Inflammatory seed-map fraction > 1% | Final selected fraction | RGB MAE at 100 | Verdict |
|---|---:|---:|---:|---:|---|
| 04 forehead freckles | ~0.084 | ~23.3% | **0%** | 0 | Freckles preserved. |
| 04 cheek freckles | ~0.115 | ~26.7% | **0%** | 0 | Freckles preserved. |
| 05 wrinkles | — | — | **0%** | 0 | Structure preserved in measured crop. |
| 06 beard/moustache | — | — | **0%** | 0 | Hair preserved in measured crop. |

The chin [stage map](Redesign/Stages/03_acne_redness_chin_200pct.png) shows inflammatory seed response but no accepted seed, grown region or final matte. Its skin-confidence map remains high at the lesion and the feature exclusion does not cover it. This is a component-acceptance failure, upstream of the unchanged repair renderer; the region-grow stage never gets an eligible chin seed. The [forehead stage map](Redesign/Stages/04_strong_freckles_forehead_200pct.png) shows numerous raw seeds but no accepted freckles.

## Artifacts and execution

For each of 03 cheek/chin and 04 forehead/cheek, [Redesign/Stages](Redesign/Stages) and [Redesign/Overlays](Redesign/Overlays) contain inflammatory seed confidence, pigmentation/freckle confidence, accepted seeds, grown regions, final soft matte and source overlays. [Redesign/Comparisons](Redesign/Comparisons) contains source, old final matte, trial matte and trial overlay. [Redesign/Sweeps](Redesign/Sweeps) contains 0/25/50/75/100 crops for 03, 04, 05 and 06.

Inspect first: [chin old/new matte](Redesign/Comparisons/03_acne_redness_chin_lesion.png), [chin sweep](Redesign/Sweeps/03_acne_redness_chin_lesion_100pct.png), [cheek sweep](Redesign/Sweeps/03_acne_redness_cheek_lesion_100pct.png), [forehead old/new matte](Redesign/Comparisons/04_strong_freckles_forehead_freckles.png), and [forehead sweep](Redesign/Sweeps/04_strong_freckles_forehead_freckles_100pct.png).

The Metal-backed diagnostic and regional-sweep tests passed, including finite-value checks. After removing the failed production integration, both were rerun against the restored detector; [Current](Current) and [Before](Before) again represent the production baseline. Passing test execution does **not** satisfy the photographic chin criterion.
