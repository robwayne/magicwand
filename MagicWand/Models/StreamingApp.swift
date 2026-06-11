import Foundation

/// A launchable app shown in the "My Apps" list.
///
/// `webOSId` is the real launch-point id used by `ssap://system.launcher/launch`.
/// `sfSymbol` / `tint` provide a lightweight built-in icon so the list looks right
/// even before we fetch the TV's real launch-point list.
struct StreamingApp: Identifiable, Hashable {
    let id: String          // stable local id
    let name: String
    let webOSId: String     // launch-point id on the TV
    let sfSymbol: String
    let tintHex: String
    var isPinned: Bool = false

    /// The default catalog matching the reference "My Apps" screen.
    static let catalog: [StreamingApp] = [
        StreamingApp(id: "disney", name: "Disney+", webOSId: "com.disney.disneyplus-prod", sfSymbol: "sparkles", tintHex: "0E2A5E"),
        StreamingApp(id: "netflix", name: "Netflix", webOSId: "netflix", sfSymbol: "play.rectangle.fill", tintHex: "E50914"),
        StreamingApp(id: "appletv", name: "Apple TV", webOSId: "com.apple.appletv", sfSymbol: "appletv.fill", tintHex: "111111"),
        StreamingApp(id: "youtube", name: "YouTube", webOSId: "youtube.leanback.v4", sfSymbol: "play.rectangle.fill", tintHex: "FF0000"),
        StreamingApp(id: "applemusic", name: "Apple Music", webOSId: "music", sfSymbol: "music.note", tintHex: "FA2956"),
        StreamingApp(id: "stremio", name: "Stremio", webOSId: "com.stremio.stremio", sfSymbol: "play.circle.fill", tintHex: "5B4EE0"),
        StreamingApp(id: "primevideo", name: "Prime Video", webOSId: "amazon", sfSymbol: "play.tv.fill", tintHex: "1399FF"),
        StreamingApp(id: "apps", name: "Apps", webOSId: "com.webos.app.discovery", sfSymbol: "square.grid.2x2.fill", tintHex: "34C759")
    ]
}
