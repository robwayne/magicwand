import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A circular/rounded remote "key" with an SF Symbol or text label, with press feedback.
struct RemoteKey: View {
    enum Content {
        case symbol(String)
        case text(String)
    }

    let content: Content
    var tint: Color = Theme.textPrimary
    var fill: Color = Theme.surfaceRaised
    var subtitle: String? = nil
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 2) {
                switch content {
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: 20, weight: .medium))
                case .text(let label):
                    Text(label)
                        .font(.system(size: 17, weight: .semibold))
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 56)
            .remoteKeyBackground(fill)
            .scaleEffect(pressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.08)) { pressed = true } }
                .onEnded { _ in withAnimation(.easeOut(duration: 0.12)) { pressed = false } }
        )
    }
}

/// A vertical rocker (Channel / Volume) with +/- or up/down and a centre label.
struct RockerControl: View {
    let topSymbol: String
    let bottomSymbol: String
    let centerLabel: String
    var onTop: () -> Void
    var onBottom: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            rockerButton(symbol: topSymbol, action: onTop)
            Text(centerLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            rockerButton(symbol: bottomSymbol, action: onBottom)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                .fill(Theme.surfaceRaised)
        )
    }

    private func rockerButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Lightweight haptic helper.
enum Haptics {
    static func tap() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
