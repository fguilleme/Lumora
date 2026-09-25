# Final targeted Beauty diagnostics

The three new cases are **synthetic**, generated expressly for this test.
They have not been retouched after generation, but they cannot establish
real-camera photographic performance. Crops are 320 native source pixels;
no upscaling is used for sweep comparisons. Amount = 100; only Dark Circles
varies. ΔY and Δchroma are measured within the cached under-eye matte.

| Case | Face width % | Eye | Slider | Mask support % | RGB MAE | ΔY | Δchroma | Nonfinite |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| 13_light_bluish_circles | 54.2 | left | 0 | 15.61 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 13_light_bluish_circles | 54.2 | left | 25 | 15.61 | 0.008906 | +0.008566 | 0.002963 | 0 |
| 13_light_bluish_circles | 54.2 | left | 50 | 15.61 | 0.017811 | +0.017132 | 0.005935 | 0 |
| 13_light_bluish_circles | 54.2 | left | 75 | 15.61 | 0.026717 | +0.025698 | 0.008917 | 0 |
| 13_light_bluish_circles | 54.2 | left | 100 | 15.61 | 0.035622 | +0.034264 | 0.011907 | 0 |
| 13_light_bluish_circles | 54.2 | right | 0 | 14.95 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 13_light_bluish_circles | 54.2 | right | 25 | 14.95 | 0.005924 | +0.005554 | 0.002726 | 0 |
| 13_light_bluish_circles | 54.2 | right | 50 | 14.95 | 0.011848 | +0.011108 | 0.005465 | 0 |
| 13_light_bluish_circles | 54.2 | right | 75 | 14.95 | 0.017773 | +0.016663 | 0.008215 | 0 |
| 13_light_bluish_circles | 54.2 | right | 100 | 14.95 | 0.023697 | +0.022217 | 0.010976 | 0 |
| 14_dark_brown_purple_circles | 57.6 | left | 0 | 13.90 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 14_dark_brown_purple_circles | 57.6 | left | 25 | 13.90 | 0.006112 | +0.005630 | 0.003882 | 0 |
| 14_dark_brown_purple_circles | 57.6 | left | 50 | 13.90 | 0.012224 | +0.011261 | 0.007770 | 0 |
| 14_dark_brown_purple_circles | 57.6 | left | 75 | 13.90 | 0.018336 | +0.016891 | 0.011665 | 0 |
| 14_dark_brown_purple_circles | 57.6 | left | 100 | 13.90 | 0.024449 | +0.022521 | 0.015563 | 0 |
| 14_dark_brown_purple_circles | 57.6 | right | 0 | 14.11 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 14_dark_brown_purple_circles | 57.6 | right | 25 | 14.11 | 0.007398 | +0.006881 | 0.004196 | 0 |
| 14_dark_brown_purple_circles | 57.6 | right | 50 | 14.11 | 0.014796 | +0.013763 | 0.008403 | 0 |
| 14_dark_brown_purple_circles | 57.6 | right | 75 | 14.11 | 0.022195 | +0.020644 | 0.012617 | 0 |
| 14_dark_brown_purple_circles | 57.6 | right | 100 | 14.11 | 0.029593 | +0.027526 | 0.016837 | 0 |
| 15_older_bags_circles | 60.5 | left | 0 | 15.89 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 15_older_bags_circles | 60.5 | left | 25 | 15.89 | 0.012933 | +0.012678 | 0.002670 | 0 |
| 15_older_bags_circles | 60.5 | left | 50 | 15.89 | 0.025865 | +0.025356 | 0.005343 | 0 |
| 15_older_bags_circles | 60.5 | left | 75 | 15.89 | 0.038798 | +0.038033 | 0.008018 | 0 |
| 15_older_bags_circles | 60.5 | left | 100 | 15.89 | 0.051731 | +0.050711 | 0.010695 | 0 |
| 15_older_bags_circles | 60.5 | right | 0 | 15.83 | 0.000000 | +0.000000 | 0.000000 | 0 |
| 15_older_bags_circles | 60.5 | right | 25 | 15.83 | 0.006897 | +0.006723 | 0.002657 | 0 |
| 15_older_bags_circles | 60.5 | right | 50 | 15.83 | 0.013794 | +0.013445 | 0.005317 | 0 |
| 15_older_bags_circles | 60.5 | right | 75 | 15.83 | 0.020691 | +0.020168 | 0.007981 | 0 |
| 15_older_bags_circles | 60.5 | right | 100 | 15.83 | 0.027588 | +0.026891 | 0.010647 | 0 |

03_acne_redness/cheek: old matte support 0.50%, new matte support 2.42% of native crop.

03_acne_redness/chin: old matte support 0.35%, new matte support 3.48% of native crop.

04_strong_freckles/forehead: old matte support 0.20%, new matte support 10.45% of native crop.

04_strong_freckles/cheek: old matte support 0.10%, new matte support 6.12% of native crop.
