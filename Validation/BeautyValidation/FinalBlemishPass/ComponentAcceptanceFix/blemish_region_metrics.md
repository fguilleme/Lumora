# Final blemish detector — descriptive measurements

ROI values are native source pixels. Selected-area fraction uses final
matte > 0.01. RGB MAE compares value 100 against value 0 over the entire
ROI, including unselected pixels. These numbers are not a quality score.

| Photo | Region | Mean confidence | P95 confidence | Selected area % | RGB MAE at 100 | Nonfinite |
|---|---|---:|---:|---:|---:|---:|
| 03_acne_redness | cheek lesion | 0.20166 | 0.79142 | 36.78 | 0.012672 | 0 |
| 03_acne_redness | chin lesion | 0.15470 | 0.45466 | 55.58 | 0.004967 | 0 |
| 04_strong_freckles | forehead freckles | 0.00000 | 0.00000 | 0.00 | 0.000000 | 0 |
| 04_strong_freckles | cheek freckles | 0.00181 | 0.00000 | 1.59 | 0.000072 | 0 |
| 05_older_wrinkles | wrinkles | 0.00285 | 0.00000 | 2.06 | 0.000172 | 0 |
| 06_beard_moustache | beard | 0.00000 | 0.00000 | 0.00 | 0.000000 | 0 |
