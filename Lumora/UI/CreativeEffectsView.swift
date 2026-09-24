import SwiftUI

struct CreativeEffectsView: View {
    @Bindable var session: EditorSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.usesSideControlLayout) private var usesSideControlLayout
    @Binding var selected: UUID?
    @State private var advanced = false
    @State private var showsTile = false
    @State private var presetFeedback = 0
    #if DEBUG
    @State private var showsLab = false
    #endif
    private var effect: CreativeEffect? { session.state.creative.effects.first { $0.id == selected } }
    @ViewBuilder private var previewActions: some View {
        if !dynamicTypeSize.isAccessibilitySize {
            Text("FX").font(.caption).foregroundStyle(.secondary)
        }
        Toggle("FX", isOn: Binding(get: { !session.bypassCreative }, set: { session.setCreativeBypass(!$0) }))
            .labelsHidden().accessibilityLabel("Enable Creative preview")
            .accessibilityIdentifier("creative-preview-toggle")
        Button { session.finishInteraction(); showsTile = true } label: {
            if dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "viewfinder").frame(width: 44, height: 44)
            } else { Text("100 %") }
        }
        .accessibilityLabel("Creative detail at native resolution")
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Menu {
                        ForEach(["Key", "Detail", "Film"], id: \.self) { category in
                            Section(NSLocalizedString(category, comment: "Creative effect category")) {
                                ForEach(CreativeEffectKind.allCases.filter { $0.descriptor.category == category }) { kind in
                                    Button(NSLocalizedString(kind.descriptor.title, comment: "Creative effect"), systemImage: kind.descriptor.symbol) {
                                        let effect = CreativeEffect(kind, maskID: session.selectedMaskID)
                                        session.changeCreative("Add \(kind.descriptor.title)") { $0.effects.append(effect) }
                                        selected = effect.id
                                    }.disabled(session.state.creative.effects.count >= 32)
                                    .accessibilityIdentifier("creative-add-\(kind.rawValue)")
                                }
                            }
                        }
                        #if DEBUG
                        Divider()
                        Button("Creative FX Lab") { showsLab = true }
                        #endif
                    } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            Image(systemName: "plus.circle").frame(width: 44, height: 44)
                        } else { Label("Add", systemImage: "plus.circle") }
                    }
                    .accessibilityLabel("Add effect")
                    .accessibilityIdentifier("creative-add")
                    Menu {
                        ForEach(CreativeEffectKind.allCases) { kind in
                            Section(NSLocalizedString(kind.descriptor.title, comment: "Creative effect")) {
                                ForEach(CreativeFXPreset.all(for: kind)) { preset in
                                    Button(NSLocalizedString(preset.title, comment: "Creative preset")) {
                                        applyCatalogPreset(preset)
                                    }
                                    .disabled(session.state.creative.effects.count >= 32 &&
                                              !session.state.creative.effects.contains { $0.kind == kind })
                                    .accessibilityIdentifier("creative-preset-add-\(preset.id)")
                                }
                            }
                        }
                    } label: { Label("Presets", systemImage: "sparkles").fixedSize(horizontal: true, vertical: false) }
                    .accessibilityIdentifier("creative-presets")
                    Spacer()
                    if !usesSideControlLayout { previewActions }
                }.dimsDuringAdjustment()
                if usesSideControlLayout {
                    HStack { Spacer(minLength: 0); previewActions }
                        .dimsDuringAdjustment()
                }
                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(session.state.creative.effects) { fx in
                                Button {
                                    session.finishInteraction(); selected = fx.id
                                    if let mask = fx.maskID, session.state.masks.contains(where: { $0.id == mask }) { session.selectMask(mask) }
                                    else { session.selectBaseLayer() }
                                } label: {
                                    Label(NSLocalizedString(fx.kind.descriptor.title, comment: "Creative effect"), systemImage: fx.enabled ? fx.kind.descriptor.symbol : "eye.slash")
                                }
                                .buttonStyle(.bordered).tint(fx.id == selected ? .mint : .secondary)
                                .accessibilityIdentifier("creative-effect-\(fx.id)")
                            }
                        }
                    }
                }.dimsDuringAdjustment()
                if let effect {
                    CreativePresetSelector(presets: CreativeFXPreset.all(for: effect.kind),
                                           selectedID: CreativeFXPreset.matching(effect)?.id) { preset in
                        update { $0 = preset.applying(to: $0) }
                    } headerActions: {
                        HStack(spacing: 0) {
                            effectAction(effect.enabled ? "Disable effect" : "Enable effect", effect.enabled ? "eye" : "eye.slash", "toggle") { update { $0.enabled.toggle() } }
                            effectAction("Duplicate", "plus.square.on.square", "duplicate") {
                                session.changeCreative("Duplicate effect") { $0.duplicate(effect.id) }
                            }
                            effectAction("Delete", "trash", "delete") {
                                session.changeCreative("Delete effect") { $0.effects.removeAll { $0.id == effect.id } }
                                selected = session.state.creative.effects.last?.id
                            }
                            effectAction("Apply earlier", "arrow.up", "earlier") {
                                session.changeCreative("Move effect") { $0.move(effect.id, by: -1) }
                            }.disabled(session.state.creative.effects.first?.id == effect.id)
                            effectAction("Apply later", "arrow.down", "later") {
                                session.changeCreative("Move effect") { $0.move(effect.id, by: 1) }
                            }.disabled(session.state.creative.effects.last?.id == effect.id)
                            effectAction("Reset", "arrow.counterclockwise", "reset") { update { $0.reset() } }
                        }
                    }
                    .dimsDuringAdjustment()
                    HStack {
                        Picker("Area", selection: Binding<UUID?>(get: { effect.maskID }, set: { id in
                            update { $0.maskID = id }
                            if let id { session.selectMask(id) } else { session.selectBaseLayer() }
                        })) {
                            Text("Whole photo").tag(nil as UUID?)
                            ForEach(session.state.masks) { Text($0.name).tag(Optional($0.id)) }
                            if let id = effect.maskID, !session.state.masks.contains(where: { $0.id == id }) {
                                Text("Mask missing — effect suspended").tag(Optional(id))
                            }
                        }.font(.caption).dimsDuringAdjustment()
                        Spacer(minLength: 0)
                    }.font(.caption).dimsDuringAdjustment()

                    Text("Settings").font(.subheadline.weight(.semibold)).dimsDuringAdjustment()
                    slider("opacity", "Opacity", 0...100, effect.opacity, 100) { value in update { $0.opacity = value } }
                    if effect.kind == .grain {
                        Picker("Mode", selection: $advanced) {
                            Text("Simple").tag(false); Text("Advanced").tag(true)
                        }.pickerStyle(.segmented).dimsDuringAdjustment()
                    }
                    if effect.kind == .tonalContrast {
                        Button(advanced ? "Hide protections" : "Advanced protections") { advanced.toggle() }
                            .font(.caption).dimsDuringAdjustment()
                    }
                    if effect.kind == .detailExtractor {
                        Button(advanced ? "Hide protections" : "Advanced protections") { advanced.toggle() }
                            .font(.caption).dimsDuringAdjustment()
                    }
                    if effect.kind == .glamourGlow || effect.kind == .bleachBypass || effect.kind == .proContrast || effect.kind == .crossProcessing || effect.kind == .filmEmulation || effect.kind == .silverBW || effect.kind == .silverToning {
                        Button(advanced ? "Hide advanced settings" : "Advanced settings") { advanced.toggle() }
                            .font(.caption).dimsDuringAdjustment()
                    }
                    if effect.kind == .silverBW {
                        Picker("Film Response", selection: Binding<Int>(get: { Int(effect["filmResponse"].rounded()) }, set: { value in
                            update { $0["filmResponse"] = Double(value) }
                        })) {
                            ForEach(SilverFilmResponse.allCases, id: \.rawValue) { response in
                                Text(response.title).tag(response.rawValue)
                            }
                        }.dimsDuringAdjustment().accessibilityIdentifier("creative-silver-film-response")
                        Menu("Color filter") {
                            Button("None") { update { $0["filterStrength"] = 0 } }
                            ForEach(["Yellow", "Orange", "Red", "Green", "Blue"].indices, id: \.self) { index in
                                Button(["Yellow", "Orange", "Red", "Green", "Blue"][index]) {
                                    update {
                                        $0["filterHue"] = [60,30,0,120,240][index]
                                        if $0["filterStrength"] == 0 { $0["filterStrength"] = 50 }
                                    }
                                }
                            }
                        }.dimsDuringAdjustment()
                    }
                    if effect.kind == .silverToning {
                        Picker("Toner", selection: Binding<Int>(get: { Int(effect["toner"].rounded()) }, set: { value in
                            update { $0["toner"] = Double(value) }
                        })) {
                            ForEach(SilverToner.allCases, id: \.rawValue) { toner in
                                Text(toner.title).tag(toner.rawValue)
                            }
                        }.dimsDuringAdjustment().accessibilityIdentifier("creative-silver-toner")
                    }
                    if effect.kind == .darkenLightenCenter {
                        Text("Drag the handle on the photo to position the center.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button(advanced ? "Hide precise position" : "Precise X / Y position") { advanced.toggle() }
                            .buttonStyle(.bordered).accessibilityIdentifier("creative-dlc-position")
                    }
                    ForEach(effect.kind.descriptor.parameters.filter { spec in
                        if effect.kind == .darkenLightenCenter && ["centerX", "centerY"].contains(spec.id) { return advanced }
                        if effect.kind == .silverToning {
                            if spec.id == "toner" { return false }
                            let split = Int(effect["toner"].rounded()) == SilverToner.split.rawValue
                            if ["shadowHue", "highlightHue"].contains(spec.id) { return split }
                            if !advanced {
                                return ["amount", "strength", "balance"].contains(spec.id)
                                    || (split && ["shadowStrength", "highlightStrength"].contains(spec.id))
                            }
                        }
                        if effect.kind == .grain { return advanced || ["amount", "size", "hardness"].contains(spec.id) }
                        if (effect.kind == .tonalContrast || effect.kind == .detailExtractor) && !advanced {
                            return !spec.id.hasPrefix("protect")
                        }
                        if effect.kind == .glamourGlow && !advanced {
                            return !["threshold", "highlightProtection", "shadowProtection"].contains(spec.id)
                        }
                        if effect.kind == .bleachBypass && !advanced {
                            return !["blackDensity", "highlightRollOff", "shadowProtection"].contains(spec.id)
                        }
                        if effect.kind == .proContrast && !advanced {
                            return !["shadowProtection", "highlightProtection"].contains(spec.id)
                        }
                        if effect.kind == .crossProcessing {
                            if spec.id == "style" { return false }
                            if !advanced { return !["shadowHue", "shadowStrength", "highlightHue",
                                                   "highlightStrength", "blackLift"].contains(spec.id) }
                        }
                        if effect.kind == .silverBW {
                            if spec.id == "filmResponse" { return false }
                            if !advanced { return !["dynamicBrightness", "softContrast", "blacks", "whites"].contains(spec.id) }
                        }
                        if effect.kind == .filmEmulation {
                            if spec.id == "style" { return false }
                            if !advanced { return !["highlightRollOff", "shadowDensity", "colorResponse"].contains(spec.id) }
                        }
                        return true
                    }) { spec in
                        slider(spec.id, NSLocalizedString(spec.title, comment: "Creative effect parameter"), spec.range, effect[spec.id], spec.defaultValue) { value in update { $0[spec.id] = value } }
                    }
                    if effect.kind == .grain && advanced {
                        Toggle("Monochrome", isOn: Binding(get: { effect.monochromatic }, set: { v in update { $0.monochromatic = v } }))
                            .dimsDuringAdjustment()
                        Button("New structure") { update { $0.seed = $0.seed &+ 1 } }.dimsDuringAdjustment()
                    }
                } else {
                    Text("Stack Pro Contrast, Bleach Bypass and other Creative effects. Each effect can target an existing mask.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 18).padding(.bottom, 12)
        }
        .accessibilityIdentifier("creative-controls")
        .sensoryFeedback(.selection, trigger: presetFeedback)
        .onAppear { if selected == nil { selected = session.state.creative.effects.last?.id } }
        .onChange(of: session.state.creative.effects.map(\.id)) { _, ids in
            if selected == nil || !ids.contains(selected!) { selected = ids.last }
        }
        #if DEBUG
        .sheet(isPresented: $showsLab) { CreativeFXLab() }
        #endif
        .sheet(isPresented: $showsTile) { CreativeTileView(session: session) }
    }
    private func update(_ change: (inout CreativeEffect) -> Void) {
        guard let selected else { return }
        session.changeCreative("Creative") { stack in
            if let i = stack.effects.firstIndex(where: { $0.id == selected }) { change(&stack.effects[i]) }
        }
    }
    private func applyCatalogPreset(_ preset: CreativeFXPreset) {
        let effects = session.state.creative.effects
        let matchingID = effects.first(where: { $0.id == selected && $0.kind == preset.kind })?.id
            ?? effects.last(where: { $0.kind == preset.kind })?.id
        if let matchingID {
            selected = matchingID
            guard let current = effects.first(where: { $0.id == matchingID }), !preset.matches(current) else { return }
            session.changeCreative("Preset \(preset.title)") { stack in
                if let index = stack.effects.firstIndex(where: { $0.id == matchingID }) {
                    stack.effects[index] = preset.applying(to: stack.effects[index])
                }
            }
        } else {
            let effect = preset.makeEffect(maskID: session.selectedMaskID)
            session.changeCreative("Add \(preset.title) preset") { $0.effects.append(effect) }
            selected = effect.id
        }
        presetFeedback += 1
    }
    private func effectAction(_ title: String, _ symbol: String, _ id: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title)
            .accessibilityIdentifier("creative-action-" + id)
    }
    private func slider(_ id: String, _ title: String, _ range: ClosedRange<Double>, _ value: Double,
                        _ reset: Double, change: @escaping (Double) -> Void) -> some View {
        let preciseCenter = effect?.kind == .darkenLightenCenter && ["centerX", "centerY"].contains(id)
        let preciseEV = effect?.kind == .darkenLightenCenter && ["centerEV", "borderEV"].contains(id)
        return AdjustmentSlider(title: title, range: range, step: preciseCenter ? 0.001 : preciseEV ? 0.01 : 1,
            precision: preciseCenter ? 3 : preciseEV ? 2 : 0, accessibilityID: "creative-\(id)", value: value,
            onBegin: { session.beginInteraction("Creative · \(title)") }, onChange: change,
            onEnd: session.finishInteraction, onReset: { session.finishInteraction(); change(reset) })
    }
}

/// Native pixel inspection is explicit: ordinary preview zoom still magnifies the cached preview.
struct CreativeTileView: View {
    let session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var x = 0.5
    @State private var y = 0.5
    @State private var tile: CGImage?
    @State private var error: String?
    @State private var loading = false
    private var position: String { "\(x)-\(y)" }
    var body: some View {
        NavigationStack {
            VStack {
                if let tile {
                    ScrollView([.horizontal, .vertical]) {
                        Image(decorative: tile, scale: displayScale).interpolation(.none)
                    }
                }
                if loading { ProgressView("Native-resolution region…") }
                if let error { Text(error).font(.caption) }
                Text("100% · one photo pixel per screen pixel").font(.caption)
                Slider(value: $x, in: 0...1, step: 0.1).accessibilityLabel("Horizontal position")
                Slider(value: $y, in: 0...1, step: 0.1).accessibilityLabel("Vertical position")
            }.padding().background(.black)
                .navigationTitle("Creative detail")
                .toolbar { Button("Close") { dismiss() } }
                .task(id: position) {
                    loading = true; error = nil
                    do {
                        try await Task.sleep(for: .milliseconds(180))
                        let next = try await session.creativeTile(region: CGRect(x: x-0.125, y: y-0.125, width: 0.25, height: 0.25))
                        try Task.checkCancellation(); tile = next; loading = false
                    } catch is CancellationError {} catch { self.error = error.localizedDescription; loading = false }
                }
        }.preferredColorScheme(.dark)
    }
}
