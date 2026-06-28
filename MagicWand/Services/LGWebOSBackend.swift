import Foundation

/// `TVControlBackend` for LG webOS TVs. Thin adapter over `SSAPClient`: translates the
/// SSAP event stream to vendor-agnostic `TVBackendEvent`s and protocol methods to SSAP
/// requests. All LG-specific protocol logic (pairing manifest, pointer socket, etc.)
/// lives inside `SSAPClient` and stays unchanged.
@MainActor
final class LGWebOSBackend: TVControlBackend {
    var onEvent: ((TVBackendEvent) -> Void)?
    var isConnected: Bool { client.isConnected }

    private let client = SSAPClient()

    init() {
        client.onEvent = { [weak self] event in self?.translate(event) }
    }

    // MARK: - Lifecycle

    func connect(to device: TVDevice) {
        client.connect(to: device)
    }

    func disconnect() {
        client.disconnect(notify: true)
    }

    func submitPairingInput(_ input: String) {
        client.submitPIN(input)
    }

    // MARK: - Commands

    func sendButton(_ button: RemoteButton)              { client.sendButton(button) }
    func sendMove(dx: CGFloat, dy: CGFloat, drag: Bool)  { client.sendMove(dx: dx, dy: dy, drag: drag) }
    func sendClick()                                      { client.sendClick() }

    func volumeUp()    { client.send(.volumeUp) }
    func volumeDown()  { client.send(.volumeDown) }
    func setVolume(_ level: Int) { client.send(.setVolume(level)) }
    func setMute(_ on: Bool)     { client.send(.setMute(on)) }

    func channelUp()   { client.send(.channelUp) }
    func channelDown() { client.send(.channelDown) }

    func turnOff()       { client.send(.turnOff) }
    func turnOnScreen()  { client.send(.turnOnScreen) }

    func launchApp(id: String) {
        client.send(.launchApp(appId: id)) { [weak self] result in
            self?.emitLaunchResult(appId: id, result: result)
        }
    }

    func openURL(_ urlString: String) {
        client.send(.openURL(target: urlString))
    }

    func insertText(_ text: String) {
        client.send(.insertText(text))
    }

    func sendEnterKey() {
        client.send(.sendEnterKey)
    }

    func deleteCharacters(_ count: Int) {
        client.send(.deleteCharacters(count))
    }

    // MARK: - Subscriptions / queries

    func subscribeVolume() {
        client.subscribe(.getVolume) { [weak self] result in
            guard let self, case .success(let payload) = result else { return }
            let status = payload["volumeStatus"] as? [String: Any]
            let level = (payload["volume"] as? Int) ?? (status?["volume"] as? Int)
            let muted = (payload["muted"] as? Bool) ?? (status?["muteStatus"] as? Bool)
            self.onEvent?(.volume(level: level, muted: muted))
        }
    }

    func subscribePowerState() {
        client.subscribe(.getPowerState) { [weak self] result in
            guard let self, case .success(let payload) = result else { return }
            let state = (payload["state"] as? String) ?? ""
            let processing = (payload["processing"] as? String) ?? ""
            let on = state == "Active" && !processing.localizedCaseInsensitiveContains("Screen Off")
            self.onEvent?(.powerState(on: on))
        }
    }

    /// Try `listLaunchPoints` first, fall back to `listApps`. Matches the previous logic.
    func fetchInstalledApps(completion: @escaping (Result<[BackendInstalledApp], Error>) -> Void) {
        client.send(.listApps) { [weak self] result in
            guard let self else { return }
            let apps = Self.parseApps(result, key: "launchPoints")
            if !apps.isEmpty { completion(.success(apps)); return }
            self.client.send(.listAllApps) { result2 in
                let apps2 = Self.parseApps(result2, key: "apps")
                if !apps2.isEmpty {
                    completion(.success(apps2))
                } else if case .failure(let err) = result2 {
                    completion(.failure(err))
                } else {
                    completion(.success([]))
                }
            }
        }
    }

    func fetchMACAddress(completion: @escaping (String?) -> Void) {
        client.send(.getNetworkInfo) { result in
            guard case .success(let payload) = result else { completion(nil); return }
            let wifi = payload["wifiInfo"] as? [String: Any]
            let wired = payload["wiredInfo"] as? [String: Any]
            let mac = (wifi?["macAddress"] as? String)
                ?? (wired?["macAddress"] as? String)
                ?? Self.recursiveMac(in: payload)
            completion(mac)
        }
    }

    // MARK: - Helpers

    private func translate(_ event: SSAPEvent) {
        switch event {
        case .connecting:
            onEvent?(.connecting)
        case .awaitingPIN:
            onEvent?(.awaitingPairing(method: .pin))
        case .registered(let key):
            onEvent?(.paired(credentials: key))
        case .ready:
            onEvent?(.ready)
        case .disconnected(let err):
            onEvent?(.disconnected(err))
        case .failed(let err):
            onEvent?(.failed(message: err.errorDescription ?? "Connection failed"))
        }
    }

    private func emitLaunchResult(appId: String, result: Result<[String: Any], Error>) {
        switch result {
        case .success(let payload):
            let ok = (payload["returnValue"] as? Bool) ?? true
            let errText = payload["errorText"] as? String
            onEvent?(.launchResult(appId: appId, success: ok, errorText: errText))
        case .failure(let error):
            onEvent?(.launchResult(appId: appId, success: false, errorText: error.localizedDescription))
        }
    }

    private static func parseApps(_ result: Result<[String: Any], Error>, key: String) -> [BackendInstalledApp] {
        guard case .success(let payload) = result,
              let entries = payload[key] as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard let id = entry["id"] as? String,
                  let title = entry["title"] as? String else { return nil }
            return BackendInstalledApp(id: id, title: title)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func recursiveMac(in dict: [String: Any]) -> String? {
        for (key, value) in dict {
            if key.lowercased() == "macaddress", let s = value as? String, !s.isEmpty { return s }
            if let nested = value as? [String: Any], let found = recursiveMac(in: nested) { return found }
        }
        return nil
    }
}
