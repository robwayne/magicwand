import SwiftUI

/// Lets the user type on the phone and forward keystrokes to the TV's on-screen
/// keyboard via the webOS IME (`insertText` / `sendEnterKey`). Presented from the
/// keyboard key on the remote.
struct TextEntryView: View {
    @Environment(TVConnectionManager.self) private var connection
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Capsule()
                    .fill(Theme.textTertiary)
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                Text("Send Text to TV")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                TextField("Type here…", text: $text)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($focused)
                    .submitLabel(.send)
                    .onChange(of: text) { _, newValue in
                        // Forward the full buffer as it changes.
                        connection.sendText(newValue)
                    }
                    .onSubmit {
                        connection.sendEnter()
                        dismiss()
                    }

                Button {
                    connection.sendEnter()
                    dismiss()
                } label: {
                    Text("Send")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear { focused = true }
    }
}
