# Film Emulation vs simple color grading

The diagnostic baselines use constant linear RGB gains (temperature/tint), Core Image global contrast and saturation. They are adjusted to resemble each film broadly, not optimized to maximize or minimize distance. Film Emulation applies exposure before a logarithmic toe/mid/shoulder response, small layer coupling and luminance-dependent saturation.

## Warm Portrait

MAE 0.065285, RMSE 0.214296, SSIM 0.95061. Toe, midtones, shoulder, skin and HDR regional values are in the validation report. [Comparison](FilmEmulation/film_vs_simple_grade_warm_portrait.png).

## Vivid Chrome

MAE 0.058239, RMSE 0.075272, SSIM 0.73614. Toe, midtones, shoulder, skin and HDR regional values are in the validation report. [Comparison](FilmEmulation/film_vs_simple_grade_vivid_chrome.png).
