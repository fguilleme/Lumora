# Histogram clipping overlay — validation

## Interaction and implementation

Holding either histogram for **0.35 s** activates a temporary clipping warning. Releasing hides it through the gesture-state update; a short tap still expands or collapses the histogram. A recognized long press does not also perform the tap. The existing histogram and its endpoint indicators stay above the photograph. VoiceOver continues to announce the histogram's shadow/highlight fractions and now explains the held-press action.

`HistogramClippingOverlay.make(from:)` converts the current rendered preview `CGImage` to the same SDR sRGB8 representation used by `Histogram.compute`. It makes one RGBA mask: blue at pixels with **all RGB channels ≤ 1**, red at pixels with **any RGB channel ≥ 254**; highlight takes priority. The colors use alpha 145/255. The histogram's 0.2% global occupancy rule does not apply to this per-pixel mask. The mask is computed once per image while needed, off MainActor, cached for a repeated press on the same `CGImage`, and invalidated when the rendered image or document changes. A request generation rejects obsolete asynchronous results. No pixels, development state, sidecar, Undo history, histogram bins or export are modified.

The overlay is a SwiftUI image attached directly to the photograph before the canvas scale and offset. It therefore uses the same aspect fit, zoom and pan. Crop, rotation and mirror are already baked into the rendered preview from which the mask is made. The overlay is display-only and ignores hit testing. This version uses a **single CPU preview-resolution conversion per changed image**, not a GPU kernel and not a per-frame readback. A later source/HDR diagnostic could be separate; this implementation makes no RAW clipping claim.

## Checks

| Result | Type | Check and evidence |
| --- | --- | --- |
| PASS | hard | Black uses all three channels ≤ 1; white uses any channel ≥ 254; red wins. Targeted pixel tests. |
| PASS | hard | One clipped pixel remains marked below the histogram's 0.2% indicator threshold. |
| PASS | hard | Uniform black, uniform white, gray ramp, isolated black/white patch and isolated R/G/B highlights. `synthetic_cases.png` and pixel tests. |
| PASS | hard | Crop, 90°/180°/270° rotation and mirror variants generate a mask with the rendered image's exact dimensions and per-pixel classification. |
| PASS | hard | The overlay shares the photograph's aspect-fit, zoom and pan transform and has no hit target. |
| PASS | hard | App UI tests: the photo overlay view appears during a held press in both histogram sizes, disappears on release, held press does not toggle size, and tap does. Existing outside drag leaves the histogram unchanged. A test-only accessibility counter records the view appearance because XCTest's press command is synchronous. |
| PASS | hard | Seven targeted histogram/core regression tests and two histogram UI tests pass; iOS simulator app builds. Histogram implementation and photographic renderer remain untouched. |
| PASS | hard | No permanent document, EditState, Undo, cache or export state introduced; obsolete mask tasks cannot publish after release/image replacement. |
| PASS | quality | `01_dark_indoor_portrait`: blue traces the deep background, hair, clothing and foreground; bright window receives red. |
| PASS | quality | `02_overexposed_beach_portrait`: large bright sky/sea areas receive red; face retains unmarked regions. |
| PASS | quality | `08_high_iso_rainy_night`: small lamp/reflection highlights receive red, deep bicycle/street shadows receive blue. |
| PASS | quality | Compact and expanded diagnostic plates preserve the visible histogram. |
| PASS | performance | On the measured Mac, 35 preview-mask create/release cycles produced 0 B net RSS growth after warm-up. |
| WARN | performance | Device-specific first-activation latency and GPU compositing were not profiled on iPhone. CPU mask and ImageRenderer measurements below are macOS surrogates. |
| WARN | visual inspection | Pixel alignment during live zoom/pan and the strength of the colors need inspection on an iPhone. Structural placement and transformed-image tests pass. |

**Totals: 13 PASS, 2 WARN, 0 FAIL.** The WARN items require visual/device inspection, not changes to histogram thresholds or photo rendering.

## Performance and memory

Measured on Apple M2 Pro/macOS with an optimized (`-O`) diagnostic harness, 12 runs per mask size. The 0.35 s recognition threshold precedes mask work. Median mask calculation: **1.62 ms** for a 960-pixel long-side preview and **7.04 ms** for 2048. The first visible frame is expected after recognition plus the mask calculation and a SwiftUI frame; actual touch-to-pixels latency on iPhone was not measured. Hiding changes transient state immediately on release, with disappearance on the next UI frame.

With a precomputed 960-pixel mask, the macOS ImageRenderer median was **2.4165 ms** without the overlay and **2.4380 ms** with it across six frames; the approximately **0.022 ms** difference is below the precision needed to predict iPhone GPU cost. There is no mask recomputation per active frame. The stored RGBA mask is **2,457,600 B** at 960 long side and **11,182,080 B** at 2048; temporary input/output buffers increase peak work memory while generating it. Warmed RSS stayed at **306,872,320 B** before and after 35 create/release cycles. Detailed figures are in `Validation/HistogramClippingOverlay/measurements.json`.

## SDR and HDR meaning

These marks describe **near clipping in the displayed SDR preview**. A source value above 1 may map to a white SDR preview pixel and appear red even if the original RAW/HDR value was recoverable. The overlay does not diagnose irreversible source clipping and does not modify or inspect extended-linear/HDR data directly.

## Priority visual inspection

1. `Validation/HistogramClippingOverlay/01_shadows.png`
2. `Validation/HistogramClippingOverlay/02_highlights.png`
3. `Validation/HistogramClippingOverlay/08_night.png`
4. `Validation/HistogramClippingOverlay/synthetic_cases.png`
5. `Validation/HistogramClippingOverlay/compact_overlay.png`
6. `Validation/HistogramClippingOverlay/expanded_overlay.png`

On iPhone, additionally hold and release the compact and expanded histograms while zoomed and panned; then repeat after crop, rotation and mirror. The supplied PNGs are diagnostic renders, not Golden Masters.
