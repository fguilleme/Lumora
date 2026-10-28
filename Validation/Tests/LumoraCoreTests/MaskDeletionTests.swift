import Testing
import Foundation
import CoreImage
@testable import LumoraCore

@Test func deletingMaskClearsOnlyItsReferencesAndPersists() throws {
    let removed = LocalMask(name: "Removed", components: [.init(shape: .radial(.init()))])
    let kept = LocalMask(name: "Kept", components: [.init(shape: .linear(.init()))])
    var state = EditState()
    state.masks = [removed, kept]
    var local = CreativeEffect(.highKey, maskID: removed.id)
    local["amount"] = 47
    var disabled = CreativeEffect(.lowKey, maskID: removed.id)
    disabled.enabled = false
    let other = CreativeEffect(.grain, maskID: kept.id)
    let global = CreativeEffect(.tonalContrast)
    state.creative.effects = [local, disabled, other, global]
    let didRemove = state.removeMask(id: removed.id)
    #expect(didRemove)
    #expect(state.masks == [kept])
    #expect(state.creative.effects.count == 4)
    for effect in state.creative.effects.prefix(2) {
        #expect(effect.maskID == nil)
        #expect(!effect.enabled)
    }
    #expect(state.creative.effects[0].id == local.id)
    #expect(state.creative.effects[0].parameters == local.parameters)
    #expect(state.creative.effects[2] == other)
    #expect(state.creative.effects[3] == global)
    #expect(try JSONDecoder().decode(EditState.self, from: JSONEncoder().encode(state)) == state.validated)
    let snapshot = state
    let removedAgain = state.removeMask(id: removed.id)
    #expect(!removedAgain)
    #expect(state == snapshot)
}

@Test func deletingMaskAndReferencesIsOneUndoRedoOperation() {
    var state = EditState()
    let mask = LocalMask(name: "Local", components: [.init(shape: .radial(.init()))])
    state.masks = [mask]
    state.creative.effects = [CreativeEffect(.grain, maskID: mask.id)]
    let original = state
    var history = HistoryManager()
    history.begin("Delete layer", state: state)
    state.removeMask(id: mask.id)
    history.commit(state)
    #expect(history.undoStack.count == 1)
    #expect(history.undo() == original)
    #expect(history.redo() == state)
}

@Test func detachedCreativeEffectDoesNotBecomeGlobal() throws {
    let mask = LocalMask(name: "Local", components: [.init(shape: .radial(.init()))])
    var state = EditState()
    state.masks = [mask]
    state.creative.effects = [CreativeEffect(.highKey, maskID: mask.id)]
    state.removeMask(id: mask.id)
    let input = CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.6))
        .cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
    let output = try CreativeStackRenderer.apply(input, stack: state.creative, masks: state.masks)
    // Disabled detached effects return the original CI graph, without a renderer.
    #expect(output === input)
}
