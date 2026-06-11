import SwiftUI

/// The "My Apps" list. Mirrors the reference screen: a searchable list of streaming
/// apps, each with a pin toggle. Tapping a row launches that app on the TV.
struct AppsView: View {
    @Environment(TVConnectionManager.self) private var connection
    @Environment(\.dismiss) private var dismiss

    @State private var apps = StreamingApp.catalog
    @State private var query = ""

    private var filtered: [StreamingApp] {
        let base = apps.sorted { $0.isPinned && !$1.isPinned }
        guard !query.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.onboardingGradient.ignoresSafeArea()
                VStack(spacing: 14) {
                    searchField
                    List {
                        ForEach(filtered) { app in
                            AppRow(app: app, isPinned: app.isPinned) {
                                launch(app)
                            } onPin: {
                                togglePin(app)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .padding(.top, 8)
            }
            .navigationTitle("My Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
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

    private func launch(_ app: StreamingApp) {
        Haptics.tap()
        connection.launchApp(app)
        dismiss()
    }

    private func togglePin(_ app: StreamingApp) {
        guard let index = apps.firstIndex(of: app) else { return }
        apps[index].isPinned.toggle()
    }
}

/// A single row in the My Apps list.
private struct AppRow: View {
    let app: StreamingApp
    let isPinned: Bool
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

            Button(action: onPin) {
                Image(systemName: isPinned ? "bell.fill" : "bell")
                    .foregroundStyle(isPinned ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    AppsView()
        .environment(TVConnectionManager())
}
