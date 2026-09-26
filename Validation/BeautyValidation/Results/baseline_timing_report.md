# Beauty V1 — dedicated photographic corpus

Renderer: production `BeautyRenderer`; working space: extended-linear sRGB float.
Face analysis: Vision on at most 1024-pixel sRGB preview. Sources are framed by the fixed, normalized rectangles in `BeautyValidation/corpus.json`; no pixels are retouched or resampled during corpus preparation. All 320×320 crops use the source's native pixels at 100%, without enlargement. Auto Stress portraits are excluded from photographic quality validation.
No golden masters. These diagnostics require human inspection before any aesthetic tuning; MAE is a change magnitude, not a quality score.

| Case | Framed px | Vision face width | Faces | Natural MAE | Portrait MAE | Beauty MAE | Non-finite | Vision+mask ms | GPU render ms (3 presets) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 01_light_skin_pores | 2400×1353 | 49.7% | 1 | 0.00211 | 0.00251 | 0.00305 | 0 | 1974.8 | 94.9 |
| 02_dark_skin_texture | 2670×3338 | 53.7% | 1 | 0.00199 | 0.00205 | 0.00212 | 0 | 3154.2 | 340.5 |
| 03_acne_redness | 1800×2700 | 51.3% | 1 | 0.00165 | 0.00181 | 0.00200 | 0 | 2289.6 | 141.2 |
| 04_strong_freckles | 2538×2000 | 50.4% | 1 | 0.00226 | 0.00245 | 0.00271 | 0 | 3153.3 | 128.0 |
| 05_older_wrinkles | 1800×1046 | 56.5% | 1 | 0.00362 | 0.00393 | 0.00436 | 0 | 2140.3 | 48.4 |
| 06_beard_moustache | 3000×4500 | 55.9% | 1 | 0.00063 | 0.00090 | 0.00120 | 0 | 2688.1 | 1.8 |
| 07_glasses | 2760×4140 | 55.1% | 1 | 0.00028 | 0.00039 | 0.00053 | 0 | 2647.6 | 1.8 |
| 08_open_smile_teeth | 2070×1380 | 49.8% | 1 | 0.00056 | 0.00086 | 0.00120 | 0 | 2679.0 | 59.6 |
| 09_pronounced_dark_circles | 1950×1098 | 48.5% | 1 | 0.00072 | 0.00127 | 0.00189 | 0 | 1879.2 | 46.1 |
| 10_detailed_eyes | 3000×2042 | 41.0% | 1 | 0.00246 | 0.00258 | 0.00273 | 0 | 2203.0 | 142.0 |
| 11_45_degree_face | 2550×1700 | 54.3% | 1 | 0.00057 | 0.00082 | 0.00111 | 0 | 2692.5 | 102.4 |
| 12_profile_face | 1890×1263 | 55.7% | 1 | 0.00095 | 0.00135 | 0.00181 | 0 | 2276.4 | 57.1 |

## Per-stage analysis timings (ms)

The first pass measures the existing joint skin/eyes/under-eye/teeth raster without changing its math. Vision's face detection and landmark work are currently one request and are therefore reported together until separately instrumented.

| Case | Image preparation | Vision face+landmarks | Geometry/color sample | Joint raster | Blemishes | CGImage conversions | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| 01_light_skin_pores | 10.7 | 97.2 | 0.6 | 1647.6 | 218.0 | 0.4 | 1974.8 |
| 02_dark_skin_texture | 18.9 | 39.3 | 0.4 | 2897.3 | 197.7 | 0.5 | 3154.2 |
| 03_acne_redness | 13.2 | 76.7 | 0.2 | 1962.9 | 236.2 | 0.3 | 2289.6 |
| 04_strong_freckles | 13.5 | 26.5 | 0.4 | 2872.3 | 240.2 | 0.4 | 3153.3 |
| 05_older_wrinkles | 7.0 | 46.6 | 0.6 | 1808.6 | 277.1 | 0.3 | 2140.3 |
| 06_beard_moustache | 45.3 | 25.7 | 0.3 | 2454.7 | 161.7 | 0.3 | 2688.1 |
| 07_glasses | 39.2 | 56.1 | 0.3 | 2401.0 | 150.6 | 0.4 | 2647.6 |
| 08_open_smile_teeth | 9.4 | 41.5 | 0.5 | 2400.1 | 227.2 | 0.3 | 2679.0 |
| 09_pronounced_dark_circles | 7.4 | 14.6 | 0.4 | 1647.5 | 209.0 | 0.3 | 1879.2 |
| 10_detailed_eyes | 14.9 | 18.8 | 0.3 | 1989.2 | 179.3 | 0.3 | 2203.0 |
| 11_45_degree_face | 11.3 | 21.2 | 0.4 | 2395.1 | 264.1 | 0.4 | 2692.5 |
| 12_profile_face | 8.1 | 17.5 | 0.8 | 1957.0 | 292.6 | 0.4 | 2276.4 |

## GPU render by resolution (Portrait preset)

| Long side | GPU materialization ms |
|---:|---:|
| 1024 | 20.7 |
| 2048 | 25.7 |
| 4096 | 100.5 |

Preview/HQ normalized MAE: 0.001601; non-finite: 0. This includes input resampling differences and is a quality diagnostic.

## Corpus and quality status

Twelve dedicated photographs are used; the source links, authors, licenses and fixed framing rectangles are recorded in `BeautyValidation/corpus.json`. The mask sheet and five native 100% crop sheets are generated for every case. All feature labels describe visible photographic content, not verified camera-original status.

No automated framing/detection warnings.

**PASS technical:** finite renders above; neutral identity, HDR reconstruction, no-face identity and persistence remain covered by `BeautyTests`.

**Quality assessment pending:** inspect pores, wrinkles, freckles, beard, glasses, sclera, teeth, acne and under-eyes at 100%. Automated pixel distances do not establish photographic quality. No Beauty renderer, preset or mask algorithm was changed in response to these measurements.

**Priority:** `BeautyValidation/contact_sheet.png`, then `BeautyValidation/03_acne_redness/masks.png`, `BeautyValidation/04_strong_freckles/Crops/blemishes_100pct.png`, `BeautyValidation/05_older_wrinkles/Crops/skin_100pct.png`, `BeautyValidation/08_open_smile_teeth/Crops/teeth_100pct.png`, `BeautyValidation/09_pronounced_dark_circles/Crops/under_eyes_100pct.png`, `BeautyValidation/12_profile_face/masks.png`.