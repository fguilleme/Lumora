import Foundation

struct CurvePoint: Codable, Sendable, Equatable {
    var x: Double
    var y: Double
}

enum CurveChannel: String, Codable, CaseIterable, Sendable, Identifiable {
    case rgb, red, green, blue
    var id: String { rawValue }
    var title: String {
        switch self { case .rgb: "RGB"; case .red: "Red"; case .green: "Green"; case .blue: "Blue" }
    }
}

/// Shape-preserving cubic Hermite interpolation. Local extrema have zero tangent:
/// no ringing or overshoot between control points, even for non-monotonic curves.
struct ToneCurve: Codable, Sendable, Equatable {
    private(set) var points: [CurvePoint]
    static let minimumSpacing = 0.02
    static let maximumPoints = 16
    init(points: [CurvePoint] = [CurvePoint(x: 0, y: 0), CurvePoint(x: 1, y: 1)]) {
        let finite = points.filter { $0.x.isFinite && $0.y.isFinite }
            .map { CurvePoint(x: min(1, max(0, $0.x)), y: min(1, max(0, $0.y))) }
            .sorted { $0.x < $1.x }
        var clean: [CurvePoint] = []
        for point in finite {
            if let previous = clean.last, point.x - previous.x < Self.minimumSpacing { continue }
            clean.append(point)
        }
        guard clean.count >= 2 else {
            self.points = [CurvePoint(x: 0, y: 0), CurvePoint(x: 1, y: 1)]
            return
        }
        clean[0].x = 0
        clean[clean.count - 1].x = 1
        if clean.count > Self.maximumPoints {
            clean = Array(clean.prefix(Self.maximumPoints - 1)) + [clean[clean.count - 1]]
        }
        self.points = clean
    }
    private enum CodingKeys: String, CodingKey { case points }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(points: try container.decode([CurvePoint].self, forKey: .points))
    }
    var isIdentity: Bool { points.allSatisfy { $0.x == $0.y } }

    @discardableResult
    mutating func add(x: Double, y: Double) -> Int? {
        guard points.count < Self.maximumPoints, x.isFinite, y.isFinite,
              x >= Self.minimumSpacing, x <= 1 - Self.minimumSpacing,
              points.allSatisfy({ abs($0.x - x) >= Self.minimumSpacing }) else { return nil }
        let index = points.firstIndex { $0.x > x } ?? (points.count - 1)
        points.insert(CurvePoint(x: x, y: min(1, max(0, y))), at: index)
        return index
    }
    mutating func move(index: Int, x: Double, y: Double) {
        guard points.indices.contains(index), x.isFinite, y.isFinite else { return }
        if index > 0 && index < points.count - 1 {
            points[index].x = min(points[index + 1].x - Self.minimumSpacing,
                                  max(points[index - 1].x + Self.minimumSpacing, x))
        }
        points[index].y = min(1, max(0, y))
    }
    mutating func remove(index: Int) {
        guard index > 0, index < points.count - 1 else { return }
        points.remove(at: index)
    }

    func evaluate(_ input: Double) -> Double {
        guard input.isFinite else { return 0 }
        let x = min(1, max(0, input))
        if isIdentity { return x }
        let index = min(points.count - 2, max(0, (points.firstIndex { $0.x >= x } ?? (points.count - 1)) - 1))
        let a = points[index], b = points[index + 1]
        let h = b.x - a.x, t = (x - a.x) / h
        let t2 = t * t, t3 = t2 * t
        let value = (2 * t3 - 3 * t2 + 1) * a.y + (t3 - 2 * t2 + t) * h * tangent(index)
            + (-2 * t3 + 3 * t2) * b.y + (t3 - t2) * h * tangent(index + 1)
        return min(max(a.y, b.y), max(min(a.y, b.y), value))
    }
    private func slope(_ index: Int) -> Double {
        (points[index + 1].y - points[index].y) / (points[index + 1].x - points[index].x)
    }
    private func tangent(_ index: Int) -> Double {
        if points.count == 2 { return slope(0) }
        if index == 0 { return endpoint(h0: points[1].x - points[0].x, h1: points[2].x - points[1].x, d0: slope(0), d1: slope(1)) }
        if index == points.count - 1 {
            return endpoint(h0: points[index].x - points[index - 1].x,
                            h1: points[index - 1].x - points[index - 2].x,
                            d0: slope(index - 1), d1: slope(index - 2))
        }
        let before = slope(index - 1), after = slope(index)
        guard before * after > 0 else { return 0 }
        let h0 = points[index].x - points[index - 1].x, h1 = points[index + 1].x - points[index].x
        let w0 = 2 * h1 + h0, w1 = h1 + 2 * h0
        return (w0 + w1) / (w0 / before + w1 / after)
    }
    private func endpoint(h0: Double, h1: Double, d0: Double, d1: Double) -> Double {
        let value = ((2 * h0 + h1) * d0 - h0 * d1) / (h0 + h1)
        if value * d0 <= 0 { return 0 }
        if d0 * d1 < 0 && abs(value) > abs(3 * d0) { return 3 * d0 }
        return value
    }
}

struct ToneCurves: Codable, Sendable, Equatable {
    var rgb = ToneCurve()
    var red = ToneCurve()
    var green = ToneCurve()
    var blue = ToneCurve()
    var isIdentity: Bool { rgb.isIdentity && red.isIdentity && green.isIdentity && blue.isIdentity }
    subscript(_ channel: CurveChannel) -> ToneCurve {
        get { switch channel { case .rgb: rgb; case .red: red; case .green: green; case .blue: blue } }
        set { switch channel { case .rgb: rgb = newValue; case .red: red = newValue; case .green: green = newValue; case .blue: blue = newValue } }
    }
}

/// Prepared once per render state, not once per pixel or cube sample.
struct CurveLookup: Sendable {
    private let tables: [[Double]]
    init(_ curves: ToneCurves) {
        tables = CurveChannel.allCases.map { channel in
            (0...1023).map { curves[channel].evaluate(Double($0) / 1023) }
        }
    }
    func value(_ input: Double, channel: Int) -> Double {
        let position = min(1, max(0, input)) * 1023
        let low = Int(position), high = min(1023, low + 1)
        return tables[channel][low] + (tables[channel][high] - tables[channel][low]) * (position - Double(low))
    }
    func apply(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        (value(value(r, channel: 0), channel: 1), value(value(g, channel: 0), channel: 2), value(value(b, channel: 0), channel: 3))
    }
}
