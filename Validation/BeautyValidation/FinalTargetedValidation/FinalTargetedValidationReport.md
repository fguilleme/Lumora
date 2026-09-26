# Beauty V1 — final targeted validation before freeze

Diagnostic pass only. No Beauty renderer, mask algorithm, preset, or production pipeline was changed. The 0/25/50/75/100 sweeps use one isolated control at a time. Numeric results are in [Results/final_targeted_metrics.md](Results/final_targeted_metrics.md).

## Source limitation

The three new dark-circle portraits are **synthetic diagnostic images**, generated for this pass at 1086 × 1448 pixels, then left unedited. They depict light skin with blue-purple circles, dark skin with brown-purple circles, and an older face with bags and circles. Vision detected one face per image; face widths in the analyzed frames are 54.2%, 57.6%, and 60.5%. Synthetic texture and anatomy cannot establish performance on unretouched camera photographs. A real-photo check is still needed before a photographic freeze.

## Dark Circles

| Case | 0 → 100 finding at native 100% | Visual assessment |
|---|---|---|
| 13, light / bluish | Under-eye darkness and blue-purple cast decrease progressively; mean masked luminance rises by 0.022–0.034 across the two crops. | Texture remains visible. No obvious bright patch or halo in these crops. The circles remain present at 100. |
| 14, dark / brown-purple | Darkness decreases progressively; mean masked luminance rises by 0.023–0.028. | Skin retains gradation and texture; no obvious pale patch, halo, or gross skin-tone shift. The result is deliberately moderate. |
| 15, older / bags | Darkness decreases, with asymmetric response between the two sides (mean masked luminance +0.027 versus +0.051 at 100). | Bags, folds, and skin texture remain visible. The brighter side merits human inspection for a local bright patch at 100; no clear halo is visible in the contact crop. |

All three sweeps are progressive and finite in the measured crops; value 0 is pixel-identical in the measured region. Chroma changes are measured, but the visual checks for tone drift, halo, volume, and texture remain qualitative. **No clear visual failure justifies unfreezing Dark Circles in this pass.**

## Imperfections: old/new matte and isolated sweeps

| Region | Classification | Observation |
|---|---|---|
| 03 cheek, prominent red lesion | Covered by the new matte | The large red mark is selected and fades progressively in the sweep. Old matte support was 0.50% of the crop; new support is 2.42%. |
| 03 cheek, diffuse smaller redness | **Missed red lesion**, possible low mask confidence | Several faint marks remain outside the sparse new matte. The overlay alone cannot distinguish low candidate confidence from a later rejection stage. |
| 03 chin, prominent red lesion | **Missed red lesion**, possible mask confidence too low | The visible chin mark is largely outside the new overlay and remains evident at 100. The new matte's 3.48% support is elsewhere in this crop, including near the lip edge. |
| 03 chin, lip boundary | **Other: edge-adjacent selection** | A small selected region lies next to the lip; whether this is texture/edge rejection or candidate leakage cannot be established from the composite matte alone. |
| 04 forehead | **Freckle false positive** | Numerous freckles are selected by the new matte (10.45% crop support versus 0.20% old); the 100 sweep visibly attenuates some. |
| 04 cheek | **Freckle false positive** | A smaller cluster is selected (6.12% support versus 0.10% old) and attenuated in the sweep. |

No distinct **missed dark lesion** can be confirmed in these four chosen crops; that category remains unassessed rather than inferred. The composite mattes do not expose intermediate candidate confidence or texture/edge rejection scores, so those causes are explicitly provisional. The main unresolved aesthetic issue is freckle preservation; no algorithm change was made.

## Inspection order

1. [Dark-circle contact sheet](Results/dark_circle_contact_sheet.png), then the [older left-eye native crop](Results/DarkCircles/15_older_bags_circles_left_100pct.png).
2. [Chin old/new matte at 200%](Results/Imperfections/03_acne_redness_chin_old_new_200pct.png) and [chin sweep at 100%](Results/Imperfections/03_acne_redness_chin_sweep_100pct.png).
3. [Freckle forehead old/new matte at 200%](Results/Imperfections/04_strong_freckles_forehead_old_new_200pct.png) and [forehead sweep at 100%](Results/Imperfections/04_strong_freckles_forehead_sweep_100pct.png).
4. [Cheek old/new matte at 200%](Results/Imperfections/03_acne_redness_cheek_old_new_200pct.png) and [freckle cheek old/new matte at 200%](Results/Imperfections/04_strong_freckles_cheek_old_new_200pct.png).

## Execution

`swift test --disable-sandbox --filter beautyFinalTargetedValidation` passed on macOS with Metal. The test generates all listed sheets and metrics, confirms one detected face per new case, checks finite sampled output, and checks that slider 0 has zero measured RGB difference. An initial sandboxed run could not access a Metal device; the authorized Metal run passed. This is not a device-based or real-camera validation.
