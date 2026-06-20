import Foundation

/// Hardware buttons sent over the webOS "pointer input" socket.
/// These are the literal token names webOS expects (e.g. `button\nname:ENTER\n\n`).
enum RemoteButton: String {
    case up = "UP"
    case down = "DOWN"
    case left = "LEFT"
    case right = "RIGHT"
    case enter = "ENTER"
    case back = "BACK"
    case exit = "EXIT"
    case home = "HOME"
    case menu = "MENU"
    case info = "INFO"
    case dash = "DASH"
    case asterisk = "ASTERISK"
    case channelUp = "CHANNELUP"
    case channelDown = "CHANNELDOWN"
    case volumeUp = "VOLUMEUP"
    case volumeDown = "VOLUMEDOWN"
    case mute = "MUTE"
    case play = "PLAY"
    case pause = "PAUSE"
    case stop = "STOP"
    case rewind = "REWIND"
    case fastForward = "FASTFORWARD"
    case red = "RED"
    case green = "GREEN"
    case yellow = "YELLOW"
    case blue = "BLUE"
    case num0 = "0"
    case num1 = "1"
    case num2 = "2"
    case num3 = "3"
    case num4 = "4"
    case num5 = "5"
    case num6 = "6"
    case num7 = "7"
    case num8 = "8"
    case num9 = "9"
}

/// High-level SSAP requests addressed by URI. The TV replies with a JSON payload.
enum SSAPRequest {
    case volumeUp
    case volumeDown
    case setMute(Bool)
    case setVolume(Int)
    case getVolume
    case channelUp
    case channelDown
    case turnOff
    case turnOnScreen
    case getPowerState
    case launchApp(appId: String)
    case openURL(target: String)
    case listApps
    case listAllApps
    case getForegroundAppInfo
    case getNetworkInfo
    case insertText(String)
    case sendEnterKey
    case deleteCharacters(Int)
    case createToast(String)
    /// Escape hatch for one-off internal URIs (e.g. requesting the pointer socket).
    case raw(String)

    /// The webOS SSAP URI for the request.
    var uri: String {
        switch self {
        case .raw(let uri): uri
        case .volumeUp: "ssap://audio/volumeUp"
        case .volumeDown: "ssap://audio/volumeDown"
        case .setMute: "ssap://audio/setMute"
        case .setVolume: "ssap://audio/setVolume"
        case .getVolume: "ssap://audio/getVolume"
        case .channelUp: "ssap://tv/channelUp"
        case .channelDown: "ssap://tv/channelDown"
        case .turnOff: "ssap://system/turnOff"
        case .turnOnScreen: "ssap://com.webos.service.tvpower/power/turnOnScreen"
        case .getPowerState: "ssap://com.webos.service.tvpower/power/getPowerState"
        case .launchApp: "ssap://system.launcher/launch"
        case .openURL: "ssap://system.launcher/open"
        case .listApps: "ssap://com.webos.applicationManager/listLaunchPoints"
        case .listAllApps: "ssap://com.webos.applicationManager/listApps"
        case .getForegroundAppInfo: "ssap://com.webos.applicationManager/getForegroundAppInfo"
        case .getNetworkInfo: "ssap://com.webos.service.connectionmanager/getinfo"
        case .insertText: "ssap://com.webos.service.ime/insertText"
        case .sendEnterKey: "ssap://com.webos.service.ime/sendEnterKey"
        case .deleteCharacters: "ssap://com.webos.service.ime/deleteCharacters"
        case .createToast: "ssap://system.notifications/createToast"
        }
    }

    /// The JSON `payload` accompanying the request, if any.
    var payload: [String: Any]? {
        switch self {
        case .setMute(let on): ["mute": on]
        case .setVolume(let level): ["volume": level]
        case .launchApp(let appId): ["id": appId]
        case .openURL(let target): ["target": target]
        case .insertText(let text): ["text": text, "replace": false]
        case .deleteCharacters(let count): ["count": count]
        case .createToast(let message): ["message": message]
        default: nil
        }
    }
}
