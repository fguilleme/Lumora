# Beauty V1 — production render paths

RenderEngine interactive/HQ previews and PNG export use identical persisted
Beauty settings. Comparisons resample each result to 256×256 and read it in
extended-linear sRGB; measured MAE includes resampling and PNG conversion.
Timings are macOS wall time, not iPhone interaction latency.

| Case | Preset | Preview/HQ MAE | HQ/export MAE | Nonfinite | Preview ms | HQ ms | Export ms |
|---|---|---:|---:|---:|---:|---:|---:|
| 01_light_skin_pores | natural | 0.003866 | 0.001194 | 0 | 1288.1 | 120.5 | 240.0 |
| 01_light_skin_pores | portrait | 0.003858 | 0.001180 | 0 | 12.7 | 29.5 | 115.8 |
| 01_light_skin_pores | beauty | 0.003847 | 0.001173 | 0 | 12.3 | 28.0 | 113.9 |
| 09_pronounced_dark_circles | portrait | 0.001044 | 0.000634 | 0 | 668.5 | 99.7 | 245.7 |
