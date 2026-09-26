# Targeted Beauty renderer pass — diagnostic measurements

All rows use the dedicated, unchanged BeautyValidation portraits. Amount is
100; the named control alone is varied. Mask support means weight > 0.01 in
a native 320 × 320 source-pixel crop. RGB MAE and affected fraction (> 0.001
linear RGB) are restricted to this support. ΔY and Δchroma are signed/absolute
changes within that support. Metrics describe, rather than score, appearance.

| Photo | Control | Value | Support % | Mean matte | P95 matte | Affected % | RGB MAE | ΔY | Δchroma | Nonfinite |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 03_acne_redness | blemishes | 0 | 7.46 | 0.274 | 1.000 | 0.00 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 03_acne_redness | blemishes | 25 | 7.46 | 0.274 | 1.000 | 68.43 | 0.004497 | +0.003153 | 0.001689 | 0 |
| 03_acne_redness | blemishes | 50 | 7.46 | 0.274 | 1.000 | 81.58 | 0.008993 | +0.006306 | 0.003364 | 0 |
| 03_acne_redness | blemishes | 75 | 7.46 | 0.274 | 1.000 | 87.46 | 0.013490 | +0.009459 | 0.005023 | 0 |
| 03_acne_redness | blemishes | 100 | 7.46 | 0.274 | 1.000 | 90.78 | 0.017597 | +0.012186 | 0.006402 | 0 |
| 04_strong_freckles | blemishes | 0 | 5.67 | 0.284 | 1.000 | 0.00 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 04_strong_freckles | blemishes | 25 | 5.67 | 0.284 | 1.000 | 39.09 | 0.002132 | +0.001817 | 0.001112 | 0 |
| 04_strong_freckles | blemishes | 50 | 5.67 | 0.284 | 1.000 | 52.98 | 0.004264 | +0.003633 | 0.002221 | 0 |
| 04_strong_freckles | blemishes | 75 | 5.67 | 0.284 | 1.000 | 67.92 | 0.006396 | +0.005450 | 0.003325 | 0 |
| 04_strong_freckles | blemishes | 100 | 5.67 | 0.284 | 1.000 | 77.56 | 0.008196 | +0.006963 | 0.004279 | 0 |
| 05_older_wrinkles | blemishes | 0 | 3.69 | 0.041 | 0.079 | 0.00 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 05_older_wrinkles | blemishes | 25 | 3.69 | 0.041 | 0.079 | 3.10 | 0.000430 | +0.000109 | 0.000359 | 0 |
| 05_older_wrinkles | blemishes | 50 | 3.69 | 0.041 | 0.079 | 21.15 | 0.000860 | +0.000219 | 0.000719 | 0 |
| 05_older_wrinkles | blemishes | 75 | 3.69 | 0.041 | 0.079 | 48.03 | 0.001290 | +0.000328 | 0.001078 | 0 |
| 05_older_wrinkles | blemishes | 100 | 3.69 | 0.041 | 0.079 | 67.00 | 0.001720 | +0.000437 | 0.001438 | 0 |
| 06_beard_moustache | blemishes | 0 | 0.46 | 0.018 | 0.035 | 0.00 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 06_beard_moustache | blemishes | 25 | 0.46 | 0.018 | 0.035 | 0.00 | 0.000327 | +0.000335 | 0.000043 | 0 |
| 06_beard_moustache | blemishes | 50 | 0.46 | 0.018 | 0.035 | 19.33 | 0.000655 | +0.000669 | 0.000087 | 0 |
| 06_beard_moustache | blemishes | 75 | 0.46 | 0.018 | 0.035 | 40.55 | 0.000982 | +0.001004 | 0.000130 | 0 |
| 06_beard_moustache | blemishes | 100 | 0.46 | 0.018 | 0.035 | 56.93 | 0.001309 | +0.001338 | 0.000173 | 0 |
| 09_pronounced_dark_circles | darkCircles | 0 | 30.99 | 0.766 | 1.000 | 0.00 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 09_pronounced_dark_circles | darkCircles | 25 | 30.99 | 0.766 | 1.000 | 79.88 | 0.009372 | +0.009107 | 0.003579 | 0 |
| 09_pronounced_dark_circles | darkCircles | 50 | 30.99 | 0.766 | 1.000 | 89.25 | 0.018745 | +0.018214 | 0.007139 | 0 |
| 09_pronounced_dark_circles | darkCircles | 75 | 30.99 | 0.766 | 1.000 | 92.04 | 0.028117 | +0.027321 | 0.010681 | 0 |
| 09_pronounced_dark_circles | darkCircles | 100 | 30.99 | 0.766 | 1.000 | 93.43 | 0.037489 | +0.036428 | 0.014208 | 0 |
| 01_light_skin_pores | darkCircles | 0 | 35.12 | 0.719 | 1.000 | 0.00 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 01_light_skin_pores | darkCircles | 25 | 35.12 | 0.719 | 1.000 | 73.51 | 0.003210 | +0.001785 | 0.003062 | 0 |
| 01_light_skin_pores | darkCircles | 50 | 35.12 | 0.719 | 1.000 | 85.75 | 0.006420 | +0.003569 | 0.006123 | 0 |
| 01_light_skin_pores | darkCircles | 75 | 35.12 | 0.719 | 1.000 | 92.34 | 0.009631 | +0.005354 | 0.009182 | 0 |
| 01_light_skin_pores | darkCircles | 100 | 35.12 | 0.719 | 1.000 | 94.83 | 0.012841 | +0.007139 | 0.012240 | 0 |
| 02_dark_skin_texture | darkCircles | 0 | 72.25 | 0.747 | 1.000 | 0.00 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 02_dark_skin_texture | darkCircles | 25 | 72.25 | 0.747 | 1.000 | 69.07 | 0.004651 | +0.004226 | 0.003939 | 0 |
| 02_dark_skin_texture | darkCircles | 50 | 72.25 | 0.747 | 1.000 | 81.79 | 0.009302 | +0.008452 | 0.007890 | 0 |
| 02_dark_skin_texture | darkCircles | 75 | 72.25 | 0.747 | 1.000 | 87.07 | 0.013953 | +0.012678 | 0.011848 | 0 |
| 02_dark_skin_texture | darkCircles | 100 | 72.25 | 0.747 | 1.000 | 90.41 | 0.018604 | +0.016905 | 0.015809 | 0 |
| 10_detailed_eyes | darkCircles | 0 | 39.21 | 0.759 | 1.000 | 0.00 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 10_detailed_eyes | darkCircles | 25 | 39.21 | 0.759 | 1.000 | 67.89 | 0.003764 | +0.003163 | 0.001740 | 0 |
| 10_detailed_eyes | darkCircles | 50 | 39.21 | 0.759 | 1.000 | 80.97 | 0.007529 | +0.006326 | 0.003484 | 0 |
| 10_detailed_eyes | darkCircles | 75 | 39.21 | 0.759 | 1.000 | 85.29 | 0.011293 | +0.009490 | 0.005233 | 0 |
| 10_detailed_eyes | darkCircles | 100 | 39.21 | 0.759 | 1.000 | 87.88 | 0.015058 | +0.012653 | 0.006986 | 0 |


For dark circles, the low-frequency cheek gap is the masked mean of
|Y(under-eye blur) − Y(nearby cheek blur)|, before/after. Texture retention
compares mean absolute high-pass luminance within the unchanged under-eye
matte; 1.0 means equal high-frequency amplitude. This is descriptive and
cannot by itself rule out a visible halo.

| Photo | Cheek gap before | Cheek gap after 100 | High-pass retention |
|---|---:|---:|---:|
| 09_pronounced_dark_circles | 0.13051 | 0.09666 | 0.989 |
| 01_light_skin_pores | 0.23903 | 0.23266 | 1.002 |
| 02_dark_skin_texture | 0.08307 | 0.06637 | 1.001 |
| 10_detailed_eyes | 0.08588 | 0.07388 | 1.010 |
