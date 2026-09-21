# Creative FX

## Integration

`CreativeEffectStack` is part of `EditState`, including Codable persistence, whole-state history and preset section `creative`. Older documents default to an empty stack. Presets version 2 accept version 1. The stack is limited to 32 effects; duplicates receive a new UUID. Parameter ranges/defaults live in `CreativeEffectCatalog`. Missing effect parameters use defaults. Unknown future effect kinds fail decoding rather than silently discard edits.

An effect references an existing `AdjustmentLayer.id`. `MaskRenderer.makeMask` supplies the same composed, feathered, inverted and opacity-adjusted matte used by local development. Missing, hidden or zero-opacity masks suspend their effects. No duplicate mask representation exists. Presets containing Creative and masks preserve links; Creative-only presets strip links for portability and target the selected layer when applied there. A preset containing masks replaces the global mask composition.

## Pipeline and color

Decode → global WB/exposure/perceptual color LUT → texture/clarity/dehaze → detail → vignette → geometry → ordered local development adjustments → legacy global/local grain → ordered Creative effects → output resize/color conversion.

Creative grain is added at the end by default. Reordering is intentional: any subsequent effect may transform that grain. Existing Effects grain now uses the same `FilmGrainEngine`; enabling both accumulates grain. Moving legacy grain late changes its appearance in older edits, while keeping their scalar setting intact.

Core Image works in extended linear sRGB through the existing Metal CIContext; tagged sRGB/P3 input is converted by Core Image. Key and Glow use linear luminance. Key mixes a smooth standard tone transform with a luminance-dependent dynamic transform, with continuous toe/shoulder protection. It rescales linear RGB to preserve hue, then applies contrast/saturation and effect amount. Dynamic treatment is per-pixel, not a local luminance pyramid. Glow extracts highlights, diffuses energy with an image-relative radius and limits additions by channel headroom. Output retains existing Display P3 preview and export color management. Strong saturation on wide-gamut colors can exceed the output gamut; this is not a new gamut-mapping system.

## Grain

One cached stitchable Metal kernel, compiled via `CIKernel.kernels(withMetalString:)`, serves old Effects grain, Creative grain and future film/B&W renderers. There are no CPU noise textures or per-frame random seeds. The Metal device must support dynamic libraries; kernel failure propagates as a render error.

Integer cell hashing → interpolated spatial field → coarse domain warp → fine/coarse clustered mixture → smooth hardness shaping → continuous shadow/midtone/highlight response → perceptual lightness modulation. Monochrome uses one shared field; color adds a restrained correlated tint field. A small second-order compensation limits mean energy bias; it is an approximation, not a chemical film model.

Coordinates use a 3000-unit photographic long edge. Size maps to 0.7–6 units per cell. Preview footprint attenuation reduces unresolved frequencies, while retaining the same seed and cell locations. This approximates downsampled export, rather than claiming exact pixel equality between independently rendered resolutions. Crops establish a new photographic frame; grain is anchored to the final developed frame.

Amount/hardness/irregularity/clumping/softness/chroma: 0–100; size: 1–100; tone response: 0–200. Defaults are declared in the catalog and `FilmGrainSettings`. Six generic profiles adjust structure while retaining amount, seed and monochrome/color mode. They do not claim commercial film equivalence.

## Preview, tiles and UI

Normal interaction keeps the existing 960px/2048px preview scheduling and coalesced undo. FX bypass is preview-only and is not serialized or exported. The Creative panel supports add, disable, duplicate, reorder, reset, delete, opacity and assignment to existing masks. Simple/Advanced grain is presentation state and never resets parameters.

The 100% inspector builds the full-resolution lazy graph and materializes only a bounded ROI (1024px default, 2048px cap). Grain sees the full frame before ROI cropping. One separate actor/context serializes tile requests and clears caches afterward. Native inspection uses one photo pixel per physical display pixel. It is an explicit inspector; ordinary preview zoom still magnifies the cached preview.

Output allocation is bounded, but the image/RAW decoder or neighborhood filters can still require larger regions/full-source decoding. This is not a guarantee of constant memory on 48MP RAW files. On-device latency and peak-memory profiling remain necessary. Cancellation is checked between graph stages and after rendering; Core Image's synchronous GPU call cannot be preempted mid-call.

## Validation and extension

`CreativeTests` covers migration/round-trip/history, stack identity/ordering, preset links, key direction/endpoints/identity/glow, stable grain/seed, native tile continuity and existing radial mask targeting. Existing core tests exercise the integrated export/development pipeline.

DEBUG builds expose Creative FX Lab from the Creative panel: a grayscale ramp and dark/mid/highlight/color patches, imported test image (bounded to 2048px), Original/High Key/Low Key/Grain comparison, pixel inspection and measured render duration. The normal 100% inspector is the native-source path. The lab is excluded from Release.

To add an effect: add a kind and catalog descriptor, implement `CreativeEffectRendering`, then register it in `CreativeStackRenderer.renderers`. The compositor, history, persistence, mask assignment and parameter UI remain unchanged. New specialized editors can replace the descriptor-generated controls. Shared `GlowRenderer` and `FilmGrainEngine` are available to future B&W/film engines; those future effects are intentionally not implemented.

### Simulator verification

Verified on iPhone 18 Pro / iOS 27 Simulator: High Key visibly changes the photograph, survives application relaunch, and the native inspector displays a source-resolution region. The management row was compacted so Amount and Dynamic are visible in the fixed-height panel; the DEBUG lab moved into Add, and FX bypass now has a visible label. Effect actions have explicit accessibility labels.

`nativeCreativeTileMatchesFullGraphAndHonorsBounds` exercises the public tile API with High Key and grain, checks the 64px output bound, compares its luminance histogram with the matching full-graph crop, and checks bypass. This passed on Metal. Simulator checks do not establish peak-memory or latency behavior on a physical iPhone with 48MP RAW.

`EditorUITests.testCreativeStackAndNativeInspector` passed on the simulator: fixed preview height, adding an effect, changing Amount, restored toolbar, duplicate/undo, opening/closing native inspection, deleting the added effect. Menu tests distinguish the UIKit menu title from an existing same-named effect, because iOS 27 drops SwiftUI menu-item identifiers. The test removes its effect explicitly: accessibility slider adjustment can emit multiple discrete edits, so cleanup must not assume a fixed number of undo commands.
