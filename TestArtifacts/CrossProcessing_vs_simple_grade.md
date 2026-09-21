# Cross Processing vs simple color grading

Baseline: constant linear RGB gains (R 1.055, G 1.005, B 0.950), followed by Core Image saturation 1.025 and contrast 1.045. These settings approximately warm the chart. Cross Processing instead uses three different analytic tone curves and luminance-dependent shadow/highlight chromatic shaping. The measured MAE is 0.029868 in the linear chart; this diagnostic does not imply either result is aesthetically superior.

[Visual comparison](CrossProcessing/cross_vs_simple_grade.png)