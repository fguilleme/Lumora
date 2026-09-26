# Final blemish detector — descriptive measurements

ROI values are native source pixels. Selected-area fraction uses final
matte > 0.01. RGB MAE compares value 100 against value 0 over the entire
ROI, including unselected pixels. These numbers are not a quality score.

| Photo | Region | Mean confidence | P95 confidence | Selected area % | RGB MAE at 100 | Nonfinite |
|---|---|---:|---:|---:|---:|---:|
| 03_acne_redness | cheek lesion | 0.23779 | 1.00000 | 29.13 | 0.015679 | 0 |
| 03_acne_redness | chin lesion | 0.00596 | 0.04804 | 12.80 | 0.000359 | 0 |
| 04_strong_freckles | forehead freckles | 0.04440 | 0.33162 | 10.36 | 0.001488 | 0 |
| 04_strong_freckles | cheek freckles | 0.01340 | 0.00441 | 4.43 | 0.000282 | 0 |
| 05_older_wrinkles | wrinkles | 0.00099 | 0.00000 | 0.99 | 0.000027 | 0 |
| 06_beard_moustache | beard | 0.00000 | 0.00000 | 0.00 | 0.000000 | 0 |
