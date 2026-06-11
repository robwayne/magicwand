import SwiftUI

/// The little dashed progress indicator shown at the top of the onboarding screens.
struct StepDots: View {
    let total: Int
    let current: Int   // 0-based

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.textPrimary : Theme.textTertiary)
                    .frame(width: i == current ? 20 : 12, height: 4)
            }
        }
    }
}
