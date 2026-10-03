import SwiftUI

struct MagicSelectionView: View {
    let source: CGImage
    let onCancel: () -> Void
    let onValidate: (GeneratedMask) -> Void

    @State private var engine: MagicSelectionEngine
    @State private var points: [MagicSelectionPoint] = []
    @State private var preview: CGImage?
    @State private var includes = true
    @State private var candidate = 0
    @State private var refineEdges = true
    @State private var busy = true
    @State private var status = String(localized: "Preparing Magic Selection…")
    @State private var zoom: CGFloat = 1
    @State private var offset = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var translation = CGSize.zero

    init(source: CGImage, onCancel: @escaping () -> Void,
         onValidate: @escaping (GeneratedMask) -> Void) {
        self.source = source
        self.onCancel = onCancel
        self.onValidate = onValidate
        _engine = State(initialValue: MagicSelectionEngine(source: source))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Touch the element to select. Add points to extend the selection, or remove points to exclude an area.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                GeometryReader { geometry in
                    let imageSize = CGSize(width: source.width, height: source.height)
                    let fitted = aspectFit(imageSize, in: CGRect(origin: .zero, size: geometry.size))
                    let displayZoom = min(6, max(1, zoom * magnification))
                    let displayOffset = CGSize(width: offset.width + translation.width,
                                               height: offset.height + translation.height)
                    ZStack(alignment: .topLeading) {
                        Image(decorative: source, scale: 1).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(displayZoom).offset(displayOffset)
                        if let preview {
                            Image(decorative: preview, scale: 1).resizable().aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .scaleEffect(displayZoom).offset(displayOffset).allowsHitTesting(false)
                        }
                        ForEach(points) { point in
                            Circle().fill(point.includes ? .green : .red).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .position(displayPosition(point.location, fitted: fitted,
                                                          viewSize: geometry.size,
                                                          zoom: displayZoom,
                                                          offset: displayOffset))
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { tap in
                        let location = imageLocation(tap.location, fitted: fitted,
                                                     viewSize: geometry.size,
                                                     zoom: displayZoom,
                                                     offset: displayOffset)
                        guard !busy, points.count < 8,
                              (0...1).contains(location.x), (0...1).contains(location.y) else { return }
                        points.append(MagicSelectionPoint(location: location, includes: includes))
                        updateMask()
                    })
                    .simultaneousGesture(MagnifyGesture()
                        .updating($magnification) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            zoom = min(6, max(1, zoom * value.magnification))
                            if zoom == 1 { offset = .zero }
                        })
                    .simultaneousGesture(DragGesture(minimumDistance: 8)
                        .updating($translation) { value, state, _ in
                            if zoom > 1 { state = value.translation }
                        }
                        .onEnded { value in
                            guard zoom > 1 else { return }
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                        })
                    .onTapGesture(count: 2) { zoom = 1; offset = .zero }
                }
                Picker("Point mode", selection: $includes) {
                    Text("Add a point").tag(true)
                    Text("Remove a point").tag(false)
                }.pickerStyle(.segmented)
                if preview != nil {
                    Picker("Selection variation", selection: $candidate) {
                        Text("Selection 1").tag(0)
                        Text("Selection 2").tag(1)
                        Text("Selection 3").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: candidate) { _, _ in showCandidate() }
                }
                Toggle("Refine edges", isOn: $refineEdges)
                HStack {
                    Button("Clear points") { points = []; preview = nil }
                        .disabled(points.isEmpty || busy)
                    Spacer()
                    if busy { ProgressView() }
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.black).foregroundStyle(.white)
            .navigationTitle("Magic Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Validate") { validate() }.disabled(points.isEmpty || busy || preview == nil)
                }
            }
            .task {
                do {
                    try await engine.prepare()
                    status = String(localized: "Ready")
                } catch { status = error.localizedDescription }
                busy = false
            }
        }
    }

    private func updateMask() {
        busy = true
        status = String(localized: "Updating selection…")
        let requested = points
        Task {
            do {
                preview = try await engine.select(points: requested)
                candidate = await engine.selectedCandidateIndex()
                status = String(localized: "Selection updated")
            } catch { status = error.localizedDescription }
            busy = false
        }
    }

    private func showCandidate() {
        guard preview != nil, !busy else { return }
        Task {
            do {
                preview = try await engine.selectCandidate(candidate)
                status = String(localized: "Selection updated")
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func validate() {
        busy = true
        status = refineEdges ? String(localized: "Refining edges…") : String(localized: "Preparing mask…")
        Task {
            do { onValidate(try await engine.finalizedMask(refineEdges: refineEdges)) }
            catch { status = error.localizedDescription; busy = false }
        }
    }

    private func aspectFit(_ size: CGSize, in bounds: CGRect) -> CGRect {
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: bounds.midX - fitted.width / 2, y: bounds.midY - fitted.height / 2,
                      width: fitted.width, height: fitted.height)
    }

    private func displayPosition(_ location: CGPoint, fitted: CGRect, viewSize: CGSize,
                                 zoom: CGFloat, offset: CGSize) -> CGPoint {
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let base = CGPoint(x: fitted.minX + location.x * fitted.width,
                           y: fitted.minY + location.y * fitted.height)
        return CGPoint(x: center.x + (base.x - center.x) * zoom + offset.width,
                       y: center.y + (base.y - center.y) * zoom + offset.height)
    }

    private func imageLocation(_ location: CGPoint, fitted: CGRect, viewSize: CGSize,
                               zoom: CGFloat, offset: CGSize) -> CGPoint {
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let base = CGPoint(x: center.x + (location.x - center.x - offset.width) / zoom,
                           y: center.y + (location.y - center.y - offset.height) / zoom)
        return CGPoint(x: (base.x - fitted.minX) / fitted.width,
                       y: (base.y - fitted.minY) / fitted.height)
    }
}
