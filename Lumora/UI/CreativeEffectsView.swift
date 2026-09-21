import SwiftUI

struct CreativeEffectsView: View {
    @Bindable var session: EditorSession
    @State private var selected: UUID?
    @State private var advanced = false
    @State private var showsTile = false
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
                    } label: { Label("Ajouter", systemImage: "plus.circle") }
                    .accessibilityIdentifier("creative-add")
                    Menu {
                        ForEach(CreativeEffectKind.allCases) { kind in
                            Section(kind.descriptor.title) {
                                ForEach(CreativeFXPreset.all(for: kind)) { preset in
                                    Button(preset.title) {
                                        let effect = preset.makeEffect(maskID: session.selectedMaskID)
                                        session.changeCreative("Ajouter le preset \(preset.title)") { $0.effects.append(effect) }
                                        selected = effect.id
                                    }
                                    .disabled(session.state.creative.effects.count >= 32)
                                    .accessibilityIdentifier("creative-preset-add-\(preset.id)")
                                }
                            }
                        }
                    } label: { Label("Presets", systemImage: "sparkles") }
                    .accessibilityIdentifier("creative-presets")
                    Spacer()
                    Text("FX").font(.caption).foregroundStyle(.secondary)
                    Toggle("FX", isOn: Binding(get: { !session.bypassCreative }, set: { session.setCreativeBypass(!$0) }))
                        .labelsHidden().accessibilityLabel("Activer l’aperçu Creative")
                    Button("100 %") { session.finishInteraction(); showsTile = true }
                        .accessibilityLabel("Détail Creative à résolution native")
                }.dimsDuringAdjustment()
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
                }.dimsDuringAdjustment()
                if let effect {
                    HStack {
                        Button { update { $0.enabled.toggle() } } label: {
                            Image(systemName: effect.enabled ? "eye" : "eye.slash").frame(width: 30, height: 30)
                        }.accessibilityLabel(effect.enabled ? "Désactiver l’effet" : "Activer l’effet")
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
                        Menu {
                            Button("Dupliquer", systemImage: "plus.square.on.square") {
                                session.changeCreative("Dupliquer un effet") { $0.duplicate(effect.id) }
                            }
                            Button("Appliquer plus tôt", systemImage: "arrow.up") {
                                session.changeCreative("Déplacer un effet") { $0.move(effect.id, by: -1) }
                            }
                            Button("Appliquer plus tard", systemImage: "arrow.down") {
                                session.changeCreative("Déplacer un effet") { $0.move(effect.id, by: 1) }
                            }
                            Button("Réinitialiser", systemImage: "arrow.counterclockwise") { update { $0.reset() } }
                            Button("Supprimer", systemImage: "trash", role: .destructive) {
                                session.changeCreative("Supprimer un effet") { $0.effects.removeAll { $0.id == effect.id } }
                                selected = session.state.creative.effects.last?.id
                            }
                        } label: { Image(systemName: "ellipsis.circle").frame(width: 32, height: 30) }
                        .accessibilityLabel("Options de l’effet")
                    }.font(.caption).dimsDuringAdjustment()

                    slider("opacity", "Opacité", 0...100, effect.opacity, 100) { value in update { $0.opacity = value } }
                    Menu {
                        ForEach(CreativeFXPreset.all(for: effect.kind)) { preset in
                            Button(preset.title) { update { $0 = preset.applying(to: $0) } }
                                .accessibilityIdentifier("creative-preset-apply-\(preset.id)")
                        }
                    } label: {
                        Label(CreativeFXPreset.all(for: effect.kind).first(where: { $0.matches(effect) })?.title
                              ?? "Preset personnalisé", systemImage: "square.stack.3d.up")
                    }
                    .accessibilityLabel("Preset \(effect.kind.descriptor.title)")
                    .dimsDuringAdjustment()
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
                    ForEach(effect.kind.descriptor.parameters.filter { spec in
                        if effect.kind == .grain { return advanced || ["amount", "size", "hardness"].contains(spec.id) }
                        if (effect.kind == .tonalContrast || effect.kind == .detailExtractor) && !advanced {
                            return !spec.id.hasPrefix("protect")
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
                    Text("Empilez High Key, Low Key, Tonal Contrast, Detail Extractor et Grain. Chaque effet peut cibler un masque existant.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 18).padding(.bottom, 12)
        }
        .accessibilityIdentifier("creative-controls")
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
    private func slider(_ id: String, _ title: String, _ range: ClosedRange<Double>, _ value: Double,
                        _ reset: Double, change: @escaping (Double) -> Void) -> some View {
        AdjustmentSlider(title: title, range: range, accessibilityID: "creative-\(id)", value: value,
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
