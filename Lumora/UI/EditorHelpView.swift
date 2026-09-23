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
                Text("Choose a tab to learn its controls and gestures. Help does not change the photo.")
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
                                Text(topic.summary).font(.caption2).foregroundStyle(.secondary)
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
                        Text(topic.introduction)
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
        self.name = name
        self.explanation = explanation
    }
}

private struct HelpSection: Identifiable {
    let title: String
    let items: [HelpItem]
    var id: String { title }
    init(_ title: String, _ items: [HelpItem]) {
        self.title = title
        self.items = items
    }
}

private enum EditorHelpTopic: String, CaseIterable, Identifiable {
    case creative, light, color, curves, colorTools, effects, detail, optics, geometry, masks, presets
    var id: String { rawValue }

    var title: String {
        switch self {
        case .creative: "Creative"
        case .light: "Light"
        case .color: "Color"
        case .curves: "Curves"
        case .colorTools: "Color Tools"
        case .effects: "Effects"
        case .detail: "Detail"
        case .optics: "Optics"
        case .geometry: "Geometry"
        case .masks: "Masks"
        case .presets: "Presets"
        }
    }

    var symbol: String {
        switch self {
        case .creative: "sparkles"
        case .light: "sun.max"
        case .color: "slider.horizontal.3"
        case .curves: "point.topleft.down.to.point.bottomright.curvepath"
        case .colorTools: "circle.lefthalf.filled"
        case .effects: "camera.filters"
        case .detail: "triangle"
        case .optics: "camera.aperture"
        case .geometry: "crop.rotate"
        case .masks: "circle.dashed.inset.filled"
        case .presets: "slider.horizontal.2.square"
        }
    }

    var summary: String {
        switch self {
        case .creative: "Photographic effects and looks in a stack"
        case .light: "Exposure and tonal balance"
        case .color: "White balance and color intensity"
        case .curves: "Precise tonal and channel control"
        case .colorTools: "Color Mixer and grading"
        case .effects: "Texture, clarity, dehaze, vignette, grain"
        case .detail: "Sharpening and noise reduction"
        case .optics: "Lens profile and manual corrections"
        case .geometry: "Horizon, perspective, and crop"
        case .masks: "Layers and local adjustments"
        case .presets: "Save and reuse your settings"
        }
    }

    var introduction: String {
        switch self {
        case .creative: "Creative combines independent effects. Each has its own settings, and its position in the stack changes the result. Built-in looks are editable starting points."
        case .light: "Light controls the overall tonal balance, or that of the selected mask. Start with exposure, protect highlights, then refine shadows, whites, and blacks."
        case .color: "Color controls color cast and intensity. Careful white balance preserves the mood of a deliberately warm or cool scene."
        case .curves: "Curves positions tones precisely and can adjust RGB channels separately. View mode prevents accidental edits while scrolling."
        case .colorTools: "Color Tools contains Color Mixer for colors in the scene and Grading for tonal regions. They change different properties."
        case .effects: "Effects provides finishing adjustments. Texture and Clarity change local contrast; Dehaze, Vignette, and Grain serve different purposes."
        case .detail: "Detail controls sharpening and noise reduction. Examine results at 100%: a reduced preview can hide oversharpening and excessive smoothing."
        case .optics: "Optics corrects lens defects. A manufacturer profile is available only when the RAW exposes a compatible one; manual adjustments remain available otherwise."
        case .geometry: "Geometry changes orientation, perspective, and framing. It changes which part of the photo is visible without altering the source file."
        case .masks: "Masks creates layers for local adjustments. Select a mask here, then use controls in other tabs to edit only its area."
        case .presets: "Presets saves groups of personal settings for use on other photos. Choose which groups to include when creating one."
        }
    }

    var sections: [HelpSection] {
        switch self {
        case .creative:
            return [
                HelpSection("Build an effect stack", [
                    HelpItem("Add an effect", "Choose from the catalog. Every effect becomes a separate step; effects run in their displayed order."),
                    HelpItem("Change the order", "Move an effect earlier or later to change the result. Silver B&W before Silver Toning creates a toned print; reversing them can remove the toning color."),
                    HelpItem("Quick actions", "The eye enables or disables a step. Other icons duplicate, delete, reset, or reorder the selected effect."),
                    HelpItem("Opacity and mask", "Opacity controls the effect's strength. Assign an existing mask to limit the effect to part of the photo.")
                ]),
                HelpSection("Effect families", [
                    HelpItem("Tone and detail", "High Key, Low Key, Pro Contrast, Tonal Contrast, Detail Extractor, and Glamour Glow shape light or detail. Inspect at 100% to avoid excessive structure."),
                    HelpItem("Film and processes", "Film Grain adds grain. Film Emulation changes film response without generating grain. Cross Processing and Bleach Bypass alter color response."),
                    HelpItem("Monochrome prints", "Silver B&W converts colors to gray densities. Silver Toning colors the print according to density. Add Film Grain separately if desired."),
                    HelpItem("Darken / Lighten Center", "Position the center on your subject, then adjust the center and outer exposure independently."),
                    HelpItem("Looks and Custom", "Choosing a look fills in the effect's settings. Changing a value switches to Custom; the original look remains available.")
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
                    HelpItem("Auto", "Analyzes the photo and fills the visible sliders with a starting proposal. It is a one-time action: edit the values, undo it, or run Auto again."),
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
                    HelpItem("Auto Color", "Uses the shared Auto image analysis but fills only color controls. A deliberately warm scene does not necessarily have a white-balance error."),
                    HelpItem("With Auto Light", "Auto Color does not duplicate exposure or contrast. You can use both proposals together and refine them manually."),
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
                    HelpItem("Natural, Balanced, Punchy", "These three styles express the same Auto analysis with increasing tonal strength. Generated points remain editable."),
                    HelpItem("With Auto Light", "Auto Curves is an alternative representation of a tonal correction. Lumora does not automatically stack an equivalent curve on Auto Light and double the adjustment."),
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
                    HelpItem("Texture", "Strengthens or softens fine detail such as fabric or hair. Negative values reduce detail."),
                    HelpItem("Clarity", "Affects broader local contrast than Texture. High values can harden faces or create overly visible transitions."),
                    HelpItem("Dehaze", "Increases or reduces separation in a hazy scene. It also changes global contrast and slightly affects color; inspect the shadows."),
                    HelpItem("Vignette", "Modulates edge brightness to guide attention. It differs from Lens vignetting, which is meant to correct the lens."),
                    HelpItem("Grain", "Adds a finishing grain texture. Creative also has Film Grain; using both can compound the grain.")
                ]),
                HelpSection("What to check", [
                    HelpItem("At 100%", "Inspect Texture, Clarity, and Grain at full size. A reduced preview can hide an overly strong result."),
                    HelpItem("Active mask", "These settings follow the selected layer, like other development controls.")
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
                    HelpItem("Brush", "Paint adds to the mask, Erase removes from it, and Pan navigates a zoomed photo. Size, Feather, Flow, and Opacity shape the stroke."),
                    HelpItem("Gradients", "Place and resize linear or radial masks with handles on the photo, including after zooming."),
                    HelpItem("Smart masks", "Depending on the image, Lumora can propose Subject, Background, Person, Face, Eyes, Sky, or Skin. Inspect the outline before a strong adjustment."),
                    HelpItem("Add / Subtract", "Combine several components for a more precise selection. Each can be selected, reordered, or removed."),
                    HelpItem("Photo gestures", "Pinch to zoom and double-tap to reset zoom, even while using the brush. Mask strokes update the mask visualization without rerendering the full development after every gesture.")
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
                    HelpItem("Import and export", "Share a preset in Lumora's JSON format. Before applying one you received, check which groups it includes, especially Geometry and Masks.")
                ])
            ]
        }
    }
}
