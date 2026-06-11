import SwiftUI

/// "Connect your TV" screen (IMG_9692). Lists discovered TVs, with Refresh and an
/// "I don't see the device" manual-entry fallback.
struct SelectTVView: View {
    @Environment(TVConnectionManager.self) private var connection
    @State private var showManual = false

    var body: some View {
        VStack(spacing: 0) {
            StepDots(total: 4, current: 2)
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Connect your TV")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("To continue please select your Smart TV from the list below")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 36)
            }
            .padding(.top, 16)

            card
                .padding(.horizontal, 18)
                .padding(.top, 28)

            Spacer()

            Button {
                showManual = true
            } label: {
                Text("I don't see the device")
                    .font(.system(size: 14, weight: .medium))
                    .underline()
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showManual) {
            ManualConnectView()
                .presentationDetents([.height(300)])
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            Text("Make sure your device is active and connected to the same WiFi network as your phone or tablet")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .padding(20)

            Divider().overlay(Color.white.opacity(0.06))

            if connection.discovered.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.textSecondary)
                    Text("Searching for TVs…")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(connection.discovered) { tv in
                    Button {
                        connection.connect(to: tv)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tv.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("Not Connected")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if isConnectingTo(tv) {
                                ProgressView().tint(Theme.textSecondary)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Color.white.opacity(0.06))
                }
            }

            Button {
                connection.startDiscovery()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Refresh")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .background(Color.white.opacity(0.04))
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func isConnectingTo(_ tv: DiscoveredTV) -> Bool {
        connection.status == .connecting && connection.activeDevice?.host == tv.host
    }
}
