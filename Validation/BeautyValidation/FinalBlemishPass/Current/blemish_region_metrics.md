# Final blemish detector — descriptive measurements

ROI values are native source pixels. Selected-area fraction uses final
matte > 0.01. RGB MAE compares value 100 against value 0 over the entire
ROI, including unselected pixels. These numbers are not a quality score.

| Photo | Region | Mean confidence | P95 confidence | Selected area % | RGB MAE at 100 | Nonfinite |
|---|---|---:|---:|---:|---:|---:|
| 03_acne_redness | cheek lesion | 0.26130 | 1.00000 | 29.77 | 0.018626 | 0 |
| 03_acne_redness | chin lesion | 0.01005 | 0.08848 | 13.65 | 0.000669 | 0 |
| 04_strong_freckles | forehead freckles | 0.04592 | 0.36201 | 10.45 | 0.001540 | 0 |
| 04_strong_freckles | cheek freckles | 0.01412 | 0.01520 | 6.12 | 0.000323 | 0 |
| 05_older_wrinkles | wrinkles | 0.00172 | 0.00588 | 3.69 | 0.000078 | 0 |
| 06_beard_moustache | beard | 0.00016 | 0.00000 | 0.46 | 0.000011 | 0 |
