import SwiftUI

/// A 0–9 number pad for direct channel entry, presented from the "123" key.
struct NumberPadView: View {
    var onDigit: (RemoteButton) -> Void
    @Environment(\.dismiss) private var dismiss

    private let rows: [[RemoteButton]] = [
        [.num1, .num2, .num3],
        [.num4, .num5, .num6],
        [.num7, .num8, .num9],
        [.dash, .num0, .asterisk]
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 14) {
                Capsule()
                    .fill(Theme.textTertiary)
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                Text("Enter Channel")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                ForEach(rows.indices, id: \.self) { r in
                    HStack(spacing: 14) {
                        ForEach(rows[r], id: \.self) { button in
                            // Hold to auto-repeat, emulating a held physical number key.
                            HoldRepeatButton {
                                onDigit(button)
                            } label: {
                                Text(label(for: button))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .remoteKeyBackground()
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func label(for button: RemoteButton) -> String {
        switch button {
        case .dash: "-"
        case .asterisk: "*"
        default: button.rawValue
        }
    }
}

#Preview {
    NumberPadView { _ in }
}
