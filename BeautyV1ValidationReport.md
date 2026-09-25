# Beauty V1 — final validation

**Status: V1 frozen. 10 PASS, 2 WARN, 0 FAIL.** The accepted Imperfections detector, region grower, blemish repair, Dark Circles, skin/eye/teeth masks, frequency separation and Natural/Portrait/Beauty values were not changed during this pass. No new Beauty feature was added. The [12-portrait corpus](BeautyValidation/FinalV1Run/BeautyValidation/aesthetic_contact_sheet.png) was run **once** with the final production code; each case produced Original, Natural, Portrait and Beauty, native 100% crops and a mask sheet. All 12 had one detected face, the expected 40–60% face width, and zero nonfinite render pixels. The generated [corpus metrics](BeautyValidation/FinalV1Run/BeautyValidationReport.md) and [100% crops](BeautyValidation/FinalV1Run/BeautyValidation/aesthetic_crops_100pct.png) remain diagnostic images, not golden masters.

## Architecture and controls

Beauty is a non-destructive development stage in the existing `RenderEngine`. Vision extracts facial landmarks from an oriented, geometry-adjusted sRGB analysis image bounded to 1024 pixels on its longest side. It builds temporary 8-bit grayscale mattes for skin, eyes, under-eyes, teeth and blemishes; source, optics and geometry determine the analysis-cache key. Slider changes reuse those mattes. The retouched image stays in extended-linear sRGB Core Image/Metal surfaces. The same `BeautyRenderer` processes interactive preview, HQ and export; masks are never persisted in documents, while editable `BeautyState` is.

Visible controls are Amount, Uniformity, Texture, Imperfections, Dark Circles, Eye Brightness, Eye Detail and Teeth. Amount and all controls except Texture span 0–100; Texture spans −100…100. Amount 0 and all-neutral controls bypass Beauty. If no reliable face is detected, Beauty is an identity. There is no face geometry displacement.

| Preset | Amount | Uniformity | Texture | Imperfections | Dark Circles | Eye Brightness | Eye Detail | Teeth |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Natural | 100 | 12 | −4 | 10 | 8 | 7 | 5 | 6 |
| Portrait | 100 | 42 | −8 | 44 | 40 | 25 | 16 | 18 |
| Beauty | 100 | 70 | −15 | 70 | 65 | 42 | 28 | 32 |

The full-corpus change magnitude follows Natural < Portrait < Beauty for each portrait. This establishes distinct output levels, not an automatic quality verdict. At 100% crop inspection, pores, freckles, structural wrinkles and beard detail remain visible; the eye, teeth and under-eye treatments do not show an obvious halo or pure-white result in the generated sheets. The user has already accepted the V1 Imperfections behavior; no aesthetic retuning followed this run.

## Masks and targeted treatments

The skin matte follows the Vision contour and forehead extension with chromatic confidence and exclusions for strong details/features. Eye and under-eye mattes follow landmarks. The open-smile teeth matte uses visible inner lips and conservative low-saturation/light-pixel confidence. The profile test retains one visible eye component instead of a synthetic second eye. Source/mask coordinate alignment, crop and mirror tests passed for the relevant cases. Inspect [all masks](BeautyValidation/FinalV1Run/BeautyValidation/all_masks_contact_sheet.png), [08 teeth](BeautyValidation/FinalV1Run/BeautyValidation/08_open_smile_teeth/masks.png), [10 eyes](BeautyValidation/FinalV1Run/BeautyValidation/10_detailed_eyes/masks.png) and [12 profile](BeautyValidation/FinalV1Run/BeautyValidation/12_profile_face/masks.png).

Imperfections uses skin-relative red-inflammatory seed response, an explainable component-acceptance score and bounded region growth; the repair kernel transfers local low-frequency discrepancy while preserving fine texture. The accepted [component-acceptance report](BeautyValidation/FinalBlemishPass/ComponentAcceptanceFix/ComponentAcceptanceReport.md) documents the chin/cheek lesion recovery and freckle protection. Dark Circles uses a nearby-cheek tonal reference with low-frequency correction and retained high-frequency texture; no renderer or mask change was made here. Eye Brightness/Detail and Teeth remain constrained by their respective mattes and the frozen Metal kernels.

## Final checks

| Check | Result | Evidence |
|---|---|---|
| iOS app build | **PASS** | Xcode 27.0, generic iOS Simulator, `BUILD SUCCEEDED`. |
| Complete photographic corpus | **PASS** | 12 cases × Original/Natural/Portrait/Beauty; 12 comparison and 12 mask sheets; zero nonfinite pixels. |
| Final preset hierarchy and editable state | **PASS** | All 12 corpus rows have increasing change magnitude; preset matching and Custom transition test passed. |
| Masks, teeth, profile and geometry | **PASS** | Coordinate, crop/mirror and profile-eye tests passed; 08 high-saturation teeth-mask fraction was 0 in the targeted check. |
| Imperfections | **PASS** | Accepted V1 result: chin and cheek lesions progressive; freckles and beard protected. |
| Dark Circles, eyes and teeth | **PASS** | Frozen renderers replayed in corpus; 09/10/08 crops generated and inspected at source pixels. |
| Undo/Redo, persistence, old-document migration | **PASS** | Beauty state/history round trip and `{}` legacy-document decoding tests passed; reload does not require stored masks. |
| Identity, HDR and no-face behavior | **PASS** | Neutral/HDR reconstruction, Amount 0, masked finite/local and no-face identity tests passed. |
| Analysis cache and invalidation | **PASS** | Slider-only state reused the same skin mask object; geometry flip rebuilt it. Vision cancellation passed. |
| Preview/HQ/export | **PASS** | [Production-path table](BeautyValidation/FinalV1Run/render_path_consistency.md): 4 configurations, zero nonfinite pixels, normalized Preview/HQ MAE 0.001044–0.003866, HQ/PNG export MAE 0.000634–0.001194. |
| Low-confidence wrinkle selection | **WARN — accepted V1 caveat** | ~2.06% selected in the 05 wrinkle ROI; RGB MAE at 100 was 0.000172 and impact was visually negligible. No tuning performed. |
| Real-iPhone latency | **WARN — measurement pending** | A paired iPhone 15 Pro appeared in Xcode, but `devicectl` reported immediate disconnection after network connection. Cold analysis, cached Beauty-tab interaction and first/subsequent slider motion could not be measured reliably on it. |

## Performance

On Apple Silicon macOS 26.6.2 with Xcode 27.0, the diagnostic corpus measured Vision plus all masks at **1,256 ms median** (range 1,036–1,537 ms) across 12 photos. This run also generated diagnostics, so it is not a device UI latency estimate; blemish-mask analysis was the dominant measured stage (~925–1,285 ms). Portrait render materialization measured **26.4 / 40.3 / 163.0 ms** at long sides 1024 / 2048 / 4096. In the production render-path test, the first 01 preview took **1,288 ms** including analysis, and later preset changes with the cached analysis took **12.7 and 12.3 ms** on this Mac. Export timings in that test include rendering and PNG encoding; see the linked table. No real-iPhone performance number is claimed.

## Known V1 limits and visual review

- The same Beauty settings apply to every detected face; there is no per-face editing.
- No face reshape, makeup or hair retouching is provided.
- A small, low-confidence wrinkle selection can occur without meaningful visible change.
- Real-device cold-analysis and cached-slider latency remain unmeasured because the paired iPhone disconnected.

Priority visual files: [full contact sheet](BeautyValidation/FinalV1Run/BeautyValidation/aesthetic_contact_sheet.png), [100% crops](BeautyValidation/FinalV1Run/BeautyValidation/aesthetic_crops_100pct.png), [all masks](BeautyValidation/FinalV1Run/BeautyValidation/all_masks_contact_sheet.png), [03 acne](BeautyValidation/FinalV1Run/BeautyValidation/03_acne_redness/comparison.png), [04 freckles](BeautyValidation/FinalV1Run/BeautyValidation/04_strong_freckles/comparison.png), [09 dark circles](BeautyValidation/FinalV1Run/BeautyValidation/09_pronounced_dark_circles/comparison.png), [08 teeth](BeautyValidation/FinalV1Run/BeautyValidation/08_open_smile_teeth/comparison.png), and the [Imperfections chin sweep](BeautyValidation/FinalBlemishPass/ComponentAcceptanceFix/Sweeps/03_acne_redness_chin_lesion_100pct.png).
