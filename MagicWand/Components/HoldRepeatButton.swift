import SwiftUI

/// A button that fires once on a tap and then auto-repeats while held — emulating a
/// held physical remote key. The webOS pointer socket only sends discrete button events,
/// so "holding" is reproduced by re-sending the command on a steady interval until release.
struct HoldRepeatButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    /// Delay before auto-repeat kicks in, then the repeat interval.
    var initialDelay: Double = 0.4
    var interval: Double = 0.11

    @State private var pressing = false
    @State private var didStart = false
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        label()
            .scaleEffect(pressing ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: pressing)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !didStart else { return }
                        didStart = true
                        pressing = true
                        begin()
                    }
                    .onEnded { _ in end() }
            )
    }

    private func begin() {
        Haptics.tap()
        action() // immediate first press
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(initialDelay))
            while !Task.isCancelled {
                action()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func end() {
        didStart = false
        pressing = false
        repeatTask?.cancel()
        repeatTask = nil
    }
}
