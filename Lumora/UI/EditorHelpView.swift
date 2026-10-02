import SwiftUI

/// Read-only, offline guidance for the editor's existing tools.
struct EditorHelpView: View {
    @State private var selectedTopic: EditorHelpTopic?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Help")
                    .font(.title3.weight(.semibold))
                    .padding(.bottom, 2)
                Text("Start with common gestures, then choose a tab to learn its controls. Help does not change the photo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                ForEach(EditorHelpTopic.allCases) { topic in
                    Button { selectedTopic = topic } label: {
                        HStack(spacing: 12) {
                            Image(systemName: topic.symbol)
                                .font(.system(size: 17))
                                .frame(width: 24)
                                .foregroundStyle(.mint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.title).font(.subheadline.weight(.semibold))
                                Text(NSLocalizedString(topic.summary, comment: "Help topic summary")).font(.caption2).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("help-topic-\(topic.rawValue)")
                    Divider()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("help-controls")
        .sheet(item: $selectedTopic) { topic in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(NSLocalizedString(topic.introduction, comment: "Help topic introduction"))
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(topic.sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title).font(.headline)
                                ForEach(section.items) { item in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name).font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.mint)
                                        Text(item.explanation).font(.subheadline)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("help-detail-\(topic.rawValue)")
                .navigationTitle(topic.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { selectedTopic = nil }
                            .accessibilityIdentifier("help-close")
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct HelpItem: Identifiable {
    let name: String
    let explanation: String
    var id: String { name }
    init(_ name: String, _ explanation: String) {
        self.name = NSLocalizedString(name, comment: "Help item")
        self.explanation = NSLocalizedString(explanation, comment: "Help explanation")
    }
}

private struct HelpSection: Identifiable {
    let title: String
    let items: [HelpItem]
    var id: String { title }
    init(_ title: String, _ items: [HelpItem]) {
        self.title = NSLocalizedString(title, comment: "Help section")
        self.items = items
    }
}

private enum EditorHelpTopic: String, CaseIterable, Identifiable {
    case commonGestures, creative, light, color, curves, colorTools, effects, detail, depthLens, lighting, beauty, optics, geometry, masks, presets, exif, settings, credits
    var id: String { rawValue }

    var title: String {
        switch self {
        case .commonGestures: String(localized: "Common gestures")
        case .creative: String(localized: "Creative")
        case .light: String(localized: "Light")
        case .color: String(localized: "Color")
        case .curves: String(localized: "Curves")
        case .colorTools: String(localized: "Color Tools")
        case .effects: String(localized: "Effects")
        case .detail: String(localized: "Detail")
        case .depthLens: String(localized: "Depth Lens")
        case .lighting: String(localized: "Lighting")
        case .beauty: String(localized: "Beauty")
        case .optics: String(localized: "Optics")
        case .geometry: String(localized: "Geometry")
        case .masks: String(localized: "Masks")
        case .presets: String(localized: "Presets")
        case .exif: String(localized: "EXIF")
        case .settings: String(localized: "Settings")
        case .credits: String(localized: "Credits")
        }
    }

    var symbol: String {
        switch self {
        case .commonGestures: "hand.draw"
        case .creative: "sparkles"
        case .light: "sun.max"
        case .color: "slider.horizontal.3"
        case .curves: "point.topleft.down.to.point.bottomright.curvepath"
        case .colorTools: "circle.lefthalf.filled"
        case .effects: "camera.filters"
        case .detail: "triangle"
        case .depthLens: "camera.aperture"
        case .lighting: "lightbulb"
        case .beauty: "face.smiling"
        case .optics: "camera.aperture"
        case .geometry: "crop.rotate"
        case .masks: "circle.dashed.inset.filled"
        case .presets: "slider.horizontal.2.square"
        case .exif: "info.square"
        case .settings: "gearshape"
        case .credits: "info.circle"
        }
    }

    var summary: String {
        switch self {
        case .commonGestures: "Tap, hold, zoom, and use the histogram"
        case .creative: "Photographic effects and looks in a stack"
        case .light: "Exposure and tonal balance"
        case .color: "White balance and color intensity"
        case .curves: "Precise tonal and channel control"
        case .colorTools: "Color Mixer and grading"
        case .effects: "Texture, clarity, dehaze, vignette, grain"
        case .detail: "Sharpening and noise reduction"
        case .depthLens: "Depth of field and focus by touch"
        case .lighting: "Experimental depth-based lighting, off by default"
        case .beauty: "Local, restrained portrait retouching"
        case .optics: "Lens profile and manual corrections"
        case .geometry: "Horizon, perspective, and crop"
        case .masks: "Layers and local adjustments"
        case .presets: "Save and reuse your settings"
        case .exif: "Camera and capture metadata"
        case .settings: "Customize the histogram and tab bar"
        case .credits: "Design, technologies, and acknowledgements"
        }
    }

    var introduction: String {
        switch self {
        case .commonGestures: "These gestures work directly on the photo and its floating histogram. A tool such as the mask brush or curve eyedropper may temporarily use the same area for its own action."
        case .creative: "Creative combines independent effects. Each has its own settings, and its position in the stack changes the result. Built-in looks are editable starting points."
        case .light: "Light controls the overall tonal balance, or that of the selected mask. Start with exposure, protect highlights, then refine shadows, whites, and blacks."
        case .color: "Color controls color cast and intensity. Careful white balance preserves the mood of a deliberately warm or cool scene."
        case .curves: "Curves positions tones precisely and can adjust RGB channels separately. View mode prevents accidental edits while scrolling."
        case .colorTools: "Color Tools contains Color Mixer for colors in the scene and Grading for tonal regions. They change different properties."
        case .effects: "Effects provides finishing adjustments. Texture and Clarity change local contrast; Dehaze, Vignette, and Grain serve different purposes."
        case .detail: "Detail controls sharpening and noise reduction. Examine results at 100%: a reduced preview can hide oversharpening and excessive smoothing."
        case .depthLens: "Depth Lens simulates depth of field from an estimated depth map. It can blur areas in front of and behind the selected focus plane. The original photo is preserved; the effect is off by default."
        case .lighting: "Lighting is an experimental simulation using estimated depth. It is disabled by default, including for existing photos. Enable it explicitly to try it; it does not reconstruct the real scene lighting."
        case .beauty: "Beauty adjusts detected faces without changing their shape. Its masks and frequency separation preserve texture; inspect skin and eyes at 100%."
        case .optics: "Optics corrects lens defects. A manufacturer profile is available only when the RAW exposes a compatible one; manual adjustments remain available otherwise."
        case .geometry: "Geometry changes orientation, perspective, and framing. It changes which part of the photo is visible without altering the source file."
        case .masks: "Masks creates layers for local adjustments. Select a mask here, then use controls in other tabs to edit only its area."
        case .settings: "Settings customizes the editor interface. These preferences are saved on this device and apply to all photos; they do not change the photo or its export."
        case .presets: "Presets saves groups of personal settings for use on other photos. Choose which groups to include when creating one."
        case .exif: "EXIF displays the metadata exposed by the original image: file information, camera and lens, capture settings, location, and authorship when available. It does not modify the photo."
        case .credits: "Lumora is an independent photo editor. This page identifies its creator, the Apple technologies it uses, and the model included for depth estimation."
        }
    }

    var sections: [HelpSection] {
        switch self {
        case .commonGestures:
            return [
                HelpSection("On the photo", [
                    HelpItem("Camera RAW files", "Lumora opens original RAW files from non-Apple cameras when the format and camera are supported by the iOS RAW decoder, including compatible files from Canon, Nikon, Sony, Fujifilm, Panasonic, Olympus, Pentax, and DNG cameras. Import from Files preserves the original file. Photos also requests the original RAW resource before a developed image. Support varies by camera model and iOS version."),
                    HelpItem("Short tap", "Tap the photo once to show it alone full screen. Tap the full-screen photo once to return to the editor."),
                    HelpItem("Lighting", "When experimental Lighting is enabled and its tab is open, a short tap positions the selected light or subject marker. Drag a marker to move it directly. Switch tabs to restore the usual full-screen tap."),
                    HelpItem("Depth Lens focus", "When Depth Lens is enabled and its tab is open, a short tap sets the focus point. Switch to another tab to use the usual full-screen tap."),
                    HelpItem("Double-tap", "Double-tap the photo to reset its zoom and position."),
                    HelpItem("Touch and hold", "Hold a finger on the photo to compare with the original. Release to return to the edited preview."),
                    HelpItem("Pinch and pan", "Pinch to zoom in or out. When zoomed in, drag the photo to inspect another area.")
                ]),
                HelpSection("On the histogram", [
                    HelpItem("Short tap on histogram", "Tap the floating histogram to switch between compact and expanded views. A tap on its clipping indicators also changes the view."),
                    HelpItem("Touch and hold histogram", "Hold the histogram to show near-black areas in blue and near-white areas in red on the SDR preview. Release to hide this temporary overlay."),
                    HelpItem("Drag histogram", "Drag the histogram to move it over the photo. The compact and expanded views remember their positions separately."),
                    HelpItem("Placement", "By default, the compact histogram sits at the left of the photo; the expanded histogram is centered over it.")
                ]),
                HelpSection("On the tab bar", [
                    HelpItem("Open a tab", "Tap an editor tab normally to open it."),
                    HelpItem("Quick tab selection", "Touch and hold any tab, then choose the tab you want to open. The tab order does not change."),
                    HelpItem("Complete organization", "Choose Manage tabs… in the long-press menu, or open Settings, to show or hide tabs and reorder the complete list, including hidden tabs.")
                ])
            ]
        case .creative:
            return [
                HelpSection("Build an effect stack", [
                    HelpItem("Add an effect", "Choose from the catalog. Every effect becomes a separate step; effects run in their displayed order."),
                    HelpItem("Change the order", "Move an effect earlier or later to change the result. Silver B&W before Silver Toning creates a toned print; reversing them can remove the toning color."),
                    HelpItem("Quick actions", "The eye enables or disables a step. Other icons duplicate, delete, reset, or reorder the selected effect."),
                    HelpItem("Opacity and mask", "Opacity controls the effect's strength. Assign an existing mask to limit the effect to part of the photo.")
                ]),
                HelpSection("Each creative filter", [
                    HelpItem("High Key", "Creates a bright, airy image by lifting tones. Dynamic controls tonal shaping; Glow adds a soft luminous veil. Use it for luminous portraits or pale interiors. Preserve blacks keeps an anchor in dark tones; check white fabric and skin so they retain detail."),
                    HelpItem("Low Key", "Builds a darker, more dramatic mood while retaining luminous accents. Adjust Amount and Dynamic first, then Contrast. Shadow and highlight protections moderate the extremes. Useful for stage scenes or side-lit portraits; check that dark hair and clothing stay readable."),
                    HelpItem("Pro Contrast", "Combines color-cast correction, overall contrast correction, and dynamic contrast. Use it to give a flat image more separation before a stylized effect. Increase these controls independently: a deliberate sunset cast should not necessarily be neutralized. Check skin and bright edges."),
                    HelpItem("Tonal Contrast", "Changes local contrast separately in highlights, midtones, and shadows. Positive values bring out structure; negative values soften it. Global sets the overall strength and Radius sets the scale of detail. Useful for clouds, stone, and landscapes; protect extreme tones and avoid harsh skin or edge halos."),
                    HelpItem("Detail Extractor", "Emphasizes or softens fine, medium, and large structures independently. Positive Amount enhances texture; negative Amount softens it. Fine detail affects delicate textures, while larger scales emphasize broader shapes. Useful for architecture and foliage. Inspect at 100% because noise and pores can also become more visible."),
                    HelpItem("Glamour Glow", "Adds a soft glow to brighter areas for a dreamy rendering. Glow sets its strength, Softness its diffusion, and Warmth its color tendency. The highlight threshold selects the luminous areas that feed the glow; protections restrain its effect on extreme tones. Use gently on portraits and inspect eyes and skin texture."),
                    HelpItem("Grain", "Adds a photographic grain texture. Amount controls its presence; Size, Hardness, Irregularity, Clumping, and Softness shape it. Separate tonal controls distribute grain across shadows, midtones, and highlights; Color grain adds chromatic variation. Inspect at 100%. Grain in Effects adds to this grain if both are enabled."),
                    HelpItem("Bleach Bypass", "Creates a dense, less colorful rendering inspired by a silver-retaining film process. Bleach strengthens the silver contribution, Contrast separates tones, and Black density adds weight to shadows. Saturation adjusts the remaining color. Useful for gritty scenes; use highlight roll-off and shadow protection to avoid harsh whites or blocked dark areas."),
                    HelpItem("Cross Processing", "Creates deliberately shifted colors inspired by cross development. Choose a style, then adjust Style strength, Contrast, and Saturation. Shadow and highlight colors can be controlled separately; Lift blacks produces a faded base. Useful for stylized urban or fashion images. Check skin and neutral objects for unwanted color casts."),
                    HelpItem("Film Emulation", "Changes tonal and color response without adding grain. Choose a film style, then dose Film strength and Color response. Exposure, Contrast, Saturation, Highlight roll-off, and Shadow density refine it. Warm Portrait favors warmth; Vivid Chrome is more vivid; Muted Cinema is restrained; Faded Negative lifts the faded mood; Dense Slide is denser. Add Grain separately if wanted."),
                    HelpItem("Silver B&W", "Converts original colors into gray tones. At Amount 100 the result is monochrome; intermediate values retain some color. Film response changes tonal interpretation. The colored photographic filter changes how source colors become gray, without tinting the result. Brightness, Contrast, and Structure refine the print. Add Silver Toning afterward for a colored monochrome."),
                    HelpItem("Silver Toning", "Colors the image according to tonal density; it does not itself convert a color photo to black and white. Place it after Silver B&W for a toned print. Choose selenium, sepia, copper, or another toner, then adjust Strength and Balance. Silver tone affects the image; Paper tone warms or cools light areas. Split Silver allows separate shadow and highlight hues."),
                    HelpItem("Darken / Lighten Center", "Directs attention with independent center and outer exposure. Move the handle onto the subject; a brighter center or darker surround draws the eye. Size, Shape, Rotation, and Feather define the transition. It does not detect the subject automatically. Equal center and outer values change exposure uniformly; watch bright areas when raising either value.")
                ]),
                HelpSection("Choose and refine a look", [
                    HelpItem("Looks and Custom", "A built-in look fills the controls of one effect. Changing a value makes it Custom. Start with one effect, compare with the eye button, then add another only when needed. Opacity blends the entire step with its input; it is separate from the effect’s own Amount."),
                    HelpItem("At 100%", "Use the 100% inspector to judge grain, halos, skin, and fine detail at source resolution. Then return to the full image to judge the overall mood. A strong detail setting can look attractive in a small preview but excessive at full size.")
                ])
            ]
        case .light:
            return [
                HelpSection("Six controls", [
                    HelpItem("Exposure", "Shifts overall brightness in exposure values. Raising it also brightens already light regions; watch the histogram and highlights."),
                    HelpItem("Contrast", "Increases or reduces separation between dark and light values around the midtones. Strong settings may lose subtlety at either end."),
                    HelpItem("Highlights", "Primarily affects bright regions. Lower it to retain detail in clouds, fabric, or reflections that still contain usable information."),
                    HelpItem("Shadows", "Primarily affects dark regions. Opening them reveals detail, but can make noise more apparent."),
                    HelpItem("Whites", "Changes the presence of white and very light tones. It cannot reconstruct detail in pixels that are permanently clipped."),
                    HelpItem("Blacks", "Sets the depth of the darkest tones. Opening them slightly can retain texture; closing them adds weight.")
                ]),
                HelpSection("How to use it", [
                    HelpItem("Auto", "Applies a Core Image Auto baseline before manual edits. The sliders stay editable and do not pretend to represent Core Image filter values. Reset Auto or Undo restores the previous rendering."),
                    HelpItem("Local adjustment", "When a mask is selected, these sliders affect that layer. Select Whole photo to return to the global settings."),
                    HelpItem("Fine adjustment", "Tap a slider's numeric value for a narrower adjustment range. Double-tap the slider or use its reset arrow to restore its default value.")
                ])
            ]
        case .color:
            return [
                HelpSection("Balance and intensity", [
                    HelpItem("Temperature", "Moves white balance toward a cooler or warmer appearance. Use a known gray reference only if it should actually be neutral in the scene."),
                    HelpItem("Tint", "Corrects the green–magenta axis when Temperature alone cannot remove a lighting cast."),
                    HelpItem("Saturation", "Raises or lowers the intensity of all colors. High values can push already vivid colors too far."),
                    HelpItem("Vibrance", "Adjusts color more cautiously in mixed scenes. Always check skin tones and colors near the gamut boundary.")
                ]),
                HelpSection("Auto and local color", [
                    HelpItem("Auto Color", "Applies the same Core Image Auto baseline used in Light and Curves. It is not a separate white-balance proposal."),
                    HelpItem("With Auto Light", "Pressing Auto in another panel refreshes the single shared baseline. It does not stack a second Auto correction."),
                    HelpItem("With a mask", "Color settings can target the active layer. Select Whole photo to adjust the image as a whole.")
                ])
            ]
        case .curves:
            return [
                HelpSection("Read and edit the curve", [
                    HelpItem("Axes", "The horizontal axis is input, from black at left to white at right. The vertical axis is output. Raising a point brightens the corresponding tones."),
                    HelpItem("RGB and channels", "RGB controls the common tonal curve. Red, Green, and Blue adjust channels separately; differences between them can introduce a color cast."),
                    HelpItem("View mode", "The graph is passive: start scrolling over it without moving or creating a point."),
                    HelpItem("Edit mode", "Tap Edit to move points. Tap the graph to add one; use Input and Output for precise placement, then Done to return to passive scrolling."),
                    HelpItem("Eyedropper", "Tap the eyedropper, then explore the photo to locate a tone on the curve. Sampling does not add a point by itself; tap + when you want one."),
                    HelpItem("Delete a point", "Select an interior point and use the trash icon. Endpoints keep their horizontal position, but their output value can change.")
                ]),
                HelpSection("Auto and consistency", [
                    HelpItem("Natural, Balanced, Punchy", "Auto applies a Core Image baseline; it does not generate editable curve points. You can edit the curve afterward."),
                    HelpItem("With Auto Light", "The Auto button in Light, Color and Curves controls one shared Core Image baseline, applied before manual settings."),
                    HelpItem("Undo and redo", "Adding, deleting, or moving a point can be undone. Leaving Edit mode does not change the image.")
                ])
            ]
        case .colorTools:
            return [
                HelpSection("Color Mixer", [
                    HelpItem("Eight ranges", "Red, Orange, Yellow, Green, Aqua, Blue, Purple, and Magenta target color families present in the photo."),
                    HelpItem("Hue", "Moves the chosen color toward neighboring colors. A blue sky, for example, can shift toward aqua or purple."),
                    HelpItem("Saturation", "Changes that family's intensity without applying global saturation to the whole photo."),
                    HelpItem("Luminance", "Brightens or darkens the family. Strong changes may affect separation between sky, vegetation, and subject."),
                    HelpItem("Reset a range", "Restores the current family's three values without changing the other seven.")
                ]),
                HelpSection("Grading", [
                    HelpItem("Tonal regions", "Choose Shadows, Midtones, or Highlights. The wheel controls hue and intensity in that region; luminance has a separate control."),
                    HelpItem("Blending and Balance", "Blending softens or distinguishes transitions between regions. Balance shifts the treatment toward dark or light tones."),
                    HelpItem("Grading presets", "Built-in looks fill only the grading controls. Move the wheel or a slider afterward; the state becomes Custom.")
                ])
            ]
        case .effects:
            return [
                HelpSection("Finishing controls", [
                    HelpItem("Cinematic Glow", "Diffuses bright sources into a luminous halo. Intensity 0 leaves the image unchanged; increase it gradually for a stronger cinematic glow. This control always affects the whole photo, even with a mask selected. Check windows, lamps, skin, and reflections. The upper range protects bright destinations, but the middle range can still increase SDR clipping; compare with the original and inspect the histogram. Reset returns to 0."),
                    HelpItem("Texture", "Strengthens or softens fine detail such as fabric or hair. Negative values reduce detail."),
                    HelpItem("Clarity", "Affects broader local contrast than Texture. High values can harden faces or create overly visible transitions."),
                    HelpItem("Dehaze", "Increases or reduces separation in a hazy scene. It also changes global contrast and slightly affects color; inspect the shadows."),
                    HelpItem("Vignette", "Modulates edge brightness to guide attention. It differs from Lens vignetting, which is meant to correct the lens."),
                    HelpItem("Grain", "Adds a finishing grain texture. Creative also has Film Grain; using both can compound the grain.")
                ]),
                HelpSection("What to check", [
                    HelpItem("At 100%", "Inspect Texture, Clarity, and Grain at full size. A reduced preview can hide an overly strong result."),
                    HelpItem("Active mask", "Texture, Clarity, Dehaze, Vignette, and Grain follow the selected layer. Cinematic Glow always applies to the whole photo.")
                ])
            ]
        case .detail:
            return [
                HelpSection("Sharpening", [
                    HelpItem("Amount", "Sets sharpening strength. Use a restrained value if the source is already sharpened."),
                    HelpItem("Radius", "Sets the width of sharpening around edges. Too large a radius can create halos."),
                    HelpItem("Detail", "Controls the contribution of fine structures. Inspect hair, stone, and skin at 100%."),
                    HelpItem("Masking", "Limits sharpening to edges so smooth areas and their noise are not enhanced evenly.")
                ]),
                HelpSection("Noise reduction", [
                    HelpItem("Luminance", "Reduces light-and-dark noise. Too much removes texture; Detail and Contrast help preserve its presence."),
                    HelpItem("Color", "Reduces colored noise blotches. Detail and Smoothing control how finely this correction is applied."),
                    HelpItem("Activation", "Secondary sharpening and noise controls become available when their primary Amount, Luminance, or Color value is above zero.")
                ])
            ]
        case .lighting:
            return [
                HelpSection("Place the lighting", [
                    HelpItem("Enable lighting", "Turn on Enable lighting in the Lighting tab. Start with a moderate intensity. Turning it off preserves the controls but removes the effect; Reset restores the initial controls and disables it."),
                    HelpItem("Subject point", "Select Subject point and tap the subject, preferably inside a solid area rather than on an edge. The turquoise marker sets the reference depth. It does not select or cut out a person."),
                    HelpItem("Light position", "Select Light position and tap where the virtual lamp should be projected. Drag either marker to move it directly. The yellow sun and turquoise target are independent; neither is exported.")
                ]),
                HelpSection("Shape the light", [
                    HelpItem("Intensity", "Controls the added light. Zero leaves the photo unchanged by this effect. Strong values can expose noise already present in dark areas; inspect skin and eyes at 100%."),
                    HelpItem("Relative distance", "Moves the lamp nearer to or farther from the selected depth plane. A closer lamp generally gives stronger, more concentrated illumination. These values are relative, not metres; the lamp stays in front of the subject plane."),
                    HelpItem("Softness", "Controls the spatial reach of the added light. Increasing it spreads illumination over a larger area near the selected depth. It does not blur the photo."),
                    HelpItem("Warmth", "Warms or cools only the added light. Zero is neutral. This is independent of the photo white balance."),
                    HelpItem("Surface relief", "Controls how strongly the estimated surface orientation shapes illumination. Lower it if depth errors create uneven shading.")
                ]),
                HelpSection("Experimental limitations", [
                    HelpItem("Sky and background", "Distant regions are attenuated according to estimated depth, not a semantic sky mask. If the sky or background brightens unexpectedly, move the subject point, reduce Softness or Intensity, or disable the effect. Hair, glass and reflections can have incorrect depth."),
                    HelpItem("Existing light and shadows", "This prototype adds light to the existing photo. It does not remove existing shadows, reconstruct hidden detail, or simulate accurate cast shadows, materials or backlighting. Faces are not regenerated."),
                    HelpItem("Processing and comparison", "Depth is calculated on device and shared with Depth Lens. First activation can take longer; geometry or optical corrections require a new estimate. The same lighting is applied in preview and export, with a reduced preview during interaction. Disable lighting to compare while retaining other edits; hold the photo to see the original."),
                    HelpItem("Saved settings", "Lighting affects the whole photo and cannot be assigned to a local mask. Its controls are saved with the photo and support Undo and Redo. Hiding or reordering the Lighting tab in Settings does not disable an effect already enabled on a photo.")
                ])
            ]
        case .depthLens:
            return [
                HelpSection("Start with the focus", [
                    HelpItem("Enable Depth Lens", "Enable Depth Lens, then tap the subject in the photo while this tab is open. The turquoise marker shows the selected position. On a portrait, start with the nearest eye. This tap sets focus instead of opening the full-screen view."),
                    HelpItem("The focus plane", "The effect uses the estimated distance at the selected point, not a cutout of the subject. Other objects at a similar estimated depth can remain sharp. A face or body spanning several depths may not be entirely sharp."),
                    HelpItem("Center focus", "Center focus returns the marker to the middle of the photo. It does not detect or select a face automatically.")
                ]),
                HelpSection("Shape the blur", [
                    HelpItem("Aperture", "A small f-number, such as f/1.4, gives stronger blur and a narrower sharp region. A larger number, such as f/5.6 or f/8, reduces the blur. If an eye or hair becomes too soft, increase the number and check the focus position."),
                    HelpItem("Focal length", "50, 85, and 135 mm change the simulated optical blur. At the same aperture and focus, longer focal lengths generally strengthen the blur. They do not zoom, crop, or change the perspective of the photo."),
                    HelpItem("A restrained starting point", "Try 50 or 85 mm with f/4, place the focus carefully, then lower the f-number gradually. Judge both the whole image and the edges around the subject. Strong blur makes depth-estimation errors more visible.")
                ]),
                HelpSection("Compare and correct", [
                    HelpItem("Compare", "Disable Depth Lens to compare with the same edits without this blur; enabling it again keeps its settings. Holding the photo compares with the original, before all edits. Pinch to inspect fine details and double-tap to restore the view."),
                    HelpItem("Reset", "Reset turns the effect off and restores f/1.4, 85 mm, and centered focus. Undo and Redo include Depth Lens changes; the settings are saved with the photo.")
                ]),
                HelpSection("Limits and rendering", [
                    HelpItem("Fine edges", "Hair, glass, reflections, fine branches, and overlapping objects can produce imperfect depth boundaries. Inspect both eyes and the subject edges. Reduce the blur or disable the effect when the depth estimate is unsuitable; it does not reconstruct hidden background detail."),
                    HelpItem("On-device processing", "Depth is calculated on the iPhone and reused while adjusting aperture, focal length, or focus. The first activation may take longer. Changing crop, geometry, or optical corrections recalculates depth; check the focus again afterward."),
                    HelpItem("Preview and export", "The preview uses a reduced resolution while dragging, then a higher quality render when released. Export applies the same effect at the output resolution. The focus marker is never exported. Depth Lens affects the whole photo and cannot be assigned to a local mask.")
                ])
            ]
        case .beauty:
            return [
                HelpSection("Portrait retouching", [
                    HelpItem("Beauty Amount", "Blends all Beauty adjustments. At zero the original pixels are preserved."),
                    HelpItem("Natural / Portrait / Beauty", "Three fixed, editable starting points. Changing any slider produces Custom."),
                    HelpItem("All Faces", "The same settings apply to every reliably detected face. If no face is found, no automatic face adjustment is applied.")
                ]),
                HelpSection("Skin, eyes and smile", [
                    HelpItem("Uniformity and Texture", "Uniformity evens broad skin tone while retaining pores. Texture controls the fine frequency band separately."),
                    HelpItem("Blemishes", "Targets isolated local redness conservatively; freckles and broad skin tone are not intentionally removed."),
                    HelpItem("Dark Circles", "Slightly lifts and warms the region below detected eyes without painting over the eyes."),
                    HelpItem("Eye Brightness and Eye Detail", "Brightens eyes and strengthens fine detail within the eye mask. The upper range is deliberately strong; use intermediate values for a natural result. Iris hue is preserved."),
                    HelpItem("Teeth", "Works only when an open mouth and plausible teeth are detected. Closed mouths remain unchanged.")
                ]),
                HelpSection("Correction", [
                    HelpItem("Edit correction area", "Add paints more of this correction area; Erase removes part of it. Finish editing to move the target or source, or tap another imperfection."),
                    HelpItem("Target and source", "Tap a small skin imperfection. Drag the turquoise target or orange source. A warning identifies low-confidence sources; inspect them at 100%."),
                    HelpItem("Size and Strength", "Adjust the selected correction. Each drag is one Undo step. Closing Correction hides the guides but keeps the repair; guides are never exported."),
                    HelpItem("Delete corrections", "Delete removes the selected correction. Delete all asks for confirmation when there are several. Reset Beauty clears every correction; Beauty presets preserve them.")
                ]),
                HelpSection("Portrait finishing", [
                    HelpItem("Lips", "Saturation changes the intensity of lip color, brightness lightens or darkens it, and detail defines its texture. The inner mouth is excluded. Compare at 100% to keep a natural result."),
                    HelpItem("Skin Shine", "Attenuates excess broad skin highlights without removing pores."),
                    HelpItem("Face Balance", "Gently lifts broad facial shadows or restrains broad highlights; it does not change overall exposure."),
                ])
            ]
        case .optics:
            return [
                HelpSection("Manufacturer profile", [
                    HelpItem("When available", "A RAW may provide a lens profile compatible with iOS. Enable Manufacturer profile to use it. A developed image generally no longer exposes an adjustable profile."),
                    HelpItem("When unavailable", "The switch is disabled and the panel explains why. Manual corrections below remain available.")
                ]),
                HelpSection("Manual corrections", [
                    HelpItem("Distortion", "Compensates visible bending of lines, especially near the edges. Compare architectural lines and avoid correcting more than needed."),
                    HelpItem("Chromatic aberration", "Adjusts color fringing along high-contrast edges. Examine silhouettes against a bright sky at 100%."),
                    HelpItem("Lens vignetting", "Compensates edge darkening caused by the lens. To add an artistic vignette, use Effects → Vignette instead.")
                ])
            ]
        case .geometry:
            return [
                HelpSection("Orientation and straightening", [
                    HelpItem("Rotate and flip", "Buttons rotate by quarter-turns or flip horizontally or vertically. Reset restores the geometry controls to their initial values."),
                    HelpItem("Auto horizon", "Estimates horizon straightening. Check the result in a scene without an obvious horizon."),
                    HelpItem("Straighten", "Corrects fine rotation. The thirds grid helps align a horizon or architectural line.")
                ]),
                HelpSection("Perspective and crop", [
                    HelpItem("Auto perspective", "Suggests a geometric correction, particularly for converging lines. You can undo or refine the result manually."),
                    HelpItem("Vertical and horizontal", "Straighten convergence in either direction. Watch the edges and subject shape after a strong correction."),
                    HelpItem("Aspect, scale, and offsets", "Refine proportions and position after perspective correction to recover a useful frame."),
                    HelpItem("Format", "Choose a crop aspect ratio. Crop changes zoom; Horizontal and Vertical position move the visible window across the photo.")
                ])
            ]
        case .masks:
            return [
                HelpSection("Layers", [
                    HelpItem("Whole photo", "The global base layer. Adding a mask creates a selectable, reorderable local layer above it."),
                    HelpItem("Selection and settings", "Select a mask here, then open Light, Color, Curves, Color Tools, Effects, or Detail to adjust that area. Their sliders are not duplicated in Masks."),
                    HelpItem("Name, opacity, and order", "Rename a mask so you can find it, control its contribution with opacity, and move it in the stack when its interaction with other layers should change."),
                    HelpItem("Visible / Outline", "Switch between the red overlay and the mask outline. This only changes overlay display; it does not turn the adjustment off."),
                    HelpItem("Invert", "Swaps the selected area with its complement. Useful for adjusting a background after isolating a subject.")
                ]),
                HelpSection("Create an area", [
                    HelpItem("Brush", "For an additive brush, Paint adds to the mask and Erase removes paint. For a subtractive brush, Paint marks the area to remove from the mask and Erase restores it. Pan navigates a zoomed photo. A newly created brush always starts in Paint mode."),
                    HelpItem("Gradients", "Place and resize linear or radial masks with handles on the photo, including after zooming."),
                    HelpItem("Smart masks", "Depending on the image, Lumora can propose Subject, Background, Person, Face, Eyes, Sky, or Skin. Inspect the outline before a strong adjustment."),
                    HelpItem("Add / Subtract", "Combine several components for a more precise selection. Each can be selected, reordered, or removed."),
                    HelpItem("Photo gestures", "Pinch to zoom and double-tap to reset zoom, even while using the brush. Mask strokes update the mask visualization without rerendering the full development after every gesture.")
                ])
            ]
        case .settings:
            return [HelpSection("Settings", [
                HelpItem("Show histogram", "Turn off Show histogram to remove the floating histogram from the photo. Turn it on to show it again. This does not change exposure or the histogram inside Curves."),
                HelpItem("Include metadata in exports", "Sets the initial state of Keep metadata whenever the export screen opens. You can change it for one export without changing this preference. GPS location remains removed unless you explicitly keep it in the export screen."),
                HelpItem("Editor tabs", "Use each eye button to show or hide a tab. Hiding a tab does not reset or disable its adjustments: they remain visible in the photo and in exports. Settings cannot be hidden."),
                HelpItem("Change the order", "Drag the handle at the right of a row to change the tab order. Hidden tabs also keep their place in this list, so you can arrange them before showing them again."),
                HelpItem("Quick selection from the tab bar", "Touch and hold a tab to open the list of visible tabs. Choose one to open it immediately. The order does not change; hidden tabs remain available in Settings."),
                HelpItem("Restore interface defaults", "Restore interface defaults shows the histogram and all tabs again, in their original order. It does not reset any photo edits. Settings is also available from the editor options menu and before importing a photo.")
            ])]
        case .exif:
            return [
                HelpSection("Displayed information", [
                    HelpItem("Original metadata", "EXIF reads the original image and groups available values into File, Camera, Capture, Location, and Authorship. Missing fields are simply omitted; developed JPEG, PNG, HEIC, TIFF, and RAW files do not all expose the same information."),
                    HelpItem("Location", "Coordinates appear only when the original contains GPS metadata. Treat them as private information when sharing a screenshot or an exported image."),
                    HelpItem("Read only", "This tab does not edit metadata or the photo. Hiding or reordering the EXIF tab in Settings has no effect on the original or on export settings.")
                ]),
                HelpSection("Export metadata", [
                    HelpItem("Keep metadata", "The export screen can include standard EXIF capture fields and selected TIFF fields. It updates dimensions and orientation for the exported pixels, removes proprietary Maker Notes, and does not copy XMP or IPTC blocks."),
                    HelpItem("Remove location", "GPS metadata is removed by default even when other metadata is kept. Disable Remove location only when you deliberately want coordinates in the exported file."),
                    HelpItem("Settings default", "The Include metadata in exports switch in Settings chooses the default for future exports. The switch inside Export remains available for each individual file.")
                ])
            ]
        case .presets:
            return [
                HelpSection("Create and apply", [
                    HelpItem("Create a preset", "Give it a name and choose groups to save. Light, Color, Curves, Color Mixer, Grading, Effects, Detail, and Creative can be included. Optics, Geometry, and Masks are optional."),
                    HelpItem("Apply", "Only groups stored in the preset are replaced. Other photo settings remain as they are; application is one undoable action."),
                    HelpItem("Personal presets", "Reuse your development choices on other photos. Creative looks and Grading presets are built into their respective tools.")
                ]),
                HelpSection("Manage and share", [
                    HelpItem("Rename or delete", "Organize your personal collection without changing settings already saved in a photo."),
                    HelpItem("Import and export", "Import Lumora JSON or XMP presets from the preset library. XMP settings are adapted to supported Lumora controls; the result may differ from the source application. Review adapted and unsupported settings before applying. Export uses Lumora JSON. Check included groups, especially Geometry and Masks.")
                ])
            ]
        case .credits:
            return [
                HelpSection("Lumora", [
                    HelpItem("Design and development", "Created by François Guillemé. Lumora's interface, editing pipeline, photographic effects, and validation tools were designed and developed specifically for the application."),
                    HelpItem("Made for Apple platforms", "Lumora is written in Swift and SwiftUI. Image rendering uses Core Image and Metal; Vision supports image analysis and masks; Core ML runs depth estimation on the device.")
                ]),
                HelpSection("Depth estimation", [
                    HelpItem("Depth Anything V2 Small", "Depth Lens and experimental Lighting use Depth Anything V2 Small. The Core ML package is distributed by Apple from the original Depth Anything V2 architecture. The Small model is provided under the Apache License 2.0."),
                    HelpItem("Model provenance", "Core ML package: apple/coreml-depth-anything-v2-small. Original project: DepthAnything/Depth-Anything-V2. The complete Apache 2.0 license and provenance notice are included with Lumora.")
                ]),
                HelpSection("Privacy and independence", [
                    HelpItem("On-device processing", "Photo editing, face analysis, masks, depth estimation, preview, and export run on the device. Lumora does not require an online image-processing service."),
                    HelpItem("Third-party libraries", "Lumora does not embed a third-party software library. Apple frameworks are part of the operating system; the depth model attribution is listed separately above.")
                ])
            ]
        }
    }
}
