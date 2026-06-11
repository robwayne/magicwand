import SwiftUI

/// The primary remote-control screen. Layout mirrors the reference app:
/// power/browser/input row, channel & volume rockers around a 2×2 of
/// settings/search/home/mute, a number-pad + keyboard row, the central D-pad,
/// back/exit, and a bottom row with colour keys, Apps, and play/pause.
struct RemoteView: View {
    @Environment(TVConnectionManager.self) private var connection

    @State private var showApps = false
    @State private var showNumberPad = false
    @State private var showKeyboard = false
    @State private var isPlaying = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ConnectionHeader()

                        topRow
                        middleControls
                        numberKeyboardRow
                        DirectionalPad(
                            onDirection: { connection.sendButton($0) },
                            onSelect: { connection.click() }
                        )
                        backExitRow
                        bottomRow
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .sheet(isPresented: $showApps) { AppsView() }
            .sheet(isPresented: $showNumberPad) {
                NumberPadView { connection.sendButton($0) }
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showKeyboard) {
                TextEntryView()
                    .presentationDetents([.height(260)])
            }
        }
    }

    // MARK: - Rows

    private var topRow: some View {
        HStack(spacing: 12) {
            RemoteKey(content: .symbol("power"), tint: Theme.danger) {
                connection.powerOff()
            }
            RemoteKey(content: .symbol("globe")) {
                connection.openBrowser()
            }
            RemoteKey(content: .symbol("rectangle.and.arrow.up.right.and.arrow.down.left")) {
                connection.sendButton(.menu) // Input/Source list
            }
        }
    }

    private var middleControls: some View {
        HStack(spacing: 12) {
            RockerControl(
                topSymbol: "chevron.up",
                bottomSymbol: "chevron.down",
                centerLabel: "Ch",
                onTop: { connection.channelUp() },
                onBottom: { connection.channelDown() }
            )
            .frame(width: 78)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    RemoteKey(content: .symbol("gearshape.fill")) {
                        connection.sendButton(.menu)
                    }
                    RemoteKey(content: .symbol("magnifyingglass")) {
                        connection.sendButton(.menu)
                    }
                }
                HStack(spacing: 12) {
                    RemoteKey(content: .symbol("house.fill")) {
                        connection.sendButton(.home)
                    }
                    RemoteKey(content: .symbol(connection.volumeMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")) {
                        connection.toggleMute()
                    }
                }
            }

            RockerControl(
                topSymbol: "plus",
                bottomSymbol: "minus",
                centerLabel: "Vol",
                onTop: { connection.volumeUp() },
                onBottom: { connection.volumeDown() }
            )
            .frame(width: 78)
        }
    }

    private var numberKeyboardRow: some View {
        HStack(spacing: 12) {
            RemoteKey(content: .text("123")) {
                showNumberPad = true
            }
            .frame(width: 78)

            RemoteKey(content: .symbol("chevron.up")) {
                connection.sendButton(.up)
            }

            RemoteKey(content: .symbol("keyboard")) {
                showKeyboard = true
            }
            .frame(width: 78)
        }
    }

    private var backExitRow: some View {
        HStack(spacing: 12) {
            RemoteKey(content: .symbol("arrow.left")) {
                connection.sendButton(.back)
            }
            RemoteKey(content: .symbol("chevron.down")) {
                connection.sendButton(.down)
            }
            RemoteKey(content: .symbol("rectangle.portrait.and.arrow.right")) {
                connection.sendButton(.exit)
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            RemoteKey(content: .symbol("circle.grid.2x2.fill"), tint: .clear) {
                // Colour-key shortcut menu.
                connection.sendButton(.red)
            }
            .overlay(ColorDots())

            RemoteKey(content: .text("Apps"), fill: Theme.surfaceRaised) {
                showApps = true
            }
            .overlay(alignment: .leading) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.leading, 26)
            }

            RemoteKey(content: .symbol(isPlaying ? "playpause.fill" : "play.fill")) {
                isPlaying.toggle()
                connection.sendButton(isPlaying ? .play : .pause)
            }
        }
    }
}

/// The four LG colour keys rendered as small dots.
private struct ColorDots: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(.red)
            Circle().fill(.green)
            Circle().fill(.yellow)
            Circle().fill(.blue)
        }
        .frame(width: 34, height: 18)
    }
}

#Preview {
    RemoteView()
        .environment(TVConnectionManager())
        .environment(TVStore())
}
