import SwiftUI

/// The large central navigation surface from the remote screen.
///
/// Acts as both a D-pad (tap the edges / swipe to move focus and send UP/DOWN/LEFT/RIGHT)
/// and a tap-to-select in the middle (ENTER). Edge chevrons hint at the directions.
struct DirectionalPad: View {
    var onDirection: (RemoteButton) -> Void
    var onSelect: () -> Void

    @State private var dragStart: CGPoint?
    private let swipeThreshold: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Theme.trackpad)
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
                )

            // Directional chevrons.
            VStack {
                chevron("chevron.up")
                Spacer()
                chevron("chevron.down")
            }
            .padding(.vertical, 18)

            HStack {
                chevron("chevron.left")
                Spacer()
                chevron("chevron.right")
            }
            .padding(.horizontal, 18)

            // Centre select dot.
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 10, height: 10)
        }
        .frame(height: 230)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStart == nil { dragStart = value.startLocation }
                }
                .onEnded { value in
                    defer { dragStart = nil }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    // A near-stationary touch counts as a centre press.
                    if abs(dx) < swipeThreshold && abs(dy) < swipeThreshold {
                        Haptics.tap()
                        onSelect()
                        return
                    }
                    Haptics.tap()
                    if abs(dx) > abs(dy) {
                        onDirection(dx > 0 ? .right : .left)
                    } else {
                        onDirection(dy > 0 ? .down : .up)
                    }
                }
        )
    }

    private func chevron(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
    }
}
