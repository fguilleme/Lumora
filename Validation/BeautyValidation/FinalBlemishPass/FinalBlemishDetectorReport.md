# Beauty V1 — final blemish detector pass

**Decision: Imperfections is not ready to freeze for V1.** One detector-only trial was made and validated. It did not meet the two hard photographic acceptance criteria, so its production changes were reverted. Dark Circles, presets, the general skin mask, frequency separation, and the blemish repair renderer were not changed. No second tuning pass was performed.

## Detector-stage attribution

The [pre-change stage maps](Before/Stages) and [per-stage overlays](Before/Overlays) expose skin confidence, raw chroma/dark/light anomalies, multiscale candidate, edge/detail protection, repeated-dark density and suppression, prethreshold evidence, feature exclusion, and final confidence. The four requested crops have separate files.

| Region | Where the decision occurs |
|---|---|
| 03 cheek | The prominent red lesion reaches the candidate and final matte and is progressively attenuated. Current lesion ROI: mean final confidence 0.261, 29.77% selected, RGB MAE at 100 = 0.01863. |
| 03 chin | **Not a skin-confidence or lip-exclusion failure at the measured lesion.** In the lesion ROI, skin confidence averages 0.999, feature exclusion 0, edge/detail protection 0.993, chroma anomaly 0.210, and multiscale candidate 0.222. Prethreshold evidence averages only 0.052 and final confidence about 0.041 in the rendered diagnostic map: the candidate is compact but covers too little of the visible lesion, and the final confidence transfer further reduces its outskirts. The current numeric matte ROI has mean confidence 0.010, 13.65% selected, and RGB MAE at 100 only 0.00067. The lesion remains visibly present. |
| 04 forehead and cheek | Freckles trigger the local red/chroma opponent response even though they are predominantly pigmentation. The repeated-dark map is weak at many selected spots; the suppression is calculated from repeated **dark** response and therefore misses freckles entering by the **chroma** branch. Current final matte selects 10.45% of the forehead crop and 6.12% of the cheek crop. Their visible attenuation at 100 is unacceptable for this control. |

The maps distinguish the measured stage failure from a theory about skin tone: no absolute complexion threshold was implicated. The current detector also admits dark/light candidates, which is broader than the requested V1 inflammatory-only scope.

## Single trial and validation

The trial narrowed the blemish-specific lip exclusion and required local red-channel retention for the inflammatory candidate, while leaving the other Beauty controls and repair untouched. Its [stage maps](Trial/Stages), [old/new matte comparisons](Trial/Comparisons), [isolated 0/25/50/75/100 sweeps](Trial/Sweeps), and [regional metrics](Trial/blemish_region_metrics.md) are retained for inspection. `Current/` contains the measurements and sheets after reverting the failed trial.

| ROI | Current: mean confidence / selected / RGB MAE 100 | Trial: mean confidence / selected / RGB MAE 100 | Result |
|---|---|---|---|
| 03 cheek lesion | 0.261 / 29.77% / 0.01863 | 0.238 / 29.13% / 0.01568 | Captured in both. |
| 03 chin lesion | 0.010 / 13.65% / 0.00067 | 0.006 / 12.80% / 0.00036 | **FAIL:** still barely affected; trial worsened coverage. |
| 04 forehead freckles | 0.046 / 10.45% / 0.00154 | 0.044 / 10.36% / 0.00149 | **FAIL:** many freckles remain selected. |
| 04 cheek freckles | 0.014 / 6.12% / 0.00032 | 0.013 / 4.43% / 0.00028 | **FAIL:** selection remains visible. |
| 05 wrinkles | 0.0017 / 3.69% / 0.000078 | 0.0010 / 0.99% / 0.000027 | No trial regression detected in this crop. |
| 06 beard | 0.00016 / 0.46% / 0.000011 | 0 / 0% / 0 | No trial regression detected in this crop. |

The matte is continuous, but the trial did not achieve strong inflammatory-lesion coverage and freckle protection at the same time. No further threshold, preset, or renderer adjustment followed these results.

## Validation and inspection

`beautyBlemishStageDiagnostics` and `beautyFinalBlemishValidation` passed with Metal. All measured outputs are finite. These tests validate the diagnostic pipeline and artifacts; they do **not** turn the photographic failures above into a PASS. The latter test was rerun after rollback, confirming the production detector remains at its previous behavior.

Inspect first: [03 chin stages before](Before/Stages/03_acne_redness_chin_200pct.png), [03 chin trial sweep](Trial/Sweeps/03_acne_redness_chin_lesion_100pct.png), [04 forehead stages before](Before/Stages/04_strong_freckles_forehead_200pct.png), [04 forehead trial matte comparison](Trial/Comparisons/04_strong_freckles_forehead_freckles.png), then [current regional metrics](Current/blemish_region_metrics.md). Wait for human inspection before another detector design pass.
