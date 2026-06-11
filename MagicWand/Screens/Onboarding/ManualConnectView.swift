import SwiftUI
import UIKit

/// Manual IP-entry fallback. Reached from the Library "+" button and the
/// "I don't see the device" link on the discovery screen — useful when SSDP
/// multicast discovery isn't available.
struct ManualConnectView: View {
    @Environment(TVConnectionManager.self) private var connection
    @Environment(\.dismiss) private var dismiss

    @State private var host = ""
    @State private var name = "LG TV UP7500PVG"

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Capsule()
                    .fill(Theme.textTertiary)
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                Text("Add TV by IP address")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text("Find the TV's IP under Settings › Network on your LG TV.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    field("TV name", text: $name, keyboard: .default)
                    field("IP address (e.g. 192.168.1.42)", text: $host, keyboard: .numbersAndPunctuation)
                }

                Button {
                    let trimmed = host.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    connection.connectManually(host: trimmed,
                                               name: name.isEmpty ? "LG TV" : name)
                    dismiss()
                } label: {
                    Text("Connect")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(host.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding()
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Theme.textPrimary)
    }
}
