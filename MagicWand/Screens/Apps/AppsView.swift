import SwiftUI

/// The "My Apps" list. Searchable, and (in edit mode) reorderable with add/remove.
/// Tapping a row launches that app on the TV. The first five apps double as the
/// floating quick-launch shortcuts, so order here drives the shortcuts.
struct AppsView: View {
    @Environment(TVConnectionManager.self) private var connection
    @Environment(AppsStore.self) private var appsStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var showAddSheet = false
    @State private var showInstalled = false
    @State private var editMode: EditMode = .inactive

    private var filtered: [StreamingApp] {
        guard !query.isEmpty else { return appsStore.apps }
        return appsStore.apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Reordering is only meaningful (and safe) when not filtering.
    private var canReorder: Bool { query.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.onboardingGradient.ignoresSafeArea()
                VStack(spacing: 14) {
                    searchField
                    installedAppsButton
                    list
                }
                .padding(.top, 8)
            }
            .navigationTitle("My Apps")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(Theme.textPrimary)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus").foregroundStyle(Theme.textPrimary)
                    }
                    .disabled(appsStore.available.isEmpty)

                    Button {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    } label: {
                        Text(editMode.isEditing ? "Done" : "Edit")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddAppSheet()
            }
            .sheet(isPresented: $showInstalled) {
                InstalledAppsSheet()
            }
        }
    }

    private var installedAppsButton: some View {
        Button {
            connection.refreshInstalledApps()
            showInstalled = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "tv.badge.wifi")
                Text("Apps installed on this TV")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right").font(.caption)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .disabled(!connection.status.isConnected)
        .opacity(connection.status.isConnected ? 1 : 0.5)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private var list: some View {
        List {
            ForEach(filtered) { app in
                AppRow(app: app, isPinned: app.isPinned, showLaunch: !editMode.isEditing) {
                    launch(app)
                } onPin: {
                    appsStore.togglePin(app)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Color.white.opacity(0.08))
            }
            // Reorder/delete only when the list isn't filtered, so offsets line up.
            .onDelete(perform: canReorder ? { appsStore.remove(at: $0) } : nil)
            .onMove(perform: canReorder ? { appsStore.move(from: $0, to: $1) } : nil)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .top) {
            if editMode.isEditing && query.isEmpty {
                Text("The top 5 apps appear in your quick-launch shortcut.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 6)
            }
        }
    }

    private func launch(_ app: StreamingApp) {
        guard !editMode.isEditing else { return }
        Haptics.tap()
        connection.launchApp(app)
        dismiss()
    }
}

/// A single row in the My Apps list.
private struct AppRow: View {
    let app: StreamingApp
    let isPinned: Bool
    let showLaunch: Bool
    var onTap: () -> Void
    var onPin: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: app.tintHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: app.sfSymbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                )

            Text(app.name)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            if showLaunch {
                Button(action: onPin) {
                    Image(systemName: isPinned ? "bell.fill" : "bell")
                        .foregroundStyle(isPinned ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

/// Sheet listing catalog apps not yet in the user's list, to add them.
private struct AddAppSheet: View {
    @Environment(AppsStore.self) private var appsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.onboardingGradient.ignoresSafeArea()
                if appsStore.available.isEmpty {
                    ContentUnavailableView("All apps added",
                                           systemImage: "checkmark.circle",
                                           description: Text("Every available app is already in your list."))
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    List {
                        ForEach(appsStore.available) { app in
                            Button {
                                appsStore.add(app)
                                Haptics.success()
                            } label: {
                                HStack(spacing: 14) {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(hex: app.tintHex))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: app.sfSymbol)
                                                .foregroundStyle(.white)
                                        )
                                    Text(app.name)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Add App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Theme.accent)
                }
            }
        }
    }
}

/// Lists the apps actually installed on the connected TV (with their real launch ids)
/// and launches them directly. Guarantees correct launching for any installed app.
private struct InstalledAppsSheet: View {
    @Environment(TVConnectionManager.self) private var connection
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [TVConnectionManager.InstalledApp] {
        guard !query.isEmpty else { return connection.installedApps }
        return connection.installedApps.filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.onboardingGradient.ignoresSafeArea()
                if connection.installedApps.isEmpty {
                    ContentUnavailableView {
                        Label("No apps found yet", systemImage: "tv")
                    } description: {
                        Text("Make sure the TV is connected, then pull to refresh.")
                    }
                    .foregroundStyle(Theme.textPrimary)
                } else {
                    List {
                        ForEach(filtered) { app in
                            Button {
                                Haptics.tap()
                                connection.launch(appId: app.id)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(app.id)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $query)
                    .refreshable { connection.refreshInstalledApps() }
                }
            }
            .navigationTitle("Apps on This TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Theme.accent)
                }
            }
        }
    }
}

#Preview {
    AppsView()
        .environment(TVConnectionManager())
        .environment(AppsStore())
}
