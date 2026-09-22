# Lumora Creative FX Validation

Mode: **QUICK 512²**. Metal device: **Apple M2 Pro**.
Measurement: extended linear sRGB / RGBA Float32 before display conversion.
Generated: 2026-09-22T12:28:38Z. Chart SHA256: `2ae17d62739e2ca7ad6cd128f3604253fa8f9f6c98dc55858b8d6024e3c505d4`.

PASS means the listed property passed, not aesthetic approval. WARN is a quality heuristic requiring review; FAIL is a broken hard invariant. No effect algorithms were changed by this lab.
No Golden Masters are recorded by default. Mathematical references are independent source/endpoint identities. Repeated renders test determinism only, never serve as expected-output oracles.

## Summary

| Case | Status |
| --- | --- |
| HK01_standard | WARN |
| HK02_dynamic | WARN |
| HK03_strong_dynamic | WARN |
| HK04_protected | WARN |
| HK05_glow | WARN |
| HK00_identity | PASS |
| LK01_standard | PASS |
| LK02_dynamic | WARN |
| LK03_strong_dynamic | WARN |
| LK04_protected | PASS |
| LK05_glow | PASS |
| LK00_identity | PASS |
| LK_DynamicSweep_000 | PASS |
| LK_DynamicSweep_025 | PASS |
| LK_DynamicSweep_050 | PASS |
| LK_DynamicSweep_075 | PASS |
| LK_DynamicSweep_100 | PASS |
| Grain_fine | PASS |
| Grain_medium | PASS |
| Grain_large | PASS |
| Grain_soft | PASS |
| Grain_hardness_medium | PASS |
| Grain_hard | PASS |
| Grain_monochromatic | PASS |
| Grain_clumping_zero | PASS |
| Grain_clumping_medium | PASS |
| Grain_clumping_strong | PASS |
| Grain_softness_zero | PASS |
| Grain_softness_strong | PASS |
| Grain_response_shadow | PASS |
| Grain_response_midtone | PASS |
| Grain_response_highlight | PASS |
| Grain_chromatic | PASS |
| Grain_properties | WARN |
| Edges_HighKey | PASS |
| Edges_HighKeyGlow | PASS |
| Edges_LowKey | PASS |
| Edges_LowKeyGlow | PASS |
| Edges_Grain | PASS |
| Textures_HighKey | PASS |
| Textures_HighKeyGlow | PASS |
| Textures_LowKey | PASS |
| Textures_LowKeyGlow | PASS |
| Textures_Grain | PASS |
| Mask_highKey | PASS |
| Mask_grain | PASS |
| EffectStack_order | PASS |
| Grain_continuity_shadowAmount | PASS |
| Grain_continuity_midtoneAmount | PASS |
| Grain_continuity_highlightAmount | PASS |
| Scenes_portrait | PASS |
| Scenes_landscape | PASS |
| Scenes_night | PASS |
| Scenes_still-life | PASS |
| Photographs_photo-0 | PASS |
| Photographs_photo-1 | PASS |
| Photographs_photo-2 | PASS |
| Photographs_photo-3 | PASS |
| Photographs_photo-4 | PASS |
| Photographs_photo-5 | PASS |
| Photographs_photo-6 | PASS |
| Photographs_photo-7 | PASS |
| Performance_256 | PASS |
| Performance_512 | PASS |
| Performance_1024 | PASS |
| Grain_resolution_consistency | WARN |
| Real_preview_HQ_export | PASS |

## Important comparison sheets

- [HighKey/contact_sheet.png](HighKey/contact_sheet.png)
- [LowKey/contact_sheet.png](LowKey/contact_sheet.png)
- [LowKey/dynamic_luminance_absolute.png](LowKey/dynamic_luminance_absolute.png)
- [LowKey/dynamic_luminance_relative.png](LowKey/dynamic_luminance_relative.png)
- [LowKey/dynamic_transfer.png](LowKey/dynamic_transfer.png)
- [LowKey/dynamic_contact_sheet.png](LowKey/dynamic_contact_sheet.png)
- [Grain/contact_sheet.png](Grain/contact_sheet.png)
- [ContactSheets/Grain_100percent.png](ContactSheets/Grain_100percent.png)
- [Grain/spectrum.png](Grain/spectrum.png)
- [Grain/autocorrelation.png](Grain/autocorrelation.png)
- [Grain/resolution_comparison.png](Grain/resolution_comparison.png)
- [Pipeline/comparison.png](Pipeline/comparison.png)
- [ContactSheets/Edges.png](ContactSheets/Edges.png)
- [Masks/highKey.png](Masks/highKey.png)
- [Masks/grain.png](Masks/grain.png)
- [EffectStack/comparison.png](EffectStack/comparison.png)

## Low Key photographic contract

Five input-linear zones: deep shadows [0,.10), shadows [.10,.30), midtones [.30,.65), bright tones [.65,.90), specular whites [.95,1]. [.90,.95] is a transition excluded from zone averages, included in full-curve checks. Absolute change is signed mean(output-input), in linear luminance units; relative change is that value divided by mean(input). Legacy [.90,1] is specular/high-end response, not a general highlights measure. Historical WARN remains visible.

Dynamic sweep: Amount=.60; Dynamic=0,.25,.50,.75,1; all other fields identical. Progressive shadow reduction, bright-tone increase and rightward loss centroid are quality expectations, reported honestly as WARN if absent. Specular protection is evaluated separately. Finiteness and no tonal inversions are hard invariants.

| Dynamic | Zone | Absolute change | Relative change |
| --- | --- | ---: | ---: |
| 0.00 | deep-shadows | -0.018232 | -36.536 % |
| 0.00 | shadows | -0.084722 | -42.237 % |
| 0.00 | midtones | -0.129155 | -27.160 % |
| 0.00 | bright-tones | -0.074255 | -9.582 % |
| 0.00 | specular-whites | -0.004081 | -0.418 % |
| 0.25 | deep-shadows | -0.014017 | -28.090 % |
| 0.25 | shadows | -0.068692 | -34.246 % |
| 0.25 | midtones | -0.118947 | -25.013 % |
| 0.25 | bright-tones | -0.084215 | -10.867 % |
| 0.25 | specular-whites | -0.008922 | -0.915 % |
| 0.50 | deep-shadows | -0.009802 | -19.643 % |
| 0.50 | shadows | -0.052663 | -26.254 % |
| 0.50 | midtones | -0.108739 | -22.866 % |
| 0.50 | bright-tones | -0.094174 | -12.152 % |
| 0.50 | specular-whites | -0.013764 | -1.411 % |
| 0.75 | deep-shadows | -0.005588 | -11.197 % |
| 0.75 | shadows | -0.036633 | -18.263 % |
| 0.75 | midtones | -0.098530 | -20.720 % |
| 0.75 | bright-tones | -0.104134 | -13.438 % |
| 0.75 | specular-whites | -0.018605 | -1.907 % |
| 1.00 | deep-shadows | -0.001373 | -2.751 % |
| 1.00 | shadows | -0.020603 | -10.272 % |
| 1.00 | midtones | -0.088322 | -18.573 % |
| 1.00 | bright-tones | -0.114094 | -14.723 % |
| 1.00 | specular-whites | -0.023447 | -2.403 % |

## Interpretation and thresholds

All tolerances are specified per check below. Hard invariants: finite pixels, neutral identity/endpoints (2e-6 linear RGB), same-seed repeatability (1e-6), outside-mask identity, nonzero inside-mask/order response, and separately reviewed golden agreement. Quality heuristics do not fail the test process. Clipping counts include known black/white/HDR sources: inspect increases relative to input, not absolute counts alone. SDR PNGs clip HDR for viewing; Charts/master_linear.tiff preserves source headroom. Histograms clamp overflow into endpoint bins. Residual histograms cover [-.25,.25]. SSIM is mean non-overlapping 8×8 luminance-window SSIM with L=1, C1=.0001, C2=.0009; not multiscale SSIM. Spectrum uses a mean-subtracted Hann-windowed 256px (or smaller power-of-two) residual and vDSP 2D FFT; radial bins contain total energy, normalized to unity. Physical runtime/thermal behavior requires an iPhone measurement.

## HK01_standard — WARN

- additionalChannelClippingPercent: 5.0292969
- blackClippingPercent: 4.2480469
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- maxAdjacentRampStep: 0.0030500442
- maxColorPatchChromaticityDrift: 2.7548214e-08
- meanInput: 0.48542271
- meanOutput: 0.54053184
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 9.9430084
- ramp-highlights-relativeChange: 0.0082179229
- ramp-midtones-relativeChange: 0.22198825
- ramp-shadows-relativeChange: 0.3033416
- whiteClippingPercent: 10.797501
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **WARN** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Neutral-saturation hue preservation [quality heuristic]: Max RGB/sum(RGB) component drift below .001 on controlled color patches; independent of brightness scaling.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- **PASS** Known black and white endpoints [hard invariant]: Neutral 0 and 1 patches remain exactly 0 and 1 without glow, within 2e-6 linear RGB.
- WARN: no reviewed golden configured
- [HighKey/01_standard.png](HighKey/01_standard.png)
- [HighKey/01_standard_difference_x4.png](HighKey/01_standard_difference_x4.png)
- [HighKey/01_standard_transfer_curve.png](HighKey/01_standard_transfer_curve.png)

## HK02_dynamic — WARN

- additionalChannelClippingPercent: 5.0292969
- blackClippingPercent: 4.2480469
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- maxAdjacentRampStep: 0.0046551945
- maxColorPatchChromaticityDrift: 2.321803e-08
- meanInput: 0.48542271
- meanOutput: 0.54001848
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 9.9430084
- ramp-highlights-relativeChange: 0.0044013845
- ramp-midtones-relativeChange: 0.18759673
- ramp-shadows-relativeChange: 0.63910479
- whiteClippingPercent: 10.797501
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **WARN** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Neutral-saturation hue preservation [quality heuristic]: Max RGB/sum(RGB) component drift below .001 on controlled color patches; independent of brightness scaling.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- **PASS** Dynamic relative response [quality heuristic]: Relative change = (mean output − mean input)/mean input. Historical shadow [0,.1] and high-end [.9,1] ramps; for Low Key this is specular/high-end response, not a general highlights contract. WARN retained for historical comparison.
- **PASS** Known black and white endpoints [hard invariant]: Neutral 0 and 1 patches remain exactly 0 and 1 without glow, within 2e-6 linear RGB.
- WARN: no reviewed golden configured
- [HighKey/02_dynamic.png](HighKey/02_dynamic.png)
- [HighKey/02_dynamic_difference_x4.png](HighKey/02_dynamic_difference_x4.png)
- [HighKey/02_dynamic_transfer_curve.png](HighKey/02_dynamic_transfer_curve.png)

## HK03_strong_dynamic — WARN

- additionalChannelClippingPercent: 8.8134766
- blackClippingPercent: 4.2480469
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- maxAdjacentRampStep: 0.010255652
- maxColorPatchChromaticityDrift: 2.4755286e-08
- meanInput: 0.48542271
- meanOutput: 0.58295585
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 13.727188
- ramp-highlights-relativeChange: 0.0024266679
- ramp-midtones-relativeChange: 0.28815033
- ramp-shadows-relativeChange: 1.6338876
- whiteClippingPercent: 14.58168
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **WARN** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Neutral-saturation hue preservation [quality heuristic]: Max RGB/sum(RGB) component drift below .001 on controlled color patches; independent of brightness scaling.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- **PASS** Dynamic relative response [quality heuristic]: Relative change = (mean output − mean input)/mean input. Historical shadow [0,.1] and high-end [.9,1] ramps; for Low Key this is specular/high-end response, not a general highlights contract. WARN retained for historical comparison.
- **PASS** Known black and white endpoints [hard invariant]: Neutral 0 and 1 patches remain exactly 0 and 1 without glow, within 2e-6 linear RGB.
- WARN: no reviewed golden configured
- [HighKey/03_strong_dynamic.png](HighKey/03_strong_dynamic.png)
- [HighKey/03_strong_dynamic_difference_x4.png](HighKey/03_strong_dynamic_difference_x4.png)
- [HighKey/03_strong_dynamic_transfer_curve.png](HighKey/03_strong_dynamic_transfer_curve.png)

## HK04_protected — WARN

- additionalChannelClippingPercent: 7.5439453
- blackClippingPercent: 4.2480469
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- maxAdjacentRampStep: 0.0068137916
- maxColorPatchChromaticityDrift: 2.8745868e-08
- meanInput: 0.48542271
- meanOutput: 0.5823112
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 12.457657
- protectedNearEndpointChange: 7.635355e-05
- ramp-highlights-relativeChange: 0.0022081339
- ramp-midtones-relativeChange: 0.33767411
- ramp-shadows-relativeChange: 1.1503886
- unprotectedBlackClippingPixels: 11136
- unprotectedNearEndpointChange: 0.0080981851
- unprotectedWhiteClippingPixels: 34897
- whiteClippingPercent: 13.312149
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **WARN** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Neutral-saturation hue preservation [quality heuristic]: Max RGB/sum(RGB) component drift below .001 on controlled color patches; independent of brightness scaling.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- **PASS** Protection preserves near-endpoint detail [quality heuristic]: Compare gray .98 for High Key and .02 for Low Key at identical Amount/Dynamic; protected patch should move less even when no pixels clip.
- **PASS** Protection clipping comparison [quality heuristic]: Compare identical settings except protection=0. Equality may be inconclusive when neither output clips.
- **PASS** Known black and white endpoints [hard invariant]: Neutral 0 and 1 patches remain exactly 0 and 1 without glow, within 2e-6 linear RGB.
- WARN: no reviewed golden configured
- [HighKey/04_protected.png](HighKey/04_protected.png)
- [HighKey/04_protected_difference_x4.png](HighKey/04_protected_difference_x4.png)
- [HighKey/04_protected_transfer_curve.png](HighKey/04_protected_transfer_curve.png)

## HK05_glow — WARN

- additionalChannelClippingPercent: 5.0292969
- blackClippingPercent: 4.0344238
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- maxAdjacentRampStep: 0.0046551945
- maxColorPatchChromaticityDrift: 0.097281764
- meanInput: 0.48542271
- meanOutput: 0.54189731
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 9.9430084
- ramp-highlights-relativeChange: 0.0078088559
- ramp-midtones-relativeChange: 0.19215717
- ramp-shadows-relativeChange: 0.66163595
- whiteClippingPercent: 10.797501
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **WARN** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- WARN: no reviewed golden configured
- [HighKey/05_glow.png](HighKey/05_glow.png)
- [HighKey/05_glow_difference_x4.png](HighKey/05_glow_difference_x4.png)
- [HighKey/05_glow_transfer_curve.png](HighKey/05_glow_transfer_curve.png)

## HK00_identity — PASS

- identityMaxError: 0
- **PASS** Amount zero identity [hard invariant]: Expected = untouched analytic chart, not an effect render.

## LK01_standard — PASS

- additionalChannelClippingPercent: 0
- blackClippingPercent: 4.2480469
- bright-tones-absoluteChange: -0.061879082
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.71307199
- bright-tones-relativeChange: -0.079849017
- bright-tones-sampleCount: 127
- deep-shadows-absoluteChange: -0.015193465
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.034708687
- deep-shadows-relativeChange: -0.30446512
- deep-shadows-sampleCount: 52
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- legacy-specular-high-end-response-relativeChange: -0.008217898
- maxAdjacentRampStep: 0.0027660131
- maxColorPatchChromaticityDrift: 2.3308123e-08
- meanInput: 0.48542271
- meanOutput: 0.43031359
- midtones-absoluteChange: -0.10762941
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.36790875
- midtones-relativeChange: -0.22633181
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 4.9137115
- ramp-midtones-relativeChange: -0.22198824
- ramp-shadows-relativeChange: -0.30334158
- shadows-absoluteChange: -0.070601721
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.12998536
- shadows-relativeChange: -0.35197541
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.0034008645
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.97213729
- specular-whites-relativeChange: -0.003486142
- specular-whites-sampleCount: 26
- whiteClippingPercent: 5.7682037
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **PASS** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Neutral-saturation hue preservation [quality heuristic]: Max RGB/sum(RGB) component drift below .001 on controlled color patches; independent of brightness scaling.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- **PASS** Known black and white endpoints [hard invariant]: Neutral 0 and 1 patches remain exactly 0 and 1 without glow, within 2e-6 linear RGB.
- Historical ramp metrics retained: shadows [0,.10], midtones [.40,.60], specular/high-end response [.90,1]. The latter is not a general highlights measure. New photographic zones are reported separately; [.90,.95] is an intentionally unclassified transition.
- WARN: no reviewed golden configured
- [LowKey/01_standard.png](LowKey/01_standard.png)
- [LowKey/01_standard_difference_x4.png](LowKey/01_standard_difference_x4.png)
- [LowKey/01_standard_transfer_curve.png](LowKey/01_standard_transfer_curve.png)

## LK02_dynamic — WARN

- additionalChannelClippingPercent: 0
- blackClippingPercent: 4.2480469
- bright-tones-absoluteChange: -0.078478683
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.69647239
- bright-tones-relativeChange: -0.10126921
- bright-tones-sampleCount: 127
- deep-shadows-absoluteChange: -0.0081687494
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.041733403
- deep-shadows-relativeChange: -0.16369533
- deep-shadows-sampleCount: 52
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- legacy-specular-high-end-response-relativeChange: -0.020012162
- maxAdjacentRampStep: 0.0050637722
- maxColorPatchChromaticityDrift: 1.5326052e-08
- meanInput: 0.48542271
- meanOutput: 0.43745524
- midtones-absoluteChange: -0.090615449
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.38492271
- midtones-relativeChange: -0.19055348
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 4.9137115
- ramp-midtones-relativeChange: -0.19040303
- ramp-shadows-relativeChange: -0.1630107
- shadows-absoluteChange: -0.043885607
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.15670148
- shadows-relativeChange: -0.2187858
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.011469889
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.96406827
- specular-whites-relativeChange: -0.011757499
- specular-whites-sampleCount: 26
- whiteClippingPercent: 5.7682037
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **PASS** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Neutral-saturation hue preservation [quality heuristic]: Max RGB/sum(RGB) component drift below .001 on controlled color patches; independent of brightness scaling.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- **WARN** Historical specular/high-end vs deep-shadow relative response [quality heuristic]: Relative change = (mean output − mean input)/mean input. Historical shadow [0,.1] and high-end [.9,1] ramps; for Low Key this is specular/high-end response, not a general highlights contract. WARN retained for historical comparison.
- **PASS** Known black and white endpoints [hard invariant]: Neutral 0 and 1 patches remain exactly 0 and 1 without glow, within 2e-6 linear RGB.
- Historical ramp metrics retained: shadows [0,.10], midtones [.40,.60], specular/high-end response [.90,1]. The latter is not a general highlights measure. New photographic zones are reported separately; [.90,.95] is an intentionally unclassified transition.
- WARN: no reviewed golden configured
- [LowKey/02_dynamic.png](LowKey/02_dynamic.png)
- [LowKey/02_dynamic_difference_x4.png](LowKey/02_dynamic_difference_x4.png)
- [LowKey/02_dynamic_transfer_curve.png](LowKey/02_dynamic_transfer_curve.png)

## LK03_strong_dynamic — WARN

- additionalChannelClippingPercent: 0
- blackClippingPercent: 4.2480469
- bright-tones-absoluteChange: -0.16516504
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.60978604
- bright-tones-relativeChange: -0.21312963
- bright-tones-sampleCount: 127
- deep-shadows-absoluteChange: -0.004588158
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.045313994
- deep-shadows-relativeChange: -0.091943088
- deep-shadows-sampleCount: 52
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- legacy-specular-high-end-response-relativeChange: -0.053005634
- maxAdjacentRampStep: 0.011643231
- maxColorPatchChromaticityDrift: 1.9814878e-08
- meanInput: 0.48542271
- meanOutput: 0.40936523
- midtones-absoluteChange: -0.13860771
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.33693045
- midtones-relativeChange: -0.29147547
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 4.9137115
- ramp-midtones-relativeChange: -0.29724274
- ramp-shadows-relativeChange: -0.09134279
- shadows-absoluteChange: -0.04052289
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.1600642
- shadows-relativeChange: -0.20202143
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.032265179
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.94327298
- specular-whites-relativeChange: -0.033074236
- specular-whites-sampleCount: 26
- whiteClippingPercent: 5.7682037
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **PASS** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Neutral-saturation hue preservation [quality heuristic]: Max RGB/sum(RGB) component drift below .001 on controlled color patches; independent of brightness scaling.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- **WARN** Historical specular/high-end vs deep-shadow relative response [quality heuristic]: Relative change = (mean output − mean input)/mean input. Historical shadow [0,.1] and high-end [.9,1] ramps; for Low Key this is specular/high-end response, not a general highlights contract. WARN retained for historical comparison.
- **PASS** Known black and white endpoints [hard invariant]: Neutral 0 and 1 patches remain exactly 0 and 1 without glow, within 2e-6 linear RGB.
- Historical ramp metrics retained: shadows [0,.10], midtones [.40,.60], specular/high-end response [.90,1]. The latter is not a general highlights measure. New photographic zones are reported separately; [.90,.95] is an intentionally unclassified transition.
- WARN: no reviewed golden configured
- [LowKey/03_strong_dynamic.png](LowKey/03_strong_dynamic.png)
- [LowKey/03_strong_dynamic_difference_x4.png](LowKey/03_strong_dynamic_difference_x4.png)
- [LowKey/03_strong_dynamic_transfer_curve.png](LowKey/03_strong_dynamic_transfer_curve.png)

## LK04_protected — PASS

- additionalChannelClippingPercent: 0
- blackClippingPercent: 4.2480469
- bright-tones-absoluteChange: -0.14126162
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.63368945
- bright-tones-relativeChange: -0.18228457
- bright-tones-sampleCount: 127
- deep-shadows-absoluteChange: -0.011766857
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.038135295
- deep-shadows-relativeChange: -0.23579859
- deep-shadows-sampleCount: 52
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- legacy-specular-high-end-response-relativeChange: -0.036021891
- maxAdjacentRampStep: 0.0075491667
- maxColorPatchChromaticityDrift: 1.6861115e-08
- meanInput: 0.48542271
- meanOutput: 0.399642
- midtones-absoluteChange: -0.16310781
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.31243035
- midtones-relativeChange: -0.34299625
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 4.9137115
- protectedNearEndpointChange: -0.00059987977
- ramp-midtones-relativeChange: -0.34272545
- ramp-shadows-relativeChange: -0.23389499
- shadows-absoluteChange: -0.078960335
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.12162675
- shadows-relativeChange: -0.39364615
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.0206458
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.95489236
- specular-whites-relativeChange: -0.021163498
- specular-whites-sampleCount: 26
- unprotectedBlackClippingPixels: 11136
- unprotectedNearEndpointChange: -0.0080983713
- unprotectedWhiteClippingPixels: 15121
- whiteClippingPercent: 5.7682037
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **PASS** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Neutral-saturation hue preservation [quality heuristic]: Max RGB/sum(RGB) component drift below .001 on controlled color patches; independent of brightness scaling.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- **PASS** Protection preserves near-endpoint detail [quality heuristic]: Compare gray .98 for High Key and .02 for Low Key at identical Amount/Dynamic; protected patch should move less even when no pixels clip.
- **PASS** Protection clipping comparison [quality heuristic]: Compare identical settings except protection=0. Equality may be inconclusive when neither output clips.
- **PASS** Known black and white endpoints [hard invariant]: Neutral 0 and 1 patches remain exactly 0 and 1 without glow, within 2e-6 linear RGB.
- Historical ramp metrics retained: shadows [0,.10], midtones [.40,.60], specular/high-end response [.90,1]. The latter is not a general highlights measure. New photographic zones are reported separately; [.90,.95] is an intentionally unclassified transition.
- WARN: no reviewed golden configured
- [LowKey/04_protected.png](LowKey/04_protected.png)
- [LowKey/04_protected_difference_x4.png](LowKey/04_protected_difference_x4.png)
- [LowKey/04_protected_transfer_curve.png](LowKey/04_protected_transfer_curve.png)

## LK05_glow — PASS

- additionalChannelClippingPercent: 0
- blackClippingPercent: 4.0344238
- bright-tones-absoluteChange: -0.075626669
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.6993244
- bright-tones-relativeChange: -0.09758896
- bright-tones-sampleCount: 127
- deep-shadows-absoluteChange: -0.0081687494
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.041733403
- deep-shadows-relativeChange: -0.16369533
- deep-shadows-sampleCount: 52
- flatRampSteps: 0
- inputBlackClippingPercent: 4.2480469
- inputWhiteClippingPercent: 5.7682037
- legacy-specular-high-end-response-relativeChange: -0.015027769
- maxAdjacentRampStep: 0.0046657324
- maxColorPatchChromaticityDrift: 0.13909008
- meanInput: 0.48542271
- meanOutput: 0.43881497
- midtones-absoluteChange: -0.090615449
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.38492271
- midtones-relativeChange: -0.19055348
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- outsideSDRPercent: 4.9137115
- ramp-midtones-relativeChange: -0.18390623
- ramp-shadows-relativeChange: -0.14817238
- shadows-absoluteChange: -0.043885607
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.15670148
- shadows-relativeChange: -0.2187858
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.0087109735
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.96682718
- specular-whites-relativeChange: -0.0089294032
- specular-whites-sampleCount: 26
- whiteClippingPercent: 5.7682037
- **PASS** Finite output [hard invariant]: NaN/Inf pixel count must be zero, including alpha.
- **PASS** Additional SDR channel clipping [quality heuristic]: WARN when >1% of pixels newly reach a channel value of 1. This flags output gamut pressure even when luminance remains below white; existing HDR pixels are subtracted.
- **PASS** Mean tonal direction [quality heuristic]: High Key lifts; Low Key darkens. Includes the fixed HDR source regions.
- **PASS** Ramp monotonicity [quality heuristic]: Derivative reversals below -1e-6; tolerate at most 0.1% of ramp steps (minimum one).
- Historical ramp metrics retained: shadows [0,.10], midtones [.40,.60], specular/high-end response [.90,1]. The latter is not a general highlights measure. New photographic zones are reported separately; [.90,.95] is an intentionally unclassified transition.
- WARN: no reviewed golden configured
- [LowKey/05_glow.png](LowKey/05_glow.png)
- [LowKey/05_glow_difference_x4.png](LowKey/05_glow_difference_x4.png)
- [LowKey/05_glow_transfer_curve.png](LowKey/05_glow_transfer_curve.png)

## LK00_identity — PASS

- identityMaxError: 0
- **PASS** Amount zero identity [hard invariant]: Expected = untouched analytic chart, not an effect render.

## LK_DynamicSweep_000 — PASS

- amount: 0.6
- bright-tones-absoluteChange: -0.074254898
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.70069618
- bright-tones-relativeChange: -0.09581882
- bright-tones-sampleCount: 127
- darkeningCentroid: 0.47921577
- deep-shadows-absoluteChange: -0.018232159
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.031669993
- deep-shadows-relativeChange: -0.36535817
- deep-shadows-sampleCount: 52
- dynamic: 0
- midtones-absoluteChange: -0.1291553
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.34638286
- midtones-relativeChange: -0.27159818
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- shadows-absoluteChange: -0.084722068
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.11586502
- shadows-relativeChange: -0.4223705
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.0040810452
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.97145711
- specular-whites-relativeChange: -0.0041833783
- specular-whites-sampleCount: 26
- **PASS** Only Dynamic varies [hard invariant]: Amount=.60; opacity=1; shadows=.65; lights=.70; contrast/saturation/glow=0; every other field identical.
- **PASS** Finite output [hard invariant]: All RGBA samples must be finite.
- **PASS** Monotone curve / no tonal inversions [hard invariant]: Every adjacent output sample must be nondecreasing, with 1e-6 linear GPU tolerance; no inversion count allowance.
- **PASS** Low Key does not brighten [hard invariant]: Output <= input + 1e-6 over the entire neutral ramp.
- **PASS** Separate specular preservation [quality heuristic]: At fixed lightProtection=.70, [.95,1] may darken less proportionally than [.65,.90]. This does not establish the causal effect of the protection parameter.
- Dynamic=0 is the reference; progression checks start at Dynamic=.25.
- Zones use input linear luminance. AbsoluteChange = mean(output-input), signed linear units. RelativeChange = absoluteChange/mean(input), not mean pixel-wise ratios. [.90,.95] is intentionally excluded from named zones, but included in monotonicity, finiteness, centroid and curves. Near-black relative curve denominator is floored at 1e-6.
- [LowKey/LK_DynamicSweep_000.png](LowKey/LK_DynamicSweep_000.png)

## LK_DynamicSweep_025 — PASS

- amount: 0.6
- bright-tones-absoluteChange: -0.084214664
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.69073641
- bright-tones-relativeChange: -0.10867094
- bright-tones-sampleCount: 127
- darkeningCentroid: 0.50896094
- deep-shadows-absoluteChange: -0.014017329
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.035884823
- deep-shadows-relativeChange: -0.28089629
- deep-shadows-sampleCount: 52
- dynamic: 0.25
- midtones-absoluteChange: -0.11894692
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.35659124
- midtones-relativeChange: -0.25013118
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- shadows-absoluteChange: -0.068692399
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.13189469
- shadows-relativeChange: -0.34245674
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.0089224508
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.96661571
- specular-whites-relativeChange: -0.0091461833
- specular-whites-sampleCount: 26
- **PASS** Only Dynamic varies [hard invariant]: Amount=.60; opacity=1; shadows=.65; lights=.70; contrast/saturation/glow=0; every other field identical.
- **PASS** Finite output [hard invariant]: All RGBA samples must be finite.
- **PASS** Monotone curve / no tonal inversions [hard invariant]: Every adjacent output sample must be nondecreasing, with 1e-6 linear GPU tolerance; no inversion count allowance.
- **PASS** Low Key does not brighten [hard invariant]: Output <= input + 1e-6 over the entire neutral ramp.
- **PASS** Separate specular preservation [quality heuristic]: At fixed lightProtection=.70, [.95,1] may darken less proportionally than [.65,.90]. This does not establish the causal effect of the protection parameter.
- **PASS** Decreasing shadow action: deep-shadows-absoluteChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: deep-shadows-relativeChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: shadows-absoluteChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: shadows-relativeChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Increasing bright-tone action: absoluteChange [quality heuristic]: Compared with the preceding Dynamic step; increase must exceed 1e-6.
- **PASS** Increasing bright-tone action: relativeChange [quality heuristic]: Compared with the preceding Dynamic step; increase must exceed 1e-6.
- **PASS** Darkening moves toward brighter luminance [quality heuristic]: Loss-weighted input-luminance centroid over the FULL [0,1] ramp must move right; includes [.90,.95].
- Zones use input linear luminance. AbsoluteChange = mean(output-input), signed linear units. RelativeChange = absoluteChange/mean(input), not mean pixel-wise ratios. [.90,.95] is intentionally excluded from named zones, but included in monotonicity, finiteness, centroid and curves. Near-black relative curve denominator is floored at 1e-6.
- [LowKey/LK_DynamicSweep_025.png](LowKey/LK_DynamicSweep_025.png)

## LK_DynamicSweep_050 — PASS

- amount: 0.6
- bright-tones-absoluteChange: -0.09417442
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.68077665
- bright-tones-relativeChange: -0.12152305
- bright-tones-sampleCount: 127
- darkeningCentroid: 0.54190465
- deep-shadows-absoluteChange: -0.0098024996
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.040099653
- deep-shadows-relativeChange: -0.19643441
- deep-shadows-sampleCount: 52
- dynamic: 0.5
- midtones-absoluteChange: -0.10873855
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.36679961
- midtones-relativeChange: -0.22866419
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- shadows-absoluteChange: -0.052662731
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.14792435
- shadows-relativeChange: -0.26254298
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.013763866
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.96177429
- specular-whites-relativeChange: -0.014108998
- specular-whites-sampleCount: 26
- **PASS** Only Dynamic varies [hard invariant]: Amount=.60; opacity=1; shadows=.65; lights=.70; contrast/saturation/glow=0; every other field identical.
- **PASS** Finite output [hard invariant]: All RGBA samples must be finite.
- **PASS** Monotone curve / no tonal inversions [hard invariant]: Every adjacent output sample must be nondecreasing, with 1e-6 linear GPU tolerance; no inversion count allowance.
- **PASS** Low Key does not brighten [hard invariant]: Output <= input + 1e-6 over the entire neutral ramp.
- **PASS** Separate specular preservation [quality heuristic]: At fixed lightProtection=.70, [.95,1] may darken less proportionally than [.65,.90]. This does not establish the causal effect of the protection parameter.
- **PASS** Decreasing shadow action: deep-shadows-absoluteChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: deep-shadows-relativeChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: shadows-absoluteChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: shadows-relativeChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Increasing bright-tone action: absoluteChange [quality heuristic]: Compared with the preceding Dynamic step; increase must exceed 1e-6.
- **PASS** Increasing bright-tone action: relativeChange [quality heuristic]: Compared with the preceding Dynamic step; increase must exceed 1e-6.
- **PASS** Darkening moves toward brighter luminance [quality heuristic]: Loss-weighted input-luminance centroid over the FULL [0,1] ramp must move right; includes [.90,.95].
- Zones use input linear luminance. AbsoluteChange = mean(output-input), signed linear units. RelativeChange = absoluteChange/mean(input), not mean pixel-wise ratios. [.90,.95] is intentionally excluded from named zones, but included in monotonicity, finiteness, centroid and curves. Near-black relative curve denominator is floored at 1e-6.
- [LowKey/LK_DynamicSweep_050.png](LowKey/LK_DynamicSweep_050.png)

## LK_DynamicSweep_075 — PASS

- amount: 0.6
- bright-tones-absoluteChange: -0.10413418
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.67081689
- bright-tones-relativeChange: -0.13437517
- bright-tones-sampleCount: 127
- darkeningCentroid: 0.57859215
- deep-shadows-absoluteChange: -0.0055876698
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.044314482
- deep-shadows-relativeChange: -0.11197252
- deep-shadows-sampleCount: 52
- dynamic: 0.75
- midtones-absoluteChange: -0.09853017
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.37700799
- midtones-relativeChange: -0.20719719
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- shadows-absoluteChange: -0.036633062
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.16395402
- shadows-relativeChange: -0.18262922
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.018605271
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.95693289
- specular-whites-relativeChange: -0.019071803
- specular-whites-sampleCount: 26
- **PASS** Only Dynamic varies [hard invariant]: Amount=.60; opacity=1; shadows=.65; lights=.70; contrast/saturation/glow=0; every other field identical.
- **PASS** Finite output [hard invariant]: All RGBA samples must be finite.
- **PASS** Monotone curve / no tonal inversions [hard invariant]: Every adjacent output sample must be nondecreasing, with 1e-6 linear GPU tolerance; no inversion count allowance.
- **PASS** Low Key does not brighten [hard invariant]: Output <= input + 1e-6 over the entire neutral ramp.
- **PASS** Separate specular preservation [quality heuristic]: At fixed lightProtection=.70, [.95,1] may darken less proportionally than [.65,.90]. This does not establish the causal effect of the protection parameter.
- **PASS** Decreasing shadow action: deep-shadows-absoluteChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: deep-shadows-relativeChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: shadows-absoluteChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: shadows-relativeChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Increasing bright-tone action: absoluteChange [quality heuristic]: Compared with the preceding Dynamic step; increase must exceed 1e-6.
- **PASS** Increasing bright-tone action: relativeChange [quality heuristic]: Compared with the preceding Dynamic step; increase must exceed 1e-6.
- **PASS** Darkening moves toward brighter luminance [quality heuristic]: Loss-weighted input-luminance centroid over the FULL [0,1] ramp must move right; includes [.90,.95].
- Zones use input linear luminance. AbsoluteChange = mean(output-input), signed linear units. RelativeChange = absoluteChange/mean(input), not mean pixel-wise ratios. [.90,.95] is intentionally excluded from named zones, but included in monotonicity, finiteness, centroid and curves. Near-black relative curve denominator is floored at 1e-6.
- [LowKey/LK_DynamicSweep_075.png](LowKey/LK_DynamicSweep_075.png)

## LK_DynamicSweep_100 — PASS

- amount: 0.6
- bright-tones-absoluteChange: -0.11409393
- bright-tones-meanInput: 0.77495107
- bright-tones-meanOutput: 0.66085714
- bright-tones-relativeChange: -0.14722727
- bright-tones-sampleCount: 127
- darkeningCentroid: 0.61970005
- deep-shadows-absoluteChange: -0.0013728406
- deep-shadows-meanInput: 0.049902152
- deep-shadows-meanOutput: 0.048529312
- deep-shadows-relativeChange: -0.027510649
- deep-shadows-sampleCount: 52
- dynamic: 1
- midtones-absoluteChange: -0.088321793
- midtones-meanInput: 0.47553816
- midtones-meanOutput: 0.38721637
- midtones-relativeChange: -0.18573019
- midtones-sampleCount: 179
- monotonicityViolations: 0
- nonFinitePixels: 0
- shadows-absoluteChange: -0.020603394
- shadows-meanInput: 0.20058709
- shadows-meanOutput: 0.17998369
- shadows-relativeChange: -0.10271545
- shadows-sampleCount: 102
- specular-whites-absoluteChange: -0.023446686
- specular-whites-meanInput: 0.97553816
- specular-whites-meanOutput: 0.95209147
- specular-whites-relativeChange: -0.024034617
- specular-whites-sampleCount: 26
- **PASS** Only Dynamic varies [hard invariant]: Amount=.60; opacity=1; shadows=.65; lights=.70; contrast/saturation/glow=0; every other field identical.
- **PASS** Finite output [hard invariant]: All RGBA samples must be finite.
- **PASS** Monotone curve / no tonal inversions [hard invariant]: Every adjacent output sample must be nondecreasing, with 1e-6 linear GPU tolerance; no inversion count allowance.
- **PASS** Low Key does not brighten [hard invariant]: Output <= input + 1e-6 over the entire neutral ramp.
- **PASS** Separate specular preservation [quality heuristic]: At fixed lightProtection=.70, [.95,1] may darken less proportionally than [.65,.90]. This does not establish the causal effect of the protection parameter.
- **PASS** Decreasing shadow action: deep-shadows-absoluteChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: deep-shadows-relativeChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: shadows-absoluteChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Decreasing shadow action: shadows-relativeChange [quality heuristic]: Compared with the preceding Dynamic step at identical Amount; reduction must exceed 1e-6.
- **PASS** Increasing bright-tone action: absoluteChange [quality heuristic]: Compared with the preceding Dynamic step; increase must exceed 1e-6.
- **PASS** Increasing bright-tone action: relativeChange [quality heuristic]: Compared with the preceding Dynamic step; increase must exceed 1e-6.
- **PASS** Darkening moves toward brighter luminance [quality heuristic]: Loss-weighted input-luminance centroid over the FULL [0,1] ramp must move right; includes [.90,.95].
- Zones use input linear luminance. AbsoluteChange = mean(output-input), signed linear units. RelativeChange = absoluteChange/mean(input), not mean pixel-wise ratios. [.90,.95] is intentionally excluded from named zones, but included in monotonicity, finiteness, centroid and curves. Near-black relative curve denominator is floored at 1e-6.
- [LowKey/LK_DynamicSweep_100.png](LowKey/LK_DynamicSweep_100.png)
- [LowKey/dynamic_luminance_absolute.png](LowKey/dynamic_luminance_absolute.png)
- [LowKey/dynamic_luminance_relative.png](LowKey/dynamic_luminance_relative.png)
- [LowKey/dynamic_transfer.png](LowKey/dynamic_transfer.png)
- [LowKey/dynamic_contact_sheet.png](LowKey/dynamic_contact_sheet.png)

## Grain_fine — PASS

- chromaVariance: 4.0628907e-09
- edgeP95: 0.0055608749
- edgeRMS: 0.0028301922
- highFrequencyEnergyFraction: 0.69846602
- meanResidual: -2.6994514e-05
- peakFrequencyCyclesPerPixel: 0.4453125
- residualSD: 0.0014503621
- residualVariance: 2.1035501e-06
- spectralCentroidCyclesPerPixel: 0.31627088
- uniform-0.05-residualSD: 0.00052118939
- uniform-0.15-residualSD: 0.0013909152
- uniform-0.3-residualSD: 0.0021044401
- uniform-0.5-residualSD: 0.0017526152
- uniform-0.7-residualSD: 0.00096434599
- uniform-0.85-residualSD: 0.00047530164
- uniform-0.95-residualSD: 0.00016907326
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/fine.png](Grain/fine.png)
- [Grain/fine_difference_x16.png](Grain/fine_difference_x16.png)

## Grain_medium — PASS

- chromaVariance: 1.6809663e-08
- differentSeedRMSE: 0.0041878441
- edgeP95: 0.009989351
- edgeRMS: 0.0051122042
- highFrequencyEnergyFraction: 0.4916195
- meanResidual: -4.9299181e-06
- peakFrequencyCyclesPerPixel: 0.16796875
- repeatMaxError: 0
- residualSD: 0.0029704219
- residualVariance: 8.823406e-06
- seedSDRatio: 0.99831969
- spectralCentroidCyclesPerPixel: 0.25723079
- uniform-0.05-residualSD: 0.0010568056
- uniform-0.15-residualSD: 0.0028429352
- uniform-0.3-residualSD: 0.0043153128
- uniform-0.5-residualSD: 0.0035556653
- uniform-0.7-residualSD: 0.0019796447
- uniform-0.85-residualSD: 0.00098323035
- uniform-0.95-residualSD: 0.00034570229
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Same-seed determinism [hard invariant]: Two executions, same source/settings/seed; tolerance 1e-6.
- **PASS** Different seed changes pattern [hard invariant]: Different seeds must change spatial content.
- **PASS** Seed distribution similarity [quality heuristic]: Residual SD ratio in [0.8,1.2], allowing finite sample variation.
- WARN: no reviewed golden configured
- [Grain/medium.png](Grain/medium.png)
- [Grain/medium_difference_x16.png](Grain/medium_difference_x16.png)

## Grain_large — PASS

- chromaVariance: 4.7825756e-08
- edgeP95: 0.017525047
- edgeRMS: 0.0089127416
- highFrequencyEnergyFraction: 0.55153247
- meanResidual: 2.6809134e-06
- peakFrequencyCyclesPerPixel: 0.07421875
- residualSD: 0.0049849371
- residualVariance: 2.4849598e-05
- spectralCentroidCyclesPerPixel: 0.26875354
- uniform-0.05-residualSD: 0.0017640054
- uniform-0.15-residualSD: 0.0047607246
- uniform-0.3-residualSD: 0.0071816383
- uniform-0.5-residualSD: 0.0059696149
- uniform-0.7-residualSD: 0.0033610364
- uniform-0.85-residualSD: 0.0016424071
- uniform-0.95-residualSD: 0.00058678825
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/large.png](Grain/large.png)
- [Grain/large_difference_x16.png](Grain/large_difference_x16.png)

## Grain_soft — PASS

- chromaVariance: 4.9771923e-09
- edgeP95: 0.0053274333
- edgeRMS: 0.0027463933
- highFrequencyEnergyFraction: 0.50891796
- meanResidual: -2.4199858e-05
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0016023179
- residualVariance: 2.5674227e-06
- spectralCentroidCyclesPerPixel: 0.25914223
- uniform-0.05-residualSD: 0.00057094841
- uniform-0.15-residualSD: 0.0015344352
- uniform-0.3-residualSD: 0.0023308326
- uniform-0.5-residualSD: 0.0019235898
- uniform-0.7-residualSD: 0.0010692165
- uniform-0.85-residualSD: 0.00052779087
- uniform-0.95-residualSD: 0.00018845838
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/soft.png](Grain/soft.png)
- [Grain/soft_difference_x16.png](Grain/soft_difference_x16.png)

## Grain_hardness_medium — PASS

- chromaVariance: 1.5421285e-08
- edgeP95: 0.0093971193
- edgeRMS: 0.0048443095
- highFrequencyEnergyFraction: 0.50883475
- meanResidual: -1.4264506e-05
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0028262282
- residualVariance: 7.9875659e-06
- spectralCentroidCyclesPerPixel: 0.25910935
- uniform-0.05-residualSD: 0.0010069617
- uniform-0.15-residualSD: 0.0027053617
- uniform-0.3-residualSD: 0.004110166
- uniform-0.5-residualSD: 0.0033939427
- uniform-0.7-residualSD: 0.0018859203
- uniform-0.85-residualSD: 0.00093041923
- uniform-0.95-residualSD: 0.00033260285
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/hardness_medium.png](Grain/hardness_medium.png)
- [Grain/hardness_medium_difference_x16.png](Grain/hardness_medium_difference_x16.png)

## Grain_hard — PASS

- chromaVariance: 2.7972376e-08
- edgeP95: 0.01268512
- edgeRMS: 0.0065312191
- highFrequencyEnergyFraction: 0.50939332
- meanResidual: -4.2571911e-06
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0038081138
- residualVariance: 1.4501731e-05
- spectralCentroidCyclesPerPixel: 0.25927141
- uniform-0.05-residualSD: 0.0013567332
- uniform-0.15-residualSD: 0.0036442264
- uniform-0.3-residualSD: 0.005536698
- uniform-0.5-residualSD: 0.0045741966
- uniform-0.7-residualSD: 0.002540995
- uniform-0.85-residualSD: 0.0012532072
- uniform-0.95-residualSD: 0.00044830766
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/hard.png](Grain/hard.png)
- [Grain/hard_difference_x16.png](Grain/hard_difference_x16.png)

## Grain_monochromatic — PASS

- chromaVariance: 1.424766e-08
- edgeP95: 0.0090293288
- edgeRMS: 0.0046557671
- highFrequencyEnergyFraction: 0.50880676
- meanResidual: -1.5272096e-05
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0027163227
- residualVariance: 7.3784088e-06
- spectralCentroidCyclesPerPixel: 0.2591016
- uniform-0.05-residualSD: 0.00096781081
- uniform-0.15-residualSD: 0.0026002485
- uniform-0.3-residualSD: 0.0039504373
- uniform-0.5-residualSD: 0.0032618733
- uniform-0.7-residualSD: 0.0018125884
- uniform-0.85-residualSD: 0.00089427851
- uniform-0.95-residualSD: 0.00031965412
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/monochromatic.png](Grain/monochromatic.png)
- [Grain/monochromatic_difference_x16.png](Grain/monochromatic_difference_x16.png)

## Grain_clumping_zero — PASS

- chromaVariance: 1.097477e-08
- edgeP95: 0.0094626546
- edgeRMS: 0.0049004679
- highFrequencyEnergyFraction: 0.75491699
- meanResidual: -3.4273338e-05
- peakFrequencyCyclesPerPixel: 0.46484375
- residualSD: 0.0023831459
- residualVariance: 5.6793846e-06
- spectralCentroidCyclesPerPixel: 0.333282
- uniform-0.05-residualSD: 0.00084747914
- uniform-0.15-residualSD: 0.0022860013
- uniform-0.3-residualSD: 0.0034624156
- uniform-0.5-residualSD: 0.0028655199
- uniform-0.7-residualSD: 0.0015890284
- uniform-0.85-residualSD: 0.00078243349
- uniform-0.95-residualSD: 0.00028045728
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/clumping_zero.png](Grain/clumping_zero.png)
- [Grain/clumping_zero_difference_x16.png](Grain/clumping_zero_difference_x16.png)

## Grain_clumping_medium — PASS

- chromaVariance: 2.3881777e-08
- edgeP95: 0.010458052
- edgeRMS: 0.0052307992
- highFrequencyEnergyFraction: 0.38977725
- meanResidual: -1.6772093e-07
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0035189487
- residualVariance: 1.2383e-05
- spectralCentroidCyclesPerPixel: 0.22377799
- uniform-0.05-residualSD: 0.0012549114
- uniform-0.15-residualSD: 0.0033598522
- uniform-0.3-residualSD: 0.0051054781
- uniform-0.5-residualSD: 0.0042403999
- uniform-0.7-residualSD: 0.0023433544
- uniform-0.85-residualSD: 0.00115729
- uniform-0.95-residualSD: 0.00041445069
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/clumping_medium.png](Grain/clumping_medium.png)
- [Grain/clumping_medium_difference_x16.png](Grain/clumping_medium_difference_x16.png)

## Grain_clumping_strong — PASS

- chromaVariance: 6.5109157e-08
- edgeP95: 0.016575515
- edgeRMS: 0.0077889012
- highFrequencyEnergyFraction: 0.32685409
- meanResidual: 4.1070952e-05
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0058161006
- residualVariance: 3.3827026e-05
- spectralCentroidCyclesPerPixel: 0.20536346
- uniform-0.05-residualSD: 0.002075288
- uniform-0.15-residualSD: 0.0055439756
- uniform-0.3-residualSD: 0.0084159357
- uniform-0.5-residualSD: 0.0070356384
- uniform-0.7-residualSD: 0.0038637935
- uniform-0.85-residualSD: 0.0019092308
- uniform-0.95-residualSD: 0.00068530201
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/clumping_strong.png](Grain/clumping_strong.png)
- [Grain/clumping_strong_difference_x16.png](Grain/clumping_strong_difference_x16.png)

## Grain_softness_zero — PASS

- chromaVariance: 3.5597275e-08
- edgeP95: 0.015770286
- edgeRMS: 0.0081905071
- highFrequencyEnergyFraction: 0.63682553
- meanResidual: -8.9294451e-06
- peakFrequencyCyclesPerPixel: 0.46875
- residualSD: 0.0042969526
- residualVariance: 1.8463802e-05
- spectralCentroidCyclesPerPixel: 0.29735048
- uniform-0.05-residualSD: 0.0015294769
- uniform-0.15-residualSD: 0.0041208544
- uniform-0.3-residualSD: 0.0062539665
- uniform-0.5-residualSD: 0.0051540055
- uniform-0.7-residualSD: 0.0028696146
- uniform-0.85-residualSD: 0.0014140902
- uniform-0.95-residualSD: 0.00050554732
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/softness_zero.png](Grain/softness_zero.png)
- [Grain/softness_zero_difference_x16.png](Grain/softness_zero_difference_x16.png)

## Grain_softness_strong — PASS

- chromaVariance: 2.9166377e-09
- edgeP95: 0.0035816133
- edgeRMS: 0.0017850757
- highFrequencyEnergyFraction: 0.37732917
- meanResidual: -2.3702963e-05
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0012244282
- residualVariance: 1.4992245e-06
- spectralCentroidCyclesPerPixel: 0.22012037
- uniform-0.05-residualSD: 0.0004366567
- uniform-0.15-residualSD: 0.001168801
- uniform-0.3-residualSD: 0.0017756465
- uniform-0.5-residualSD: 0.0014765658
- uniform-0.7-residualSD: 0.00081489497
- uniform-0.85-residualSD: 0.00040268003
- uniform-0.95-residualSD: 0.00014423925
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/softness_strong.png](Grain/softness_strong.png)
- [Grain/softness_strong_difference_x16.png](Grain/softness_strong_difference_x16.png)

## Grain_response_shadow — PASS

- chromaVariance: 0
- edgeP95: 0
- edgeRMS: 0
- highFrequencyEnergyFraction: 0
- meanResidual: -5.3589044e-06
- peakFrequencyCyclesPerPixel: 0.00390625
- residualSD: 0.00068045686
- residualVariance: 4.6302154e-07
- spectralCentroidCyclesPerPixel: 0
- uniform-0.05-residualSD: 0.0017688516
- uniform-0.15-residualSD: 0.0010464346
- uniform-0.3-residualSD: 0
- uniform-0.5-residualSD: 0
- uniform-0.7-residualSD: 0
- uniform-0.85-residualSD: 0
- uniform-0.95-residualSD: 0
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/response_shadow.png](Grain/response_shadow.png)
- [Grain/response_shadow_difference_x16.png](Grain/response_shadow_difference_x16.png)

## Grain_response_midtone — PASS

- chromaVariance: 5.5355093e-08
- edgeP95: 0.017795831
- edgeRMS: 0.0091784557
- highFrequencyEnergyFraction: 0.50884884
- meanResidual: -5.9338517e-05
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0047271175
- residualVariance: 2.234564e-05
- spectralCentroidCyclesPerPixel: 0.25910588
- uniform-0.05-residualSD: 0.00052069504
- uniform-0.15-residualSD: 0.0043631351
- uniform-0.3-residualSD: 0.0077877168
- uniform-0.5-residualSD: 0.0048172506
- uniform-0.7-residualSD: 0.0010688424
- uniform-0.85-residualSD: 4.3791828e-05
- uniform-0.95-residualSD: 0
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/response_midtone.png](Grain/response_midtone.png)
- [Grain/response_midtone_difference_x16.png](Grain/response_midtone_difference_x16.png)

## Grain_response_highlight — PASS

- chromaVariance: 7.4210197e-11
- edgeP95: 0.0005761981
- edgeRMS: 0.00029706774
- highFrequencyEnergyFraction: 0.50876918
- meanResidual: -1.0355412e-05
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0027370237
- residualVariance: 7.4912989e-06
- spectralCentroidCyclesPerPixel: 0.25909856
- uniform-0.05-residualSD: 0
- uniform-0.15-residualSD: 0
- uniform-0.3-residualSD: 0.00025206961
- uniform-0.5-residualSD: 0.0037923578
- uniform-0.7-residualSD: 0.005680494
- uniform-0.85-residualSD: 0.003877179
- uniform-0.95-residualSD: 0.0014206959
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/response_highlight.png](Grain/response_highlight.png)
- [Grain/response_highlight_difference_x16.png](Grain/response_highlight_difference_x16.png)

## Grain_chromatic — PASS

- chromaVariance: 1.4612174e-07
- edgeP95: 0.0090295569
- edgeRMS: 0.0046557681
- highFrequencyEnergyFraction: 0.508806
- meanResidual: -1.5249658e-05
- peakFrequencyCyclesPerPixel: 0.22265625
- residualSD: 0.0027163235
- residualVariance: 7.3784132e-06
- spectralCentroidCyclesPerPixel: 0.25910148
- uniform-0.05-residualSD: 0.00096781037
- uniform-0.15-residualSD: 0.0026002493
- uniform-0.3-residualSD: 0.0039504374
- uniform-0.5-residualSD: 0.00326188
- uniform-0.7-residualSD: 0.0018125882
- uniform-0.85-residualSD: 0.00089427936
- uniform-0.95-residualSD: 0.0003196545
- **PASS** Finite output [hard invariant]: No non-finite pixels.
- **PASS** Mean residual uniform-0.7 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.05 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.95 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.15 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.5 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.3 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- **PASS** Mean residual uniform-0.85 [quality heuristic]: Heuristic tolerance: .001 linear + 1% of input patch luminance; not an aesthetic score.
- WARN: no reviewed golden configured
- [Grain/chromatic.png](Grain/chromatic.png)
- [Grain/chromatic_difference_x16.png](Grain/chromatic_difference_x16.png)

## Grain_properties — WARN

- zeroAmountMaxError: 0
- **WARN** Size moves energy to lower frequencies [quality heuristic]: Compare normalized radial energy centroids at fixed source dimensions and seed.
- **PASS** Spatial correlation [quality heuristic]: Adjacent residual correlation > .1; distinguishes from independent white noise, not proof of photographic quality.
- **PASS** Hardness changes edge distribution [quality heuristic]: Report high-frequency fraction and edge RMS/P95 separately.
- **PASS** Clumping changes normalized structure [quality heuristic]: Centroid shift > .001 cycles/pixel; a pure amplitude change would not change normalized spectrum.
- **PASS** Softness changes normalized structure [quality heuristic]: Centroid shift > .001 cycles/pixel; alert if this acts mostly as Amount.
- **PASS** Shadow response selectivity [quality heuristic]: Isolated shadow response, others zero.
- **PASS** Midtone response selectivity [quality heuristic]: Response weights operate in sqrt-linear lightness; representative midtone is linear .3.
- **PASS** Highlight response selectivity [quality heuristic]: Isolated highlight response, others zero.
- **PASS** Color grain has measurable chroma [quality heuristic]: Chroma proxy = residual R−G variance on neutral patch.
- **PASS** Color channels remain correlated [quality heuristic]: Pairwise residual RGB correlation > .5; not independent RGB noise.
- **PASS** Amount zero identity [hard invariant]: Expected is the original source, not another renderer output.

## Edges_HighKey — PASS

- MAEFromInput: 0.067942016
- hardEdgeRangeOvershoot: -0
- maximum: 1
- minimum: 0
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.
- **PASS** Hard-edge overshoot [quality heuristic]: Outside [0,1] overshoot > .002 is suspicious on this neutral edge. This does not score intentional glow spread.

## Edges_HighKeyGlow — PASS

- MAEFromInput: 0.070030268
- hardEdgeRangeOvershoot: -0
- maximum: 1
- minimum: 0
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.
- **PASS** Hard-edge overshoot [quality heuristic]: Outside [0,1] overshoot > .002 is suspicious on this neutral edge. This does not score intentional glow spread.

## Edges_LowKey — PASS

- MAEFromInput: 0.051846431
- hardEdgeRangeOvershoot: -0
- maximum: 1
- minimum: 0
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.
- **PASS** Hard-edge overshoot [quality heuristic]: Outside [0,1] overshoot > .002 is suspicious on this neutral edge. This does not score intentional glow spread.

## Edges_LowKeyGlow — PASS

- MAEFromInput: 0.050743708
- hardEdgeRangeOvershoot: -0
- maximum: 1
- minimum: 0
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.
- **PASS** Hard-edge overshoot [quality heuristic]: Outside [0,1] overshoot > .002 is suspicious on this neutral edge. This does not score intentional glow spread.

## Edges_Grain — PASS

- MAEFromInput: 0.0010718238
- hardEdgeRangeOvershoot: -0
- maximum: 1
- minimum: 0
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.
- **PASS** Hard-edge overshoot [quality heuristic]: Outside [0,1] overshoot > .002 is suspicious on this neutral edge. This does not score intentional glow spread.

## Textures_HighKey — PASS

- MAEFromInput: 0.099197131
- maximum: 0.68118227
- minimum: 0.40410849
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.

## Textures_HighKeyGlow — PASS

- MAEFromInput: 0.099197131
- maximum: 0.68118227
- minimum: 0.40410849
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.

## Textures_LowKey — PASS

- MAEFromInput: 0.079664086
- maximum: 0.49477112
- minimum: 0.23580764
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.

## Textures_LowKeyGlow — PASS

- MAEFromInput: 0.079664086
- maximum: 0.49477112
- minimum: 0.23580764
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.

## Textures_Grain — PASS

- MAEFromInput: 0.0017497305
- maximum: 0.60406363
- minimum: 0.2937654
- **PASS** Finite structure output [hard invariant]: No NaN/Inf on edges or fine patterns.

## Mask_highKey — PASS

- insideRMSE: 0.085950032
- outsideMaxError: 0
- **PASS** Inside changes [hard invariant]: Known geometric center is inside the existing radial mask.
- **PASS** Outside unchanged [hard invariant]: Expected outside is the unmodified analytic quadrant source, independently of MaskRenderer.

## Mask_grain — PASS

- insideRMSE: 0.0014954554
- outsideMaxError: 0
- **PASS** Inside changes [hard invariant]: Known geometric center is inside the existing radial mask.
- **PASS** Outside unchanged [hard invariant]: Expected outside is the unmodified analytic quadrant source, independently of MaskRenderer.

## EffectStack_order — PASS

- orderMaxError: 0.003237009
- orderRMSE: 0.00085270481
- **PASS** Order affects output [hard invariant]: Compares two permitted orders, not an expected image.

## Grain_continuity_shadowAmount — PASS

- maximumSDJumpPer1over64Luminance: 0.00098452383
- **PASS** Continuous response envelope [quality heuristic]: Heuristic: residual SD must not jump by > .01 linear across adjacent 1/64 luminance samples. Inspect the full curve for subtler changes.

## Grain_continuity_midtoneAmount — PASS

- maximumSDJumpPer1over64Luminance: 0.00082121967
- **PASS** Continuous response envelope [quality heuristic]: Heuristic: residual SD must not jump by > .01 linear across adjacent 1/64 luminance samples. Inspect the full curve for subtler changes.

## Grain_continuity_highlightAmount — PASS

- maximumSDJumpPer1over64Luminance: 0.00056249133
- **PASS** Continuous response envelope [quality heuristic]: Heuristic: residual SD must not jump by > .01 linear across adjacent 1/64 luminance samples. Inspect the full curve for subtler changes.

## Scenes_portrait — PASS

- bleachBypass-centerMeanChange: -0.011274506
- crossProcessing-centerMeanChange: -0.00051879167
- detailExtractor-centerMeanChange: 6.2253871e-05
- filmEmulation-centerMeanChange: -0.00079334174
- glamourGlow-centerMeanChange: 0.052999812
- grain-centerMeanChange: 5.5450993e-06
- highKey-centerMeanChange: 0.090916885
- lowKey-centerMeanChange: -0.063824935
- proContrast-centerMeanChange: 0.011684218
- silverBW-centerMeanChange: 0.0335313
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: 0.00011728184
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Scenes/portrait.png](Scenes/portrait.png)
- [Scenes/portrait_100percent.png](Scenes/portrait_100percent.png)

## Scenes_landscape — PASS

- bleachBypass-centerMeanChange: -0.010231721
- crossProcessing-centerMeanChange: -0.0010893443
- detailExtractor-centerMeanChange: 8.0253789e-06
- filmEmulation-centerMeanChange: -0.0009582681
- glamourGlow-centerMeanChange: 0.034460327
- grain-centerMeanChange: 1.2647931e-06
- highKey-centerMeanChange: 0.088822065
- lowKey-centerMeanChange: -0.05056175
- proContrast-centerMeanChange: -0.0034435281
- silverBW-centerMeanChange: -0.0021050401
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: 1.1588868e-05
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Scenes/landscape.png](Scenes/landscape.png)
- [Scenes/landscape_100percent.png](Scenes/landscape_100percent.png)

## Scenes_night — PASS

- bleachBypass-centerMeanChange: -0.001156186
- crossProcessing-centerMeanChange: -0.00033046178
- detailExtractor-centerMeanChange: -1.3311584e-06
- filmEmulation-centerMeanChange: -0.00021492331
- glamourGlow-centerMeanChange: 0.0020687079
- grain-centerMeanChange: -6.1831968e-06
- highKey-centerMeanChange: 0.010481731
- lowKey-centerMeanChange: -0.0029918522
- proContrast-centerMeanChange: 0.00011891723
- silverBW-centerMeanChange: 0.00025885443
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: -3.4813694e-06
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Scenes/night.png](Scenes/night.png)
- [Scenes/night_100percent.png](Scenes/night_100percent.png)

## Scenes_still-life — PASS

- bleachBypass-centerMeanChange: -0.012549465
- crossProcessing-centerMeanChange: -0.0010881068
- detailExtractor-centerMeanChange: 5.3216707e-05
- filmEmulation-centerMeanChange: -0.00013644363
- glamourGlow-centerMeanChange: 0.013251273
- grain-centerMeanChange: -2.5783981e-06
- highKey-centerMeanChange: 0.090499277
- lowKey-centerMeanChange: -0.043016714
- proContrast-centerMeanChange: -0.00059941141
- silverBW-centerMeanChange: 0.019285104
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: 7.992281e-05
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Scenes/still-life.png](Scenes/still-life.png)
- [Scenes/still-life_100percent.png](Scenes/still-life_100percent.png)

## Photographs_photo-0 — PASS

- bleachBypass-centerMeanChange: -0.011109574
- crossProcessing-centerMeanChange: -0.0010249927
- detailExtractor-centerMeanChange: 0.0002874434
- filmEmulation-centerMeanChange: -0.00060144297
- glamourGlow-centerMeanChange: 0.032176673
- grain-centerMeanChange: 1.1123881e-05
- highKey-centerMeanChange: 0.087982014
- lowKey-centerMeanChange: -0.050956862
- proContrast-centerMeanChange: 0.00025735528
- silverBW-centerMeanChange: 0.019100103
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: -0.00010179207
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Photographs/photo-0.png](Photographs/photo-0.png)
- [Photographs/photo-0_100percent.png](Photographs/photo-0_100percent.png)

## Photographs_photo-1 — PASS

- bleachBypass-centerMeanChange: -0.005990616
- crossProcessing-centerMeanChange: -0.00081924467
- detailExtractor-centerMeanChange: 7.8850416e-05
- filmEmulation-centerMeanChange: -9.2694622e-06
- glamourGlow-centerMeanChange: 0.0033840283
- grain-centerMeanChange: -1.2194406e-05
- highKey-centerMeanChange: 0.04627684
- lowKey-centerMeanChange: -0.018251707
- proContrast-centerMeanChange: -0.00024696926
- silverBW-centerMeanChange: 0.0074765327
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: 6.916982e-05
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Photographs/photo-1.png](Photographs/photo-1.png)
- [Photographs/photo-1_100percent.png](Photographs/photo-1_100percent.png)

## Photographs_photo-2 — PASS

- bleachBypass-centerMeanChange: -0.0099179091
- crossProcessing-centerMeanChange: -0.00037220067
- detailExtractor-centerMeanChange: 3.5848902e-07
- filmEmulation-centerMeanChange: -0.0017923838
- glamourGlow-centerMeanChange: 0.065255222
- grain-centerMeanChange: 8.2610014e-05
- highKey-centerMeanChange: 0.091694343
- lowKey-centerMeanChange: -0.067956896
- proContrast-centerMeanChange: 0.0053216119
- silverBW-centerMeanChange: 0.016113879
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: -0.0003720672
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Photographs/photo-2.png](Photographs/photo-2.png)
- [Photographs/photo-2_100percent.png](Photographs/photo-2_100percent.png)

## Photographs_photo-3 — PASS

- bleachBypass-centerMeanChange: -0.0031346835
- crossProcessing-centerMeanChange: -0.00047930699
- detailExtractor-centerMeanChange: -2.187319e-05
- filmEmulation-centerMeanChange: -0.0033856306
- glamourGlow-centerMeanChange: 0.021123967
- grain-centerMeanChange: 7.3980068e-06
- highKey-centerMeanChange: 0.0354767
- lowKey-centerMeanChange: -0.020809659
- proContrast-centerMeanChange: 1.7720368e-09
- silverBW-centerMeanChange: 0.025238666
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: -0.00021798909
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Photographs/photo-3.png](Photographs/photo-3.png)
- [Photographs/photo-3_100percent.png](Photographs/photo-3_100percent.png)

## Photographs_photo-4 — PASS

- bleachBypass-centerMeanChange: -0.0015529177
- crossProcessing-centerMeanChange: -0.00029098095
- detailExtractor-centerMeanChange: 0.00017996707
- filmEmulation-centerMeanChange: -0.00021030888
- glamourGlow-centerMeanChange: 0.0022832407
- grain-centerMeanChange: -4.4509276e-07
- highKey-centerMeanChange: 0.013975397
- lowKey-centerMeanChange: -0.0046969946
- proContrast-centerMeanChange: 0.00016578652
- silverBW-centerMeanChange: 0.0030417102
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: -4.4943823e-05
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Photographs/photo-4.png](Photographs/photo-4.png)
- [Photographs/photo-4_100percent.png](Photographs/photo-4_100percent.png)

## Photographs_photo-5 — PASS

- bleachBypass-centerMeanChange: -0.00086853707
- crossProcessing-centerMeanChange: -0.00027013271
- detailExtractor-centerMeanChange: 1.3795705e-05
- filmEmulation-centerMeanChange: -2.5505806e-05
- glamourGlow-centerMeanChange: 1.6140588e-05
- grain-centerMeanChange: 3.8623579e-06
- highKey-centerMeanChange: 0.0074431161
- lowKey-centerMeanChange: -0.0011413617
- proContrast-centerMeanChange: -0.00024893521
- silverBW-centerMeanChange: -0.00096769967
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: 7.2080795e-06
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Photographs/photo-5.png](Photographs/photo-5.png)
- [Photographs/photo-5_100percent.png](Photographs/photo-5_100percent.png)

## Photographs_photo-6 — PASS

- bleachBypass-centerMeanChange: -0.0066802155
- crossProcessing-centerMeanChange: 0.0010806436
- detailExtractor-centerMeanChange: 2.2137935e-05
- filmEmulation-centerMeanChange: -0.0032580972
- glamourGlow-centerMeanChange: 0.10620879
- grain-centerMeanChange: 8.9779832e-05
- highKey-centerMeanChange: 0.08646534
- lowKey-centerMeanChange: -0.083848811
- proContrast-centerMeanChange: -0.00036110549
- silverBW-centerMeanChange: 0.034963751
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: -0.00028255504
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Photographs/photo-6.png](Photographs/photo-6.png)
- [Photographs/photo-6_100percent.png](Photographs/photo-6_100percent.png)

## Photographs_photo-7 — PASS

- bleachBypass-centerMeanChange: -0.0096366439
- crossProcessing-centerMeanChange: -0.00088338936
- detailExtractor-centerMeanChange: 0.00042492243
- filmEmulation-centerMeanChange: -0.0010357643
- glamourGlow-centerMeanChange: 0.035816395
- grain-centerMeanChange: 6.5164742e-05
- highKey-centerMeanChange: 0.083286729
- lowKey-centerMeanChange: -0.050632855
- proContrast-centerMeanChange: 0.0065116927
- silverBW-centerMeanChange: 0.030534603
- silverToning-centerMeanChange: 0
- tonalContrast-centerMeanChange: 4.217776e-05
- **PASS** Finite highKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite lowKey [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite grain [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite tonalContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite detailExtractor [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite glamourGlow [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite bleachBypass [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite proContrast [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite crossProcessing [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite filmEmulation [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverBW [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- **PASS** Finite silverToning [hard invariant]: Central native crop checked numerically; scene quality remains a visual judgment.
- [Photographs/photo-7.png](Photographs/photo-7.png)
- [Photographs/photo-7_100percent.png](Photographs/photo-7_100percent.png)

## Performance_256 — PASS

- height: 256
- millisecondsIncludingReadback: 1.784792
- readbackBytes: 1048576
- width: 256
- Metal CIContext: Apple M2 Pro. Wall time includes allocation/readback, not isolated GPU kernel time. No machine-dependent speed assertion.

## Performance_512 — PASS

- height: 512
- millisecondsIncludingReadback: 3.03575
- readbackBytes: 4194304
- width: 512
- Metal CIContext: Apple M2 Pro. Wall time includes allocation/readback, not isolated GPU kernel time. No machine-dependent speed assertion.

## Performance_1024 — PASS

- height: 1024
- millisecondsIncludingReadback: 12.400792
- readbackBytes: 16777216
- width: 1024
- Metal CIContext: Apple M2 Pro. Wall time includes allocation/readback, not isolated GPU kernel time. No machine-dependent speed assertion.

## Grain_resolution_consistency — WARN

- 1024-grainSDRatio: 1.5653133
- 1024-normalizedRMSE: 0.004480301
- 1024-normalizedSSIM: 0.97960276
- 1024-patternCorrelation: 0.66425786
- 512-grainSDRatio: 1.3130591
- 512-normalizedRMSE: 0.0037546643
- 512-normalizedSSIM: 0.98544121
- 512-patternCorrelation: 0.6710437
- **WARN** Pattern correlation 512 [quality heuristic]: Compare equal photographic fields after Lanczos normalization, not fixed-size native crops. .75 is a diagnostic threshold allowing preview frequency attenuation.
- **PASS** Normalized grain strength 512 [quality heuristic]: SD ratio [0.65,1.5] flags substantial perceived-strength disagreement, independently of spatial alignment.
- **WARN** Pattern correlation 1024 [quality heuristic]: Compare equal photographic fields after Lanczos normalization, not fixed-size native crops. .75 is a diagnostic threshold allowing preview frequency attenuation.
- **WARN** Normalized grain strength 1024 [quality heuristic]: SD ratio [0.65,1.5] flags substantial perceived-strength disagreement, independently of spatial alignment.
- [Grain/resolution_comparison.png](Grain/resolution_comparison.png)

## Real_preview_HQ_export — PASS

- export-milliseconds: 38.256834
- export-width: 1024
- hq-exportCorrelation: 0.99998602
- hq-exportRMSE: 5.8035006e-05
- hq-exportSSIM: 0.99999704
- hq-milliseconds: 24.211916
- hq-width: 1024
- preview-exportCorrelation: 0.96212069
- preview-exportRMSE: 0.0030521668
- preview-exportSSIM: 0.99170452
- preview-milliseconds: 54.492209
- preview-width: 960
- **PASS** preview perceptual agreement [quality heuristic]: Equal-field crops normalized to interactive preview dimensions; SSIM>.95 and correlation>.7 are quality heuristics, not byte-equality assertions.
- **PASS** hq perceptual agreement [quality heuristic]: Equal-field crops normalized to interactive preview dimensions; SSIM>.95 and correlation>.7 are quality heuristics, not byte-equality assertions.
- preview execution path: GPU
- hq execution path: GPU
- [Pipeline/comparison.png](Pipeline/comparison.png)
- [Pipeline/native_crops.png](Pipeline/native_crops.png)

Full patch statistics (mean, M2/count for variance, range, residual, clipping and transfer samples) and structural measurements are in [Reports](Reports/). Performance values include full materialization/readback or the existing preview/export timing, not isolated GPU execution time.
