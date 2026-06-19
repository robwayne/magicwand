import SwiftUI

/// A button that fires once on a tap and then auto-repeats while held — emulating a
/// held physical remote key. The webOS pointer socket only sends discrete button events,
/// so "holding" is reproduced by re-sending the command on a steady interval until release.
///
/// Uses `onLongPressGesture(onPressingChanged:)` because it's the most reliable press/
/// release primitive in SwiftUI and survives being placed inside a `.sheet` (a plain
/// DragGesture(minimumDistance: 0) can be swallowed by the sheet's own drag gesture).
struct HoldRepeatButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    /// Delay before auto-repeat kicks in, then the repeat interval.
    var initialDelay: Double = 0.4
    var interval: Double = 0.11

    @State private var pressing = false
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        label()
            .scaleEffect(pressing ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: pressing)
            .contentShape(Rectangle())
            // A very large minimumDuration means `perform` never fires; we only use
            // `onPressingChanged` for the press/release transitions.
            .onLongPressGesture(minimumDuration: 100_000, maximumDistance: .infinity) {
                // intentionally empty — `perform` never runs in this configuration
            } onPressingChanged: { isPressing in
                if isPressing { begin() } else { end() }
            }
    }

    private func begin() {
        guard !pressing else { return }
        pressing = true
        Haptics.tap()
        action() // immediate first press
        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(initialDelay))
            while !Task.isCancelled {
                action()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func end() {
        pressing = false
        repeatTask?.cancel()
        repeatTask = nil
    }
}
