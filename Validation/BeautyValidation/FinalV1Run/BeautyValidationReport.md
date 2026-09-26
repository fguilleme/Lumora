# Beauty V1 — dedicated photographic corpus

Renderer: production `BeautyRenderer`; working space: extended-linear sRGB float.
Face analysis: Vision on at most 1024-pixel sRGB preview. Sources are framed by the fixed, normalized rectangles in `BeautyValidation/corpus.json`; no pixels are retouched or resampled during corpus preparation. All 320×320 crops use the source's native pixels at 100%, without enlargement. Auto Stress portraits are excluded from photographic quality validation.
No golden masters. These diagnostics require human inspection before any aesthetic tuning; MAE is a change magnitude, not a quality score.

| Case | Framed px | Vision face width | Faces | Natural MAE | Portrait MAE | Beauty MAE | Non-finite | Vision+mask ms | GPU render ms (3 presets) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 01_light_skin_pores | 2400×1353 | 49.7% | 1 | 0.00211 | 0.00307 | 0.00411 | 0 | 1369.5 | 419.4 |
| 02_dark_skin_texture | 2670×3338 | 53.7% | 1 | 0.00200 | 0.00217 | 0.00233 | 0 | 1537.3 | 920.8 |
| 03_acne_redness | 1800×2700 | 51.3% | 1 | 0.00164 | 0.00196 | 0.00228 | 0 | 1308.7 | 197.0 |
| 04_strong_freckles | 2538×2000 | 50.4% | 1 | 0.00229 | 0.00286 | 0.00348 | 0 | 1353.2 | 229.7 |
| 05_older_wrinkles | 1800×1046 | 56.5% | 1 | 0.00369 | 0.00467 | 0.00571 | 0 | 1147.8 | 108.3 |
| 06_beard_moustache | 3000×4500 | 55.9% | 1 | 0.00061 | 0.00111 | 0.00157 | 0 | 1180.6 | 3.0 |
| 07_glasses | 2760×4140 | 55.1% | 1 | 0.00033 | 0.00068 | 0.00099 | 0 | 1252.1 | 2.3 |
| 08_open_smile_teeth | 2070×1380 | 49.8% | 1 | 0.00056 | 0.00119 | 0.00177 | 0 | 1335.7 | 119.8 |
| 09_pronounced_dark_circles | 1950×1098 | 48.5% | 1 | 0.00073 | 0.00196 | 0.00307 | 0 | 1035.5 | 77.8 |
| 10_detailed_eyes | 3000×2042 | 41.0% | 1 | 0.00245 | 0.00269 | 0.00295 | 0 | 1255.9 | 251.2 |
| 11_45_degree_face | 2550×1700 | 54.3% | 1 | 0.00063 | 0.00145 | 0.00217 | 0 | 1256.0 | 205.1 |
| 12_profile_face | 1890×1263 | 55.7% | 1 | 0.00090 | 0.00155 | 0.00220 | 0 | 1167.7 | 90.3 |

## Per-stage analysis timings (ms)

The production Vision request combines face detection and landmarks. Isolated warm probes split them without changing the production request. CI→CG is test-harness image preparation; geometry, exclusions, skin, detail and blemishes are measured in the new vector/Core Image pipeline. Skin and final composition include GPU materialization of cached masks. The diagnostic unprotected/protection masks add overhead only when requested by this test. Stage and total times are wall times but run-to-run frequency/cache variation remains.

| Case | CI→CG | Bitmap prep | Vision combined | Face probe | Landmarks probe | Geometry/cheek | Face raster | Feature exclusions | Detail prep | Skin raster/compose | Final masks | Blemishes | Analysis total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 01_light_skin_pores | 34.8 | 16.2 | 138.7 | 102.1 | 4.5 | 0.6 | 59.0 | 15.2 | 9.5 | 45.3 | 13.6 | 977.2 | 1369.5 |
| 02_dark_skin_texture | 14.5 | 19.3 | 60.3 | 40.0 | 4.5 | 0.5 | 24.6 | 9.7 | 11.9 | 47.0 | 14.5 | 1284.9 | 1537.3 |
| 03_acne_redness | 8.0 | 19.5 | 62.6 | 32.8 | 3.2 | 0.3 | 27.4 | 8.1 | 10.2 | 31.6 | 16.7 | 1081.7 | 1308.7 |
| 04_strong_freckles | 8.2 | 13.5 | 22.4 | 17.2 | 3.8 | 0.4 | 10.3 | 8.5 | 7.3 | 19.4 | 10.7 | 1202.4 | 1353.2 |
| 05_older_wrinkles | 3.2 | 7.6 | 18.3 | 14.0 | 3.5 | 0.6 | 7.5 | 12.7 | 8.9 | 16.2 | 10.4 | 1032.8 | 1147.8 |
| 06_beard_moustache | 2.1 | 48.3 | 28.9 | 9.6 | 5.2 | 0.3 | 10.7 | 8.3 | 6.9 | 19.2 | 8.6 | 1018.8 | 1180.6 |
| 07_glasses | 0.2 | 48.4 | 44.5 | 17.6 | 4.0 | 0.3 | 25.6 | 9.3 | 5.6 | 2.0 | 4.8 | 1056.6 | 1252.1 |
| 08_open_smile_teeth | 4.6 | 10.2 | 30.0 | 15.2 | 4.6 | 0.6 | 22.6 | 13.5 | 5.3 | 36.4 | 10.6 | 1163.8 | 1335.7 |
| 09_pronounced_dark_circles | 3.7 | 7.0 | 16.0 | 10.2 | 3.3 | 0.4 | 11.0 | 8.4 | 4.9 | 20.6 | 14.8 | 925.0 | 1035.5 |
| 10_detailed_eyes | 16.3 | 21.3 | 29.9 | 15.6 | 4.4 | 0.4 | 10.0 | 10.2 | 5.7 | 26.6 | 10.0 | 1103.4 | 1255.9 |
| 11_45_degree_face | 8.7 | 12.2 | 35.5 | 16.7 | 3.6 | 0.4 | 15.2 | 8.2 | 10.0 | 33.2 | 30.6 | 1079.8 | 1256.0 |
| 12_profile_face | 4.2 | 8.9 | 23.0 | 14.7 | 3.3 | 0.9 | 9.2 | 8.6 | 6.7 | 22.7 | 11.4 | 1041.3 | 1167.7 |

| Case | Old mask area % image | New mask area % image | Effective area % image | Effective area / face area | Detail-protected fraction |
|---|---:|---:|---:|---:|---:|
| 01_light_skin_pores | 16.1 | 21.2 | 19.6 | 0.45 | 7.8% |
| 02_dark_skin_texture | 7.7 | 14.9 | 14.4 | 0.62 | 3.2% |
| 03_acne_redness | 6.6 | 9.4 | 9.2 | 0.52 | 2.0% |
| 04_strong_freckles | 10.8 | 14.4 | 14.2 | 0.44 | 1.6% |
| 05_older_wrinkles | 20.4 | 29.5 | 26.2 | 0.48 | 11.4% |
| 06_beard_moustache | 7.5 | 13.0 | 10.6 | 0.51 | 18.5% |
| 07_glasses | 6.7 | 11.5 | 10.8 | 0.53 | 5.5% |
| 08_open_smile_teeth | 13.1 | 15.7 | 15.3 | 0.41 | 2.8% |
| 09_pronounced_dark_circles | 15.1 | 16.7 | 16.3 | 0.39 | 2.2% |
| 10_detailed_eyes | 8.7 | 11.3 | 11.1 | 0.45 | 1.5% |
| 11_45_degree_face | 16.6 | 24.7 | 24.4 | 0.55 | 1.2% |
| 12_profile_face | 19.6 | 31.8 | 31.5 | 0.68 | 0.8% |

## GPU render by resolution (Portrait preset)

| Long side | GPU materialization ms |
|---:|---:|
| 1024 | 26.4 |
| 2048 | 40.3 |
| 4096 | 163.0 |

Preview/HQ normalized MAE: 0.001602; non-finite: 0. This includes input resampling differences and is a quality diagnostic.

## Corpus and quality status

Twelve dedicated photographs are used; the source links, authors, licenses and fixed framing rectangles are recorded in `BeautyValidation/corpus.json`. The mask sheet and five native 100% crop sheets are generated for every case. All feature labels describe visible photographic content, not verified camera-original status.

No automated framing/detection warnings.

**PASS technical:** finite renders above; neutral identity, HDR reconstruction, no-face identity and persistence remain covered by `BeautyTests`.

**Quality assessment:** compare `BeautyValidation/skin_mask_before_after.png` and each 100% skin sheet. The new contour extends forehead, cheeks and chin and reduces local detail weight, but residual leakage near hair, beard or glasses remains a visual WARN. Mask area is descriptive, not an accuracy score. Teeth/profile/coordinate fixes from the prior targeted pass remain in place. No renderer intensity or Beauty preset was retuned.

**Priority:** `BeautyValidation/skin_mask_before_after.png`, `BeautyValidation/all_masks_contact_sheet.png`, `BeautyValidation/02_dark_skin_texture/Skin/forehead_diagnostic.png`, then the per-case Skin/cheek, forehead and chin 100% sheets.