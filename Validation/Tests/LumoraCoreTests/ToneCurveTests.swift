import Testing
import Foundation
@testable import LumoraCore

@Test func curveIdentityAndKnots() {
    let identity = ToneCurve()
    for i in 0...1024 {
        let x = Double(i) / 1024
        #expect(abs(identity.evaluate(x) - x) < 1e-12)
    }
    let curve = ToneCurve(points: [.init(x: 0, y: 0.1), .init(x: 0.2, y: 0.1), .init(x: 0.55, y: 0.8), .init(x: 1, y: 0.9)])
    for point in curve.points { #expect(abs(curve.evaluate(point.x) - point.y) < 1e-10) }
    let samples = (0...1024).map { curve.evaluate(Double($0) / 1024) }
    for pair in zip(samples, samples.dropFirst()) { #expect(pair.1 >= pair.0 - 1e-12) }
}

@Test func curvesDoNotOvershootAndHaveContinuousTangents() {
    let curve = ToneCurve(points: [.init(x: 0, y: 0.1), .init(x: 0.2, y: 0.9), .init(x: 0.6, y: 0.2), .init(x: 1, y: 0.8)])
    for index in 0..<(curve.points.count - 1) {
        let a = curve.points[index], b = curve.points[index + 1]
        for i in 0...100 {
            let value = curve.evaluate(a.x + (b.x - a.x) * Double(i) / 100)
            #expect(value >= min(a.y, b.y) - 1e-10 && value <= max(a.y, b.y) + 1e-10)
        }
    }
    for point in curve.points.dropFirst().dropLast() {
        let epsilon = 0.000001
        let left = (curve.evaluate(point.x) - curve.evaluate(point.x - epsilon)) / epsilon
        let right = (curve.evaluate(point.x + epsilon) - curve.evaluate(point.x)) / epsilon
        #expect(abs(left - right) < 0.001)
    }
}

@Test func curvePointEditingEnforcesBounds() {
    var curve = ToneCurve()
    #expect(curve.add(x: 0.5, y: 0.6) == 1)
    #expect(curve.add(x: 0.501, y: 0.8) == nil)
    curve.move(index: 1, x: 2, y: -10)
    #expect(curve.points[1].x == 0.98 && curve.points[1].y == 0)
    curve.move(index: 0, x: 0.4, y: 0.2)
    #expect(curve.points[0].x == 0)
    curve.remove(index: 0)
    #expect(curve.points.count == 3)
    curve.remove(index: 1)
    #expect(curve.points.count == 2)
    curve.move(index: 50, x: 0, y: 0)
    #expect(curve.points.count == 2)
}

@Test func corruptCurveCoordinatesAreNormalized() throws {
    let data = Data(#"{"points":[{"x":1.5,"y":-3},{"x":0,"y":2},{"x":0.001,"y":0.3},{"x":0.4,"y":0.5}]}"#.utf8)
    let curve = try JSONDecoder().decode(ToneCurve.self, from: data)
    #expect(curve.points.count == 3)
    #expect(curve.points.first?.x == 0 && curve.points.last?.x == 1)
    for pair in zip(curve.points, curve.points.dropFirst()) { #expect(pair.1.x - pair.0.x >= ToneCurve.minimumSpacing) }
    for point in curve.points { #expect((0...1).contains(point.y)) }
    #expect(ToneCurve(points: [.init(x: .nan, y: 0)]).isIdentity)
}

@Test func curveSerializationAndLegacyMigration() throws {
    let oldJSON = Data(#"{"exposure":1.25,"contrast":15,"highlights":-20,"shadows":35,"whites":0,"blacks":0,"temperature":7,"tint":0,"vibrance":12,"saturation":0}"#.utf8)
    var state = try JSONDecoder().decode(EditState.self, from: oldJSON)
    #expect(state.exposure == 1.25 && state.shadows == 35 && state.curves.isIdentity)
    state.curves.red = ToneCurve(points: [.init(x: 0, y: 0), .init(x: 0.5, y: 0.7), .init(x: 1, y: 1)])
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state)
}

@Test func lookupMatchesCurveAndChannelIsolation() {
    var curves = ToneCurves()
    curves.red = ToneCurve(points: [.init(x: 0, y: 0), .init(x: 0.5, y: 0.7), .init(x: 1, y: 1)])
    let lookup = CurveLookup(curves)
    for i in 0...1024 {
        let x = Double(i) / 1024
        let output = lookup.apply(x, x, x)
        #expect(abs(output.0 - curves.red.evaluate(x)) < 0.00001)
        #expect(abs(output.1 - x) < 1e-10 && abs(output.2 - x) < 1e-10)
    }
    curves.rgb = ToneCurve(points: [.init(x: 0, y: 0.1), .init(x: 1, y: 0.9)])
    let output = CurveLookup(curves).apply(0.2, 0.2, 0.2)
    #expect(abs(output.0 - curves.red.evaluate(curves.rgb.evaluate(0.2))) < 0.00001)
}

@Test func historyGroupsCurveGestureAndRestoresAllChannels() {
    var history = HistoryManager(), state = EditState()
    state.exposure = 0.5
    let before = state
    history.begin("Courbe rouge", state: state)
    state.curves.red.add(x: 0.5, y: 0.5)
    for i in 1...40 { state.curves.red.move(index: 1, x: 0.5, y: 0.5 + Double(i) / 100) }
    history.commit(state)
    #expect(history.undoStack.count == 1)
    #expect(history.undo() == before)
    #expect(history.redo() == state)
}
