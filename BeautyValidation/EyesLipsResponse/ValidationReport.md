# Eyes and lip hue response validation

Historical pass: Lip Color was subsequently removed, and the eye mask corrected after user inspection. See [current validation](../EyeMaskCorrection/ValidationReport.md).

Scope: Eye Brightness, Eye Detail and Lip Color only. Other Beauty controls, masks, Vision and preset values are unchanged. Existing documents/presets using eye adjustments will render more strongly; there is no persistence schema change.

## Cause and change

- Eye Brightness was capped at a 10% gain before masking. It now reaches +1 EV in midtones at full mask and full strength. Black pupils and white/HDR catchlights are protected by smooth luminance gates. This is deliberately excessive at the endpoint, not a recommended default.
- Eye Detail was 0.12 times the RGB high-frequency residual. It now uses bounded relative luminance detail (gain 0.4–1.6 at maximum), preserving RGB ratios and thus iris hue. The existing blur radius and mask are unchanged.
- Lip Color previously added a tiny red-opponent offset. It now rotates chroma ±60 degrees around the linear luminance axis. Saturation, brightness and detail remain independent and unchanged. Positive values move these natural lips toward magenta/violet; negative extremes can become yellow/green. These extreme looks are intentional endpoint choices, not photographic presets. A chroma scale prevents new negative RGB for non-negative inputs without clamping HDR highlights.

## Measurements at 100

Mean absolute RGB difference measured inside the existing matte (>0.05), extended-linear sRGB. These measurements describe response, not quality.

| Photo | Control | Before | After |
|---|---|---:|---:|
| 08_open_smile_teeth | eyeBrightness | 0.01376 | 0.15912 |
| 08_open_smile_teeth | eyeDetail | 0.00470 | 0.03766 |
| 08_open_smile_teeth | lipColor | 0.01134 | 0.11398 |
| 10_detailed_eyes | eyeBrightness | 0.00453 | 0.08574 |
| 10_detailed_eyes | eyeDetail | 0.00173 | 0.01589 |
| 10_detailed_eyes | lipColor | 0.01166 | 0.08693 |

## Validation

PASS: 16 focused Beauty core tests, including real-photo sweeps, monotone eye response, neutral settings, Amount=0, masked locality, lip luminance preservation, neutral-gray protection, iris RGB-ratio preservation, HDR finite values, persistence/history and production render/export wiring. Lumora iOS Simulator build succeeds.
Visual review: changes are evident in both photo 08 (brown eyes) and photo 10 (blue eyes). At the maximum, eyes can look aggressively bright/sharp and lip color intentionally unnatural. Lower settings remain necessary for natural retouching. The lip mask is unchanged; its current edge/coverage limitations remain visible at exaggerated hues. No new real-device validation or claim of perfect halo absence.

## Comparison sheets

Eyes: columns 0 / 25 / 50 / 75 / 100. Lips: −100 / −50 / 0 / +50 / +100. Crops are native-resolution, without image rescaling. Each file exists under before/ and after/.

- [After: 08_open_smile_teeth / eyeBrightness](after/08_open_smile_teeth-eyeBrightness.png) · [Before](before/08_open_smile_teeth-eyeBrightness.png)
- [After: 08_open_smile_teeth / eyeDetail](after/08_open_smile_teeth-eyeDetail.png) · [Before](before/08_open_smile_teeth-eyeDetail.png)
- [After: 08_open_smile_teeth / lipColor](after/08_open_smile_teeth-lipColor.png) · [Before](before/08_open_smile_teeth-lipColor.png)
- [After: 10_detailed_eyes / eyeBrightness](after/10_detailed_eyes-eyeBrightness.png) · [Before](before/10_detailed_eyes-eyeBrightness.png)
- [After: 10_detailed_eyes / eyeDetail](after/10_detailed_eyes-eyeDetail.png) · [Before](before/10_detailed_eyes-eyeDetail.png)
- [After: 10_detailed_eyes / lipColor](after/10_detailed_eyes-lipColor.png) · [Before](before/10_detailed_eyes-lipColor.png)
