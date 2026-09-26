# Enlarged manual correction: boundary reconstruction

The user reported a visible patch at Size 2, also after leaving Correction. The earlier Core Image ROI fix addressed a real tile inconsistency but did not resolve this photographic defect.

Reproduction uses the production manual renderer and `08_open_smile_teeth.jpg`, with target (0.412, 0.55), source (0.438, 0.557), radius 0.01 / 0.02. These positions are estimated from screenshots, not extracted from the user's saved document. Other Beauty controls are neutral in this isolated reproduction.

The former quadratic LOW reconstruction sampled annuli at 1.3 and 1.8 times the target radius. Enlargement brought the remote samples toward the face/hair boundary. Extrapolation could produce a center brighter than the surrounding skin. A synthetic dark-boundary regression reproduces this: an originally 0.45 center reaches 0.4789424.

LOW reconstruction now uses normalized positive circular Poisson weights on 32 immediate boundary samples at 1.05 radii. This convex combination cannot overshoot the boundary samples. The existing smooth return to target LOW at the edge, mask feather, strength, source texture, texture-energy estimate, presets and Beauty masks remain unchanged. The source ROI correction is retained. The new reconstruction is used only by manual correction; it changes the render of existing manual corrections without changing their persisted settings.

This addresses extrapolation, not arbitrary source suitability: a target crossing a real facial edge or a poorly chosen source can still be inappropriate. Dark detail inside the boundary may remain partially visible. The source's image-edge handling is not changed in this pass.

Validation: 14 focused healing tests pass, including identity, HDR finite values, locality, persistence/history, geometry, native-resolution masks, resizing, texture/source response, tile consistency and the new distant-dark-boundary regression. The new regression fails with the previous renderer and passes after the fix. Original logs are retained.

Inspect `original.png`, `before-size-2.png`, `size-1.png`, `size-2.png`. These are native-resolution crops with no UI overlay. Human verification on the user's iPhone and actual edit state remains necessary.
