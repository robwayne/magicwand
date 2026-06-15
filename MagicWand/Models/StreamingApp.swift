import Foundation

/// A launchable app shown in the "My Apps" list.
///
/// `webOSId` is the real launch-point id used by `ssap://system.launcher/launch`.
/// `sfSymbol` / `tint` provide a lightweight built-in icon so the list looks right
/// even before we fetch the TV's real launch-point list.
struct StreamingApp: Identifiable, Hashable, Codable {
    let id: String          // stable local id
    let name: String
    let webOSId: String     // launch-point id on the TV (best-effort default)
    let sfSymbol: String
    let tintHex: String
    var isPinned: Bool = false

    /// The default catalog matching the reference "My Apps" screen.
    /// `webOSId`s are best-effort defaults; at runtime we resolve the real launch-point
    /// id from the TV by matching on the app's title (see `TVConnectionManager`).
    static let catalog: [StreamingApp] = [
        StreamingApp(id: "disney", name: "Disney+", webOSId: "com.disney.disneyplus-prod", sfSymbol: "sparkles", tintHex: "0E2A5E"),
        StreamingApp(id: "netflix", name: "Netflix", webOSId: "netflix", sfSymbol: "play.rectangle.fill", tintHex: "E50914"),
        StreamingApp(id: "appletv", name: "Apple TV", webOSId: "com.apple.appletv", sfSymbol: "appletv.fill", tintHex: "111111"),
        StreamingApp(id: "youtube", name: "YouTube", webOSId: "youtube.leanback.v4", sfSymbol: "play.rectangle.fill", tintHex: "FF0000"),
        StreamingApp(id: "applemusic", name: "Apple Music", webOSId: "music", sfSymbol: "music.note", tintHex: "FA2956"),
        StreamingApp(id: "stremio", name: "Stremio", webOSId: "stremio", sfSymbol: "play.circle.fill", tintHex: "5B4EE0"),
        StreamingApp(id: "primevideo", name: "Prime Video", webOSId: "amazon", sfSymbol: "play.tv.fill", tintHex: "1399FF"),
        StreamingApp(id: "apps", name: "Apps", webOSId: "com.webos.app.discovery", sfSymbol: "square.grid.2x2.fill", tintHex: "34C759"),
        StreamingApp(id: "spotify", name: "Spotify", webOSId: "spotify-beehive", sfSymbol: "music.note.list", tintHex: "1DB954"),
        StreamingApp(id: "plex", name: "Plex", webOSId: "cdp-30", sfSymbol: "play.square.stack.fill", tintHex: "E5A00D"),
        StreamingApp(id: "hbomax", name: "Max", webOSId: "com.wbd.stream", sfSymbol: "play.rectangle.fill", tintHex: "0046FF"),
        StreamingApp(id: "browser", name: "Web Browser", webOSId: "com.webos.app.browser", sfSymbol: "globe", tintHex: "5A6270"),
        StreamingApp(id: "livetv", name: "Live TV", webOSId: "com.webos.app.livetv", sfSymbol: "tv.fill", tintHex: "455066")
    ]
}
