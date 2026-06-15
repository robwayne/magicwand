import SwiftUI

/// The central navigation control from the remote screen: four tappable directional
/// arrows around a central OK/ENTER button. Each press is sent to the TV over the
/// webOS pointer-input socket. Holding an arrow auto-repeats it, like a held remote key.
struct DirectionalPad: View {
    var onDirection: (RemoteButton) -> Void
    var onSelect: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Theme.trackpad)
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )

            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    Color.clear
                    arrow(.up, "chevron.up")
                    Color.clear
                }
                GridRow {
                    arrow(.left, "chevron.left")
                    centerButton
                    arrow(.right, "chevron.right")
                }
                GridRow {
                    Color.clear
                    arrow(.down, "chevron.down")
                    Color.clear
                }
            }
            .padding(10)
        }
        .frame(height: 188) // 25% smaller than the original 250pt
        .contentShape(Rectangle())
    }

    // MARK: - Pieces

    private func arrow(_ button: RemoteButton, _ symbol: String) -> some View {
        HoldRepeatButton {
            onDirection(button)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
    }

    private var centerButton: some View {
        Button {
            Haptics.tap()
            onSelect()
        } label: {
            Text("OK")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                        .padding(8)
                )
                .contentShape(Circle())
        }
        .buttonStyle(PadPressStyle())
    }
}

/// Press feedback for the pad buttons.
private struct PadPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
