# Beauty V1 — targeted Imperfections and Dark Circles pass

## Scope and implementation

Only the blemish matte/repair and dark-circle renderer were changed. Natural, Portrait and Beauty preset values, the general skin/eye/teeth masks, Vision face geometry, frequency separation, Texture and Teeth renderers were not changed.

**Imperfections.** The old matte required a red excess over eight displaced pixels; it selected only 0.45% of the 03 native crop above 0.01. The new GPU/Core Image matte compares smoothed color and luminance at three spatial scales (1.1, 4 and 11 analysis pixels), gates candidates with the existing skin matte, and attenuates spatially repetitive dark marks using a 34-pixel neighborhood. Its response remains continuous. The repair transfers a bounded, locally estimated low-frequency difference to the original pixel, retaining the original high-frequency component instead of replacing it with blurred pixels. No source pixel is read back to the CPU while adjusting the slider.

**Cernes.** The under-eye mask is unchanged. A low-frequency under-eye estimate is compared with a blurred neighboring cheek reference displaced down by 11% of face width. The renderer applies part of the positive luminance gap plus a bounded chroma correction, then blends through a softened version of the existing under-eye matte. The source pixel's high-frequency component is untouched. The cheek reference follows each photo's local skin color; no global skin tone is prescribed.

## Results

The first full targeted campaign found that the initial matte expansion alone left Imperfections barely perceptible. The final targeted version was re-run and the observations below refer to it. The numbers are descriptive; they do not decide aesthetic quality. All RGB differences below use extended-linear sRGB. The crop is 320 × 320 native source pixels and Amount = 100.

| Check | Status | Observation |
|---|---|---|
| Slider 0 identity, both controls | PASS | RGB MAE = 0 in all eight targeted crops. |
| Finite output | PASS | 0 non-finite pixels in the eight 0/25/50/75/100 sweeps. |
| Blemish progression | PASS | The isolated control rises regularly across 0/25/50/75/100. |
| 03 lesion coverage | WARN | Matte support increased from 0.45% to 7.46% of the native crop. Mean selected weight is 0.274, P95 is 1.0. RGB MAE at 100 is 0.01760 within the selected area, but several prominent cheek marks remain visible in A/B. Inspect before any further adjustment. |
| 04 freckles | WARN | Freckles remain visible in the 100% sheet, while the selected-area RGB MAE is 0.00820 at 100. The detector still responds to some repetitive freckles; a human must judge whether this is acceptable. |
| 05 wrinkles | PASS, visual review pending | At 100, RGB MAE is 0.00172 within the selected area; structural wrinkles remain visible in the sheet. |
| 06 beard/moustache | PASS, visual review pending | Matte support is 0.46%; selected-area RGB MAE is 0.00131 at 100. Hair detail remains visible. |
| 09 dark circles | WARN | The low-frequency gap to neighboring cheek decreases from 0.13051 to 0.09666; high-pass retention is 0.989. The change is visible without flattening the visible texture, but this source is bright and should not be the sole aesthetic reference. |
| 01 / 02 / 10 dark circles | PASS, visual review pending | Low-frequency cheek gaps decrease respectively 0.23903→0.23266, 0.08307→0.06637, and 0.08588→0.07388. High-pass retention is 1.002 / 1.001 / 1.010. The stronger response on dark skin needs direct visual inspection. |
| Preset values | PASS | No preset file was edited. |
| iOS app build | PASS | `xcodebuild` Debug generic iOS, code signing disabled. |
| Beauty test suite | PASS | VisualTestLab and 6 core tests passed, including HDR/identity, masks, Undo/Redo/persistence and the full photographic corpus. The temporary reference-capture test was then removed; the targeted test was re-run successfully. |

The full numerical table is [targeted_metrics.md](../BeautyValidation/TargetedPass/targeted_metrics.md). Existing [response_metrics.md](../BeautyValidation/SliderSweeps/response_metrics.md) covers the seven isolated Beauty controls after this change. The before/after mask sheet includes each source, archived old matte, new matte and overlay; the under-eye mask itself was not modified.

## Priority visual inspection

1. [03 Imperfections — old/new sweep](../BeautyValidation/TargetedPass/BeforeAfter/03_acne_redness_old_vs_new.png)
2. [03 source/old matte/new matte/overlay](../BeautyValidation/TargetedPass/Masks/03_acne_redness.png)
3. [04 freckles at 100%](../BeautyValidation/TargetedPass/Sweeps/04_strong_freckles_blemishes.png)
4. [05 wrinkles at 100%](../BeautyValidation/TargetedPass/Sweeps/05_older_wrinkles_blemishes.png)
5. [06 beard at 100%](../BeautyValidation/TargetedPass/Sweeps/06_beard_moustache_blemishes.png)
6. [09 Cernes — old/new sweep](../BeautyValidation/TargetedPass/BeforeAfter/09_pronounced_dark_circles_old_vs_new.png)
7. [02 dark skin Cernes at 100%](../BeautyValidation/TargetedPass/Sweeps/02_dark_skin_texture_darkCircles.png)

No new second portrait with pronounced circles was added: the existing dedicated corpus contains only one such case. This limits the aesthetic conclusion for Cernes. No preset or renderer tuning followed the final validation campaign.
