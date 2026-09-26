# Eye-mask correction and removal of Lip Color

## Changes

- Removed Lip Color from the production UI and production control list. Its stored field remains decodable, but is ignored by identity checks and rendering. Existing hue values cannot silently recolor lips. Lip Saturation, Brightness and Detail are unchanged.
- The previous eye mask was an ellipse expanded by 18% of eye width horizontally and 10% vertically, followed by an outward Gaussian feather. It covered eyelid skin, which the stronger eye controls visibly brightened/sharpened.
- The eye mask now follows the visible Vision landmark polygon, inset to 92% horizontally and 80% vertically. A 1-pixel feather is multiplied by its opening mask, preventing blur from expanding into skin. Missing/profile-occluded eye landmarks have no ellipse fallback.
- Eye control strengths are unchanged from the preceding response pass. Skin/under-eye/teeth/lip masks, presets and all other controls are unchanged.

## Validation

17 focused Beauty tests pass, including a synthetic diamond-shaped eye opening: the iris interior is selected while upper/lower eyelids, lateral skin and an absent second eye remain below 0.001 mask weight. Legacy Lip Color values are tested as render identity at −100/0/+100, with finite HDR values. Persistence, history and production rendering tests pass. Lumora iOS Simulator build succeeds.

Photo 08 (brown eyes) and photo 10 (blue eyes) were rendered at 0/25/50/75/100, with generous surrounding-skin crops. Visual inspection of photo 10 no longer shows the previous bright eyelid patch. The maximum remains deliberately strong inside the eye. Landmark inaccuracies remain possible on other photographs; this is not a claim of universal segmentation accuracy. Device visual confirmation is pending. UI test expectations were updated; UI automation was not rerun in this pass.

## Inspection

Columns: 0 | 25 | 50 | 75 | 100, native-resolution crops.

- [Photo 10: brightness](after/10_detailed_eyes-eyeBrightness.png)
- [Photo 10: detail](after/10_detailed_eyes-eyeDetail.png)
- [Photo 08: brightness](after/08_open_smile_teeth-eyeBrightness.png)
- [Photo 08: detail](after/08_open_smile_teeth-eyeDetail.png)

Earlier hue-response images remain diagnostic history only; that control is no longer available.
