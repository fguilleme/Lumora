import SwiftUI

struct CreativeEffectsView: View {
    @Bindable var session: EditorSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selected: UUID?
    @State private var advanced = false
    @State private var showsTile = false
    @State private var presetFeedback = 0
    #if DEBUG
    @State private var showsLab = false
    #endif
    private var effect: CreativeEffect? { session.state.creative.effects.first { $0.id == selected } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Menu {
                        ForEach(["Key", "Detail", "Film"], id: \.self) { category in
                            Section(category) {
                                ForEach(CreativeEffectKind.allCases.filter { $0.descriptor.category == category }) { kind in
                                    Button(kind.descriptor.title, systemImage: kind.descriptor.symbol) {
                                        let effect = CreativeEffect(kind, maskID: session.selectedMaskID)
                                        session.changeCreative("Ajouter \(kind.descriptor.title)") { $0.effects.append(effect) }
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
                        } else { Label("Ajouter", systemImage: "plus.circle") }
                    }
                    .accessibilityLabel("Ajouter un effet")
                    .accessibilityIdentifier("creative-add")
                    Menu {
                        ForEach(CreativeEffectKind.allCases) { kind in
                            Section(kind.descriptor.title) {
                                ForEach(CreativeFXPreset.all(for: kind)) { preset in
                                    Button(preset.title) {
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
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text("FX").font(.caption).foregroundStyle(.secondary)
                    }
                    Toggle("FX", isOn: Binding(get: { !session.bypassCreative }, set: { session.setCreativeBypass(!$0) }))
                        .labelsHidden().accessibilityLabel("Activer l’aperçu Creative")
                    Button { session.finishInteraction(); showsTile = true } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            Image(systemName: "viewfinder").frame(width: 44, height: 44)
                        } else { Text("100 %") }
                    }
                        .accessibilityLabel("Détail Creative à résolution native")
                }.dimsDuringAdjustment()
                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(session.state.creative.effects) { fx in
                                Button {
                                    session.finishInteraction(); selected = fx.id
                                    if let mask = fx.maskID, session.state.masks.contains(where: { $0.id == mask }) { session.selectMask(mask) }
                                    else { session.selectBaseLayer() }
                                } label: {
                                    Label(fx.kind.descriptor.title, systemImage: fx.enabled ? fx.kind.descriptor.symbol : "eye.slash")
                                }
                                .buttonStyle(.bordered).tint(fx.id == selected ? .mint : .secondary)
                                .accessibilityIdentifier("creative-effect-\(fx.id)")
                            }
                        }
                    }
                    if let effect {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                effectAction(effect.enabled ? "Désactiver l’effet" : "Activer l’effet", effect.enabled ? "eye" : "eye.slash", "toggle") { update { $0.enabled.toggle() } }
                                effectAction("Dupliquer", "plus.square.on.square", "duplicate") {
                                    session.changeCreative("Dupliquer un effet") { $0.duplicate(effect.id) }
                                }
                                effectAction("Supprimer", "trash", "delete") {
                                    session.changeCreative("Supprimer un effet") { $0.effects.removeAll { $0.id == effect.id } }
                                    selected = session.state.creative.effects.last?.id
                                }
                            }
                            HStack(spacing: 0) {
                                effectAction("Appliquer plus tôt", "arrow.up", "earlier") {
                                    session.changeCreative("Déplacer un effet") { $0.move(effect.id, by: -1) }
                                }.disabled(session.state.creative.effects.first?.id == effect.id)
                                effectAction("Appliquer plus tard", "arrow.down", "later") {
                                    session.changeCreative("Déplacer un effet") { $0.move(effect.id, by: 1) }
                                }.disabled(session.state.creative.effects.last?.id == effect.id)
                                effectAction("Réinitialiser", "arrow.counterclockwise", "reset") { update { $0.reset() } }
                            }
                        }
                    }
                }.dimsDuringAdjustment()
                if let effect {
                    CreativePresetSelector(presets: CreativeFXPreset.all(for: effect.kind),
                                           selectedID: CreativeFXPreset.matching(effect)?.id) { preset in
                        update { $0 = preset.applying(to: $0) }
                    }
                    .dimsDuringAdjustment()
                    HStack {
                        Picker("Zone", selection: Binding<UUID?>(get: { effect.maskID }, set: { id in
                            update { $0.maskID = id }
                            if let id { session.selectMask(id) } else { session.selectBaseLayer() }
                        })) {
                            Text("Photo entière").tag(nil as UUID?)
                            ForEach(session.state.masks) { Text($0.name).tag(Optional($0.id)) }
                            if let id = effect.maskID, !session.state.masks.contains(where: { $0.id == id }) {
                                Text("Masque absent — effet suspendu").tag(Optional(id))
                            }
                        }.font(.caption).dimsDuringAdjustment()
                        Spacer(minLength: 0)
                    }.font(.caption).dimsDuringAdjustment()

                    Text("Réglages").font(.subheadline.weight(.semibold)).dimsDuringAdjustment()
                    slider("opacity", "Opacité", 0...100, effect.opacity, 100) { value in update { $0.opacity = value } }
                    if effect.kind == .grain {
                        Picker("Mode", selection: $advanced) {
                            Text("Simple").tag(false); Text("Avancé").tag(true)
                        }.pickerStyle(.segmented).dimsDuringAdjustment()
                    }
                    if effect.kind == .tonalContrast {
                        Button(advanced ? "Masquer les protections" : "Protections avancées") { advanced.toggle() }
                            .font(.caption).dimsDuringAdjustment()
                    }
                    if effect.kind == .detailExtractor {
                        Button(advanced ? "Masquer les protections" : "Protections avancées") { advanced.toggle() }
                            .font(.caption).dimsDuringAdjustment()
                    }
                    if effect.kind == .glamourGlow || effect.kind == .bleachBypass || effect.kind == .proContrast || effect.kind == .crossProcessing || effect.kind == .filmEmulation || effect.kind == .silverBW || effect.kind == .silverToning {
                        Button(advanced ? "Masquer les réglages avancés" : "Réglages avancés") { advanced.toggle() }
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
                        Menu("Filtre coloré") {
                            Button("Aucun") { update { $0["filterStrength"] = 0 } }
                            ForEach(["Jaune", "Orange", "Rouge", "Vert", "Bleu"].indices, id: \.self) { index in
                                Button(["Jaune", "Orange", "Rouge", "Vert", "Bleu"][index]) {
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
                        Text("Déplacez la poignée sur la photo pour placer le centre.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button(advanced ? "Masquer la position précise" : "Position précise X / Y") { advanced.toggle() }
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
                        slider(spec.id, spec.title, spec.range, effect[spec.id], spec.defaultValue) { value in update { $0[spec.id] = value } }
                    }
                    if effect.kind == .grain && advanced {
                        Toggle("Monochrome", isOn: Binding(get: { effect.monochromatic }, set: { v in update { $0.monochromatic = v } }))
                            .dimsDuringAdjustment()
                        Button("Nouvelle structure") { update { $0.seed = $0.seed &+ 1 } }.dimsDuringAdjustment()
                    }
                } else {
                    Text("Empilez Pro Contrast, Bleach Bypass et les autres effets Creative. Chaque effet peut cibler un masque existant.")
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
            session.changeCreative("Ajouter le preset \(preset.title)") { $0.effects.append(effect) }
            selected = effect.id
        }
        presetFeedback += 1
    }
    private func effectAction(_ title: String, _ symbol: String, _ id: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 20))
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
                if loading { ProgressView("Région à résolution native…") }
                if let error { Text(error).font(.caption) }
                Text("100 % · un pixel photo par pixel écran").font(.caption)
                Slider(value: $x, in: 0...1, step: 0.1).accessibilityLabel("Position horizontale")
                Slider(value: $y, in: 0...1, step: 0.1).accessibilityLabel("Position verticale")
            }.padding().background(.black)
                .navigationTitle("Détail Creative")
                .toolbar { Button("Fermer") { dismiss() } }
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
