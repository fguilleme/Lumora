# Beauty V1 — blemish component acceptance

**Ready for final visual review, with one quality caveat.** This pass restores the archived seed-and-region-grow detector to the Beauty mask pipeline and changes only the component-acceptance decision. The inflammatory seed calculation, grower, general skin mask, repair renderer, Dark Circles and presets are unchanged. There was one acceptance correction and one validation campaign; no subsequent aesthetic tuning.

## Rejection diagnosis

The [pre-correction component table](../ComponentAcceptanceBaseline/component_diagnostics.md) identified the chin object's actual veto. Its 929-pixel, elongated connected seed object exceeded the face-relative area maximum. It had red-opponent mean/max **0.04007 / 0.08667**, mean seed **0.513**, skin confidence **0.612** and feature distance **33.4 analysis pixels**. It was rejected by `area_above_face_relative_maximum` before growth despite an old combined confidence of **0.392**. The cheek lesion was a distinct 116-pixel accepted component. The freckles formed many small, similar nearby components with weaker inflammatory response.

## Acceptance model

The [candidate-by-candidate table](component_diagnostics.md) records area, compactness, covariance eccentricity, red-opponent mean/max, pigmentation confidence, local contrast, nearby *similar* count, distance to a strong facial feature, each score contribution and the final reason. Similarity uses nearby component size, red response and pigmentation, instead of counting every object in the neighborhood.

The score is `clamp(red + shape + skin − pigmentation − repetition − feature − size, 0, 1)`:

- `red = 0.35 smooth(0.04, 0.085, redMax) + 0.35 meanSeed`;
- `shape = 0.15 compactness`; `skin = 0.15 meanSkin`;
- `pigmentation = 0.30 meanPigment`; `repetition = 0.25 smooth(4, 10, similarCount)`;
- `feature = 0.20 × (1 − smooth(3, 12, featureDistance))`;
- `size = 0.08 smooth(1, 2, area/maxArea)`, plus 0.08 for a single-pixel object.

`smooth` is the continuous cubic smoothstep. A score above **0.42** accepts a component; no individual area, pigment or repetition descriptor vetoes it. Eccentricity and local contrast remain diagnostics, not additional hidden gates. The accepted chin component scores **0.543** (red 0.530, shape 0.009, skin 0.092, pigmentation 0.007, size 0.080). Its strongly red, localized peak supplies a small accepted core to the **unchanged** region grower; the entire elongated connected skirt does not become a seed. The cheek lesion scores **0.795**. The sampled forehead freckle at `(446,208)` scores **0.123**: its 32 similar neighbors and pigmentation outweigh its weaker red evidence.

## Regional results

Native-source-pixel ROI measurements are in [blemish_region_metrics.md](blemish_region_metrics.md); all five amounts are in [amount_progression.md](amount_progression.md). Selected means final matte > 0.01. RGB MAE is the full-ROI change at 100, so it is descriptive, not an aesthetic rating.

| ROI | Selected | RGB MAE at 100 | Assessment |
|---|---:|---:|---|
| 03 cheek lesion | 36.78% | 0.012672 | PASS: retained and stronger than archived redesign (0.010418 MAE). |
| 03 chin lesion | 55.58% | 0.004967 | PASS: accepted core, grown region, progressive attenuation. |
| 04 forehead freckles | 0.00% | 0 | PASS: unchanged. |
| 04 cheek freckles | 1.59% | 0.000072 | PASS: near-zero selection; no visible broad attenuation in the sweep. |
| 05 wrinkles | 2.06% | 0.000172 | WARN quality: sparse low-confidence selection, visually unchanged at 100%. |
| 06 beard/moustache | 0.00% | 0 | PASS: unselected. |

The chin RGB MAE progresses **0, 0.001242, 0.002484, 0.003726, 0.004967** at amounts 0/25/50/75/100. The cheek progresses **0, 0.003168, 0.006336, 0.009504, 0.012672**. The automated test requires positive, monotonic progression for both lesions; nonfinite outputs were zero in every measured ROI. Freckles at 100 appear unchanged on visual inspection of these diagnostic crops. The 05 wrinkle selection is a small regression against the archived redesign's 0% selected area and merits human review; the implementation is not tuned further in this pass.

## Visual inspection

Inspect [chin accepted seeds](Overlays/03_acne_redness_chin_accepted_seeds.png), [chin grown region](Overlays/03_acne_redness_chin_grown_regions.png), [chin stage sheet at 200%](Stages/03_acne_redness_chin_200pct.png), [chin sweep](Sweeps/03_acne_redness_chin_lesion_100pct.png), [cheek sweep](Sweeps/03_acne_redness_cheek_lesion_100pct.png), [forehead freckle sweep](Sweeps/04_strong_freckles_forehead_freckles_100pct.png), [cheek freckle sweep](Sweeps/04_strong_freckles_cheek_freckles_100pct.png), [wrinkle sweep](Sweeps/05_older_wrinkles_wrinkles_100pct.png) and [beard sweep](Sweeps/06_beard_moustache_beard_100pct.png).

The target diagnostic tests passed, as did six Beauty core tests covering state, Undo/Redo, document reload, Vision cancellation, neutral/HDR behavior, no-face identity and masked rendering. The iOS Simulator app build succeeded. Final visual approval remains with the user; no preset or renderer change follows this report.
