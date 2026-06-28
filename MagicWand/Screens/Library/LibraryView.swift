import SwiftUI

/// The Library tab (replaces the reference app's Settings tab). Lists every TV the
/// phone has connected to before, with the active one highlighted. Tapping a TV
/// reconnects to it; swiping removes it from local storage.
struct LibraryView: View {
    @Environment(TVStore.self) private var store
    @Environment(TVConnectionManager.self) private var connection

    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.onboardingGradient.ignoresSafeArea()

                if store.devices.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("My TVs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddSheet) {
                ManualConnectView()
                    .presentationDetents([.height(300)])
            }
        }
    }

    private var list: some View {
        List {
            ConnectNewTVButton {
                connection.beginNewConnection()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))

            ForEach(store.sortedForLibrary) { device in
                NavigationLink {
                    DeviceDetailView(deviceID: device.id)
                } label: {
                    TVLibraryRow(
                        device: device,
                        isActive: connection.activeDevice?.id == device.id
                    )
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv.inset.filled")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textSecondary)
            Text("No TVs yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("TVs you connect to will appear here so you can reconnect with one tap.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 40)
            VStack(spacing: 12) {
                Button {
                    connection.beginNewConnection()
                } label: {
                    Label("Connect a New TV", systemImage: "tv.badge.wifi")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                Button("Add by IP address") { showAddSheet = true }
                    .font(.system(size: 15, weight: .medium))
                    .tint(Theme.textSecondary)
            }
            .padding(.horizontal, 50)
            .padding(.top, 8)
        }
    }

    private func delete(at offsets: IndexSet) {
        let sorted = store.sortedForLibrary
        for index in offsets {
            store.remove(sorted[index])
        }
    }
}

/// A single saved-TV row in the Library.
private struct TVLibraryRow: View {
    let device: TVDevice
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceRaised)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "tv")
                        .font(.system(size: 22))
                        .foregroundStyle(isActive ? Theme.accent : Theme.textPrimary)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(device.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(isActive ? Theme.accent : Theme.textSecondary)
            }

            Spacer()

            if isActive {
                Text("Connected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            // Inline refresh: reconnect to this TV without opening the detail view.
            RefreshConnectionButton(device: device)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isActive ? 0.08 : 0.04))
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private var subtitle: String {
        let prefix = vendorTag(device.vendor)
        if isActive { return "\(prefix) · Active now" }
        if let date = device.lastConnected {
            return "\(prefix) · Last used \(date.formatted(.relative(presentation: .named)))"
        }
        return device.isPaired ? "\(prefix) · \(device.host)" : "\(prefix) · \(device.host) · Not paired"
    }

    private func vendorTag(_ vendor: TVVendor) -> String {
        switch vendor {
        case .lg: "LG"
        case .samsung: "Samsung"
        case .generic: "Smart TV"
        }
    }
}

/// The prominent "Connect a New TV" call-to-action at the top of the Library list.
/// Kicks off discovery + pairing for a TV that isn't saved yet.
private struct ConnectNewTVButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "tv.badge.wifi")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Connect a New TV")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Search your Wi-Fi for another TV")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.accent.opacity(0.10))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibraryView()
        .environment(TVStore())
        .environment(TVConnectionManager())
}
