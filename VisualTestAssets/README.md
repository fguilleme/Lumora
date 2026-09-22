# Photographic validation assets

Source photographs remain local: do not commit them or copy them into the app/test bundle.

## Fixed eight-image corpus

The Silver B&W and Silver Toning campaigns require exactly these eight PNG files in this directory:

1. `01_portrait_light_skin.png`
2. `02_portrait_dark_skin.png`
3. `03_landscape_clouds.png`
4. `04_backlight.png`
5. `05_night.png`
6. `06_indoor_high_contrast.png`
7. `07_white_subject.png`
8. `08_fine_texture.png`

Use the existing project corpus. Do not silently substitute images: ROI coordinates, contact sheets and source SHA-256 records depend on these photographs. A clone without these local assets can run core/synthetic-only tests, but cannot reproduce the Silver photographic campaigns. `LUMORA_VISUAL_ASSETS` does not override their fixed directory.

## Optional generic assets

The generic visual lab can additionally read PNG, JPEG, TIFF, HEIC and DNG photographs from a separate directory selected with `LUMORA_VISUAL_ASSETS=/absolute/path`. Missing optional photographs do not prevent its synthetic checks; unreadable optional files produce warnings. Keep optional additions separate from the fixed eight-PNG corpus.

Generated contact sheets contain the photographs. Silver reports use the descriptive corpus filenames and retain source hashes. See [validation commands and output conventions](../Docs/VISUAL_VALIDATION.md).
