import Foundation

/// What kind of pairing the TV needs from the user (drives the pairing screen UI).
enum PairingMethod {
    /// LG webOS — TV shows a PIN, user types it on the phone.
    case pin
    /// Samsung Tizen — TV shows an "Allow remote access?" prompt the user accepts on the TV.
    case acceptOnTV
}

/// One installed app on the TV. (Mirrors `TVConnectionManager.InstalledApp` so backends
/// don't need to know about the manager.)
struct BackendInstalledApp: Hashable {
    let id: String
    let title: String
}

/// Events a backend reports to its owner (`TVConnectionManager`). All are delivered on
/// the main actor.
enum TVBackendEvent {
    case connecting
    /// User input is needed to finish pairing.
    case awaitingPairing(method: PairingMethod)
    /// Pairing succeeded; `credentials` (e.g. webOS client-key or Tizen token) should be
    /// persisted on the device so future connects are silent.
    case paired(credentials: String?)
    /// Fully connected and ready to accept commands.
    case ready
    case disconnected(Error?)
    case failed(message: String)

    /// Live volume push (one or both fields may be `nil` if the TV didn't include them).
    case volume(level: Int?, muted: Bool?)
    /// Live power-state push (TV is on vs. screen-off/standby).
    case powerState(on: Bool)
    /// Result of a launch request (so the manager can show a toast on failure).
    case launchResult(appId: String, success: Bool, errorText: String?)
}

/// Vendor-agnostic interface for talking to a TV. Each vendor implements this on top of
/// its own protocol (LG webOS → `LGWebOSBackend`, Samsung Tizen → `TizenBackend`).
///
/// The manager (`TVConnectionManager`) is the only thing that talks to a backend. UI code
/// goes through the manager, so backends are free to differ in capability — some methods
/// may be no-ops on TVs that don't support that feature (e.g. Samsung's pointer socket).
@MainActor
protocol TVControlBackend: AnyObject {
    var onEvent: ((TVBackendEvent) -> Void)? { get set }
    var isConnected: Bool { get }

    func connect(to device: TVDevice)
    func disconnect()

    /// Submit a pairing credential the user typed in. LG: the PIN from the TV. Samsung:
    /// ignored (the TV's "Allow" tap drives pairing automatically).
    func submitPairingInput(_ input: String)

    // Buttons / navigation
    func sendButton(_ button: RemoteButton)
    func sendMove(dx: CGFloat, dy: CGFloat, drag: Bool)
    func sendClick()

    // Audio
    func volumeUp()
    func volumeDown()
    func setVolume(_ level: Int)
    func setMute(_ on: Bool)

    // Channels
    func channelUp()
    func channelDown()

    // Power
    func turnOff()
    func turnOnScreen()

    // Apps
    func launchApp(id: String)
    func openURL(_ urlString: String)

    // Text input
    func insertText(_ text: String)
    func sendEnterKey()
    func deleteCharacters(_ count: Int)

    // Subscriptions / queries
    func subscribeVolume()
    func subscribePowerState()
    func fetchInstalledApps(completion: @escaping (Result<[BackendInstalledApp], Error>) -> Void)
    func fetchMACAddress(completion: @escaping (String?) -> Void)
}

// Default no-op implementations so vendors only override what they support.
extension TVControlBackend {
    func sendMove(dx: CGFloat, dy: CGFloat, drag: Bool) {}
    func sendClick() {}
    func deleteCharacters(_ count: Int) {}
    func subscribeVolume() {}
    func subscribePowerState() {}
}
