import SwiftUI
import UIKit

/// Manual IP-entry fallback. Reached from the Library "+" button and the
/// "I don't see the device" link on the discovery screen. The vendor picker selects
/// which control backend to use (LG webOS vs. Samsung Tizen).
struct ManualConnectView: View {
    @Environment(TVConnectionManager.self) private var connection
    @Environment(\.dismiss) private var dismiss

    @State private var host = ""
    @State private var name = ""
    @State private var vendor: TVVendor = .lg

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

                Text("Find the TV's IP under Settings › Network on your TV.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 20)

                Picker("Brand", selection: $vendor) {
                    Text("LG (webOS)").tag(TVVendor.lg)
                    Text("Samsung (Tizen)").tag(TVVendor.samsung)
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    field("TV name (optional)", text: $name, keyboard: .default)
                    field("IP address (e.g. 192.168.1.42)", text: $host, keyboard: .numbersAndPunctuation)
                }

                Button {
                    let trimmedHost = host.trimmingCharacters(in: .whitespaces)
                    guard !trimmedHost.isEmpty else { return }
                    let displayName: String = {
                        let n = name.trimmingCharacters(in: .whitespaces)
                        if !n.isEmpty { return n }
                        return vendor == .samsung ? "Samsung TV" : "LG TV"
                    }()
                    connection.connectManually(host: trimmedHost, name: displayName, vendor: vendor)
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
