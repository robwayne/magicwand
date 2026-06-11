import SwiftUI

/// "Let's pair your phone with the TV" screen (IMG_9693). The TV is now showing a PIN;
/// the user types it here and we send it back over SSAP to complete pairing.
struct PairingView: View {
    @Environment(TVConnectionManager.self) private var connection
    @State private var pin = ""
    @FocusState private var focused: Bool

    private let maxDigits = 8

    var body: some View {
        VStack(spacing: 20) {
            StepDots(total: 4, current: 3)
                .padding(.top, 24)

            Text("Let's pair your phone with the TV")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 30)

            PairingIllustration()
                .frame(height: 200)
                .padding(.horizontal, 24)

            // The PIN field. Tapping anywhere focuses the hidden text field.
            ZStack {
                TextField("", text: $pin)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .opacity(0.02)
                    .onChange(of: pin) { _, newValue in
                        pin = String(newValue.filter(\.isNumber).prefix(maxDigits))
                    }

                HStack(spacing: 10) {
                    Text(pin.isEmpty ? " " : spacedPIN)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .kerning(6)
                    if focused {
                        Capsule().fill(Theme.accent).frame(width: 2, height: 34)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture { focused = true }
            }
            .padding(.horizontal, 24)

            VStack(spacing: 2) {
                Text("Look at **the code displayed on your TV**")
                Text("and enter it here")
            }
            .font(.system(size: 17))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.textSecondary)

            if case .failed(let message) = connection.status {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }

            Button {
                connection.submitPIN(pin)
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(pin.count >= 4 ? Theme.accent : Theme.textTertiary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.surface, in: Capsule())
            }
            .disabled(pin.count < 4)

            Spacer()
        }
        .onAppear { focused = true }
    }

    private var spacedPIN: String {
        pin.map(String.init).joined(separator: " ")
    }
}

/// The TV→phone pairing illustration with the "XXXX" code hint.
private struct PairingIllustration: View {
    var body: some View {
        HStack(spacing: 0) {
            // TV showing a code.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.08, green: 0.12, blue: 0.35), .black],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    VStack(spacing: 10) {
                        ForEach(0..<2) { _ in
                            Capsule().fill(.white.opacity(0.12)).frame(height: 8)
                        }
                        Text("X X X X")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(8)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(20)
                )
                .frame(width: 180, height: 130)
                .overlay(
                    RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.1))
                )

            Image(systemName: "arrow.right")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 6)

            // Phone receiving the code.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
                .frame(width: 72, height: 150)
                .overlay(
                    VStack(spacing: 6) {
                        Text("• • • •")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12))
                )
        }
    }
}
