import SwiftUI

/// Central design tokens so every screen shares the same dark look from the reference app.
enum Theme {
    // Accent / brand
    static let accent = Color(red: 0.357, green: 0.404, blue: 0.949)      // indigo/blue
    static let danger = Color(red: 0.93, green: 0.27, blue: 0.27)         // power red

    // Backgrounds
    static let background = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.15)
    static let surfaceRaised = Color(red: 0.16, green: 0.16, blue: 0.21)
    static let trackpad = Color(red: 0.14, green: 0.15, blue: 0.20)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)

    // Gradients used on the onboarding / casting screens.
    static let onboardingGradient = LinearGradient(
        colors: [
            Color(red: 0.13, green: 0.16, blue: 0.42),
            Color(red: 0.06, green: 0.06, blue: 0.12),
            Color.black
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let castGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.10, blue: 0.20),
            Color(red: 0.05, green: 0.05, blue: 0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Corner radii
    static let buttonRadius: CGFloat = 22
    static let cardRadius: CGFloat = 28
}

extension View {
    /// Standard rounded "key" background used by most remote buttons.
    func remoteKeyBackground(_ fill: Color = Theme.surfaceRaised) -> some View {
        background(
            RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                .fill(fill)
        )
    }
}
