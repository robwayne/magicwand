import SwiftUI

/// Lets the user compose text on the phone and forward it to the TV's on-screen
/// keyboard in one go via the webOS IME. The text is only sent when the user taps
/// **Send** or hits Return — never on every keystroke, so the TV doesn't accumulate
/// partial prefixes (e.g. "hheherhere" while typing "here").
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
                    .onSubmit(submit)

                Button(action: submit) {
                    Text("Send")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .disabled(text.isEmpty)
                .opacity(text.isEmpty ? 0.5 : 1)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear { focused = true }
    }

    private func submit() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        // Send the full string once, then commit with Enter.
        connection.sendText(value)
        connection.sendEnter()
        dismiss()
    }
}
