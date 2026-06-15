import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// A floating quick-launch button pinned to the bottom-right, above all other UI.
///
/// It surfaces the user's top-five apps (the first five of the My Apps list). It does not
/// scroll with content; when the keyboard appears it slides down out of the way / hides,
/// and returns when the keyboard dismisses.
struct AppShortcutsButton: View {
    @Environment(AppsStore.self) private var appsStore
    @Environment(TVConnectionManager.self) private var connection

    @State private var showShortcuts = false
    @State private var keyboardVisible = false

    var body: some View {
        Button {
            Haptics.tap()
            showShortcuts = true
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1)

                // Apps grid with a lightning-bolt badge = "quick launch apps".
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Theme.accent)
                            .padding(2)
                            .background(Circle().fill(.white))
                            .offset(x: 9, y: 9)
                    }
            }
            .frame(width: 58, height: 58)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 18)
        .padding(.bottom, 78) // float above the tab bar, easy right-thumb reach
        .opacity(keyboardVisible ? 0 : 1)
        .offset(y: keyboardVisible ? 80 : 0)
        .animation(.easeInOut(duration: 0.25), value: keyboardVisible)
        .allowsHitTesting(!keyboardVisible)
        .sheet(isPresented: $showShortcuts) {
            ShortcutsSheet { app in
                connection.launchApp(app)
                showShortcuts = false
            }
            .presentationDetents([.height(360), .medium])
            .presentationBackground(Theme.background)
        }
        .onReceive(NotificationCenter.default.publisher(for: keyboardShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: keyboardHideNotification)) { _ in
            keyboardVisible = false
        }
    }

    private var keyboardShowNotification: Notification.Name {
        #if canImport(UIKit)
        UIResponder.keyboardWillShowNotification
        #else
        Notification.Name("keyboardWillShow")
        #endif
    }

    private var keyboardHideNotification: Notification.Name {
        #if canImport(UIKit)
        UIResponder.keyboardWillHideNotification
        #else
        Notification.Name("keyboardWillHide")
        #endif
    }
}

/// The simple list presented by the floating button.
private struct ShortcutsSheet: View {
    @Environment(AppsStore.self) private var appsStore
    var onLaunch: (StreamingApp) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.textTertiary)
                .frame(width: 40, height: 5)
                .padding(.vertical, 12)

            Text("Quick Launch")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, 8)

            if appsStore.shortcuts.isEmpty {
                Spacer()
                Text("Add apps in My Apps to see shortcuts here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(appsStore.shortcuts) { app in
                            Button {
                                Haptics.tap()
                                onLaunch(app)
                            } label: {
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
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .padding(14)
                                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}
