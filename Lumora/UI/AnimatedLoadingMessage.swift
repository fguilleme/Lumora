import SwiftUI

/// An indeterminate message describes the real operation, without inventing
/// stages or percentages. Its animation stays local to this lightweight view.
struct AnimatedLoadingMessage: View {
    private let message: String
    private let compact: Bool
    private let delayMilliseconds: Int
    private let inCapsule: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0
    @State private var visible: Bool

    init(_ message: String, compact: Bool = false, delayMilliseconds: Int = 0, inCapsule: Bool = false) {
        self.message = NSLocalizedString(message, comment: "Loading operation")
        self.compact = compact
        self.delayMilliseconds = delayMilliseconds
        self.inCapsule = inCapsule
        _visible = State(initialValue: delayMilliseconds == 0)
    }

    private var title: String {
        if message.hasSuffix("…") { return String(message.dropLast()) }
        if message.hasSuffix("...") { return String(message.dropLast(3)) }
        return message
    }

    var body: some View {
        Group {
            if visible {
                HStack(spacing: compact ? 6 : 9) {
                    Text(verbatim: title)
                        .font(compact ? .caption : .subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(compact ? 1 : nil)
                    HStack(spacing: 3) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(.mint)
                                .frame(width: compact ? 4 : 5, height: compact ? 4 : 5)
                                .opacity(reduceMotion || index == phase ? 1 : 0.25)
                        }
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: phase)
                    .accessibilityHidden(true)
                }
                .padding(.horizontal, inCapsule ? 12 : 0)
                .padding(.vertical, inCapsule ? 8 : 0)
                .background(inCapsule ? Color.black.opacity(0.78) : .clear, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: message))
                .accessibilityIdentifier("loading-message")
            }
        }
        .task(id: reduceMotion) {
            do {
                if !visible {
                    try await Task.sleep(for: .milliseconds(delayMilliseconds))
                    try Task.checkCancellation()
                    visible = true
                }
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(380))
                    try Task.checkCancellation()
                    phase = (phase + 1) % 3
                }
            } catch is CancellationError {
            } catch {
                // The presentation never changes the operation's error state.
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    VStack(spacing: 24) {
        AnimatedLoadingMessage("Opening original…")
        AnimatedLoadingMessage("Analyzing faces…", compact: true)
    }.padding().preferredColorScheme(.dark)
}
