import Foundation

struct EditCommand: Sendable, Equatable {
    let name: String
    let before: EditState
    let after: EditState
}

struct HistoryManager: Sendable {
    private(set) var undoStack: [EditCommand] = []
    private(set) var redoStack: [EditCommand] = []
    private var transaction: (String, EditState)?
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func begin(_ name: String, state: EditState) {
        if transaction == nil { transaction = (name, state) }
    }
    mutating func commit(_ state: EditState) {
        guard let (name, before) = transaction else { return }
        transaction = nil
        guard before != state else { return }
        undoStack.append(EditCommand(name: name, before: before, after: state))
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
    }
    mutating func undo() -> EditState? {
        guard let command = undoStack.popLast() else { return nil }
        redoStack.append(command)
        return command.before
    }
    mutating func redo() -> EditState? {
        guard let command = redoStack.popLast() else { return nil }
        undoStack.append(command)
        return command.after
    }
}
