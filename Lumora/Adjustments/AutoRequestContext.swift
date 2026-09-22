import Foundation

/// A result is applicable only to the exact editing context that requested it.
/// Kept separate from the analysis cache key: Undo can revisit equal settings while
/// a newer edit/import/request must still invalidate an older pending application.
struct AutoRequestContext: Sendable, Equatable {
    let request: Int
    let renderGeneration: Int
    let importGeneration: Int
    let documentID: UUID
    let sourceURL: URL
    let selectedLayer: UUID?
    let state: EditState

    func permits(_ current: Self) -> Bool { self == current }
}
