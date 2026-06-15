import SwiftUI

/// Detail screen for a saved TV. Shows device info (only the nickname is editable) and
/// three toolbar actions: refresh the connection (icon reflects success/failure),
/// re-establish/re-pair, and delete the device.
struct DeviceDetailView: View {
    let deviceID: UUID

    @Environment(TVStore.self) private var store
    @Environment(TVConnectionManager.self) private var connection
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String = ""
    @State private var refreshState: RefreshState = .idle
    @State private var monitoringRefresh = false
    @State private var showDeleteConfirm = false

    private enum RefreshState: Equatable {
        case idle, failed, success
        var color: Color {
            switch self {
            case .idle: Theme.textPrimary
            case .failed: Theme.danger
            case .success: .green
            }
        }
    }

    private var device: TVDevice? { store.device(withID: deviceID) }
    private var isActive: Bool { connection.activeDevice?.id == deviceID && connection.status.isConnected }

    var body: some View {
        ZStack {
            Theme.onboardingGradient.ignoresSafeArea()

            if let device {
                List {
                    Section {
                        infoRow("Name", value: device.name)
                        nicknameRow
                        infoRow("Type", value: device.deviceType ?? "webOS Smart TV")
                        infoRow("Model", value: device.modelName.isEmpty ? "—" : device.modelName)
                        infoRow("Size", value: device.screenSize ?? "—")
                    } header: {
                        statusHeader(device)
                    }

                    Section("Network") {
                        infoRow("Current IP Address", value: device.host)
                        infoRow("IP Type", value: device.ipType ?? "IPv4")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            } else {
                Color.clear
            }
        }
        .navigationTitle(device?.displayName ?? "TV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarButtons }
        .onAppear { nickname = device?.nickname ?? "" }
        .onChange(of: connection.status) { _, newValue in handleStatusChange(newValue) }
        .onDisappear(perform: saveNickname)
        .alert("Delete this TV?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive, action: deleteDevice)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes it from your Library and forgets its pairing on this phone.")
        }
    }

    // MARK: - Rows

    private func statusHeader(_ device: TVDevice) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.green : Theme.textTertiary)
                .frame(width: 8, height: 8)
            Text(isActive ? "Connected" : "Not connected")
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    private var nicknameRow: some View {
        HStack {
            Text("Nickname").foregroundStyle(Theme.textSecondary)
            Spacer()
            TextField("Add a nickname", text: $nickname)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.accent)
                .submitLabel(.done)
                .onSubmit(saveNickname)
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: refreshConnection) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(refreshState.color)
            }
            .accessibilityLabel("Refresh connection")

            Button(action: reestablish) {
                Image(systemName: "wifi.router")
            }
            .accessibilityLabel("Re-establish connection")

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.danger)
            }
            .accessibilityLabel("Delete device")
        }
    }

    // MARK: - Actions

    private func refreshConnection() {
        guard let device else { return }
        saveNickname()
        monitoringRefresh = true
        refreshState = .idle
        connection.connect(to: device)
    }

    private func reestablish() {
        guard let device else { return }
        saveNickname()
        connection.reestablish(device)
    }

    private func deleteDevice() {
        guard let device else { return }
        if connection.activeDevice?.id == device.id {
            connection.disconnect()
        }
        store.remove(device)
        dismiss()
    }

    private func saveNickname() {
        guard var device else { return }
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        device.nickname = trimmed.isEmpty ? nil : trimmed
        store.update(device)
    }

    private func handleStatusChange(_ status: TVConnectionManager.Status) {
        guard monitoringRefresh else { return }
        switch status {
        case .connected where connection.activeDevice?.id == deviceID:
            refreshState = .success
            monitoringRefresh = false
            // Hold green for 10s, then return to the default colour.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                if refreshState == .success { refreshState = .idle }
            }
        case .failed:
            // Stay red until a later successful reconnect.
            refreshState = .failed
        default:
            break
        }
    }
}
