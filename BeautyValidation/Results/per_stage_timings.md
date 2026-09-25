# Beauty V1 — temps par étape

Mac mini M2 Pro, 16 Go ; passage final des douze cas. Les sondes isolées face/landmarks et les estimations par ligne sur 32 sont diagnostiques et ne doivent pas être ajoutées au temps mural.



The production Vision request combines face detection and landmarks. Isolated warm probes below split them without changing the production request. CI→CG measures the preparation of the analysis bitmap in the test harness; CG→mask covers the five grayscale CGImage conversions. The skin/eyes/under-eye/teeth columns in the second table are *32× extrapolations from every 32nd raster row*: diagnostic estimates including clock overhead, not additive wall times. The joint raster and total columns are actual wall times.

| Case | CI→CG | Bitmap prep | Vision combined | Face detect probe | Landmarks probe | Geometry/cheek color | Joint raster | Blemishes | CG→mask | Analysis total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 01_light_skin_pores | 12.5 | 11.4 | 84.9 | 58.7 | 3.2 | 0.4 | 1590.0 | 251.0 | 0.3 | 1938.2 |
| 02_dark_skin_texture | 11.3 | 19.4 | 26.4 | 19.9 | 4.1 | 0.5 | 1930.4 | 207.6 | 0.2 | 2184.5 |
| 03_acne_redness | 12.5 | 12.6 | 17.0 | 15.5 | 3.0 | 0.2 | 1479.0 | 152.7 | 0.3 | 1661.9 |
| 04_strong_freckles | 10.8 | 13.1 | 25.2 | 15.3 | 4.1 | 0.4 | 1759.5 | 239.4 | 0.5 | 2038.1 |
| 05_older_wrinkles | 4.2 | 7.0 | 16.9 | 11.8 | 5.7 | 0.6 | 1286.0 | 271.3 | 0.3 | 1582.1 |
| 06_beard_moustache | 0.2 | 42.4 | 22.6 | 12.6 | 3.3 | 0.3 | 1484.0 | 164.4 | 0.1 | 1713.9 |
| 07_glasses | 0.2 | 43.0 | 26.6 | 11.5 | 5.6 | 0.2 | 1487.7 | 152.7 | 0.4 | 1710.6 |
| 08_open_smile_teeth | 3.8 | 9.3 | 18.4 | 14.1 | 3.6 | 0.5 | 1489.3 | 229.0 | 0.3 | 1746.8 |
| 09_pronounced_dark_circles | 3.6 | 7.1 | 14.3 | 13.2 | 3.2 | 0.4 | 1239.1 | 210.7 | 0.2 | 1471.9 |
| 10_detailed_eyes | 7.7 | 15.7 | 18.4 | 18.8 | 4.1 | 0.3 | 1523.5 | 185.0 | 0.3 | 1743.3 |
| 11_45_degree_face | 5.8 | 11.4 | 22.4 | 13.4 | 3.7 | 0.4 | 1491.8 | 274.0 | 0.3 | 1800.3 |
| 12_profile_face | 3.9 | 8.4 | 16.8 | 11.7 | 3.4 | 0.8 | 1312.5 | 300.6 | 0.3 | 1639.5 |

| Case | Color sampling estimate | Skin mask estimate | Eyes estimate | Under-eyes estimate | Teeth estimate |
|---|---:|---:|---:|---:|---:|
| 01_light_skin_pores | 10.3 | 611.4 | 110.2 | 98.7 | 10.3 |
| 02_dark_skin_texture | 12.8 | 767.2 | 145.0 | 130.2 | 18.3 |
| 03_acne_redness | 10.5 | 600.7 | 120.8 | 107.4 | 10.9 |
| 04_strong_freckles | 13.9 | 730.0 | 147.1 | 129.1 | 19.8 |
| 05_older_wrinkles | 9.5 | 532.1 | 106.9 | 96.2 | 9.6 |
| 06_beard_moustache | 10.8 | 599.4 | 120.1 | 107.0 | 14.9 |
| 07_glasses | 10.9 | 600.9 | 119.2 | 106.3 | 15.0 |
| 08_open_smile_teeth | 11.3 | 624.2 | 125.0 | 109.9 | 16.9 |
| 09_pronounced_dark_circles | 9.3 | 534.1 | 106.1 | 94.4 | 9.7 |
| 10_detailed_eyes | 10.9 | 626.4 | 124.4 | 110.6 | 11.5 |
| 11_45_degree_face | 10.9 | 615.9 | 123.7 | 110.1 | 15.8 |
| 12_profile_face | 10.8 | 526.4 | 62.5 | 55.8 | 11.3 |
