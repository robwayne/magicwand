import Foundation

/// `TVControlBackend` for Samsung Tizen TVs (2016+ models running webOS… err, Tizen 2.3+).
///
/// Talks to `samsung.remote.control` over `wss://<ip>:8002/...` with the TV's self-signed
/// cert. Pairing is interactive on the TV itself: the first connect makes the TV display
/// an "Allow remote access?" prompt; on accept the TV returns a token in `ms.channel.connect`
/// that we persist as the device's credential. Subsequent connects include the token in
/// the URL and don't prompt.
///
/// Capability scope vs. LG: buttons, volume up/down/mute, channel up/down, power off,
/// app launch (DEEP_LINK), text input. Tizen doesn't expose a usable volume/power-state
/// subscription, so the volume HUD won't surface on Samsung TVs (the manager gates the
/// HUD on a real reading). MAC is read from the HTTP device-info endpoint for WoL.
@MainActor
final class TizenBackend: NSObject, TVControlBackend {
    var onEvent: ((TVBackendEvent) -> Void)?
    var isConnected: Bool { socket != nil && didReportReady }

    private var session: URLSession!
    private var socket: URLSessionWebSocketTask?
    private var device: TVDevice?
    private var didReportReady = false

    /// Name advertised to the TV in the Allow prompt and the device list.
    private let clientName = "MagicWand"

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Lifecycle

    func connect(to device: TVDevice) {
        disconnect()
        self.device = device
        self.didReportReady = false
        onEvent?(.connecting)

        guard let url = buildSocketURL(device: device) else {
            onEvent?(.failed(message: "Invalid TV address."))
            return
        }
        let task = session.webSocketTask(with: url)
        task.maximumMessageSize = 16 * 1024 * 1024
        self.socket = task
        task.resume()
        receiveLoop(on: task)

        // If we don't already have a token, the TV shows its on-screen prompt; tell the UI.
        if !device.isPaired {
            onEvent?(.awaitingPairing(method: .acceptOnTV))
        }
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        didReportReady = false
    }

    /// Samsung's pairing is driven by the TV's on-screen Allow prompt — there's nothing
    /// for the user to type. The token arrives in `ms.channel.connect`. No-op here.
    func submitPairingInput(_ input: String) {}

    // MARK: - Buttons

    func sendButton(_ button: RemoteButton) {
        guard let key = Self.tizenKey(for: button) else { return }
        sendKey(cmd: "Click", key: key)
    }

    // MARK: - Audio

    func volumeUp()   { sendKey(cmd: "Click", key: "KEY_VOLUP") }
    func volumeDown() { sendKey(cmd: "Click", key: "KEY_VOLDOWN") }
    func setMute(_ on: Bool) { sendKey(cmd: "Click", key: "KEY_MUTE") }
    /// Tizen has no `setVolume` over this protocol — emulate by repeating up/down a few
    /// times in the right direction. Best-effort; the LG backend has the real thing.
    func setVolume(_ level: Int) {
        // Without a known current volume on Tizen we can only nudge. Apply a small burst
        // toward the target; the user can then tap up/down to fine-tune.
        let direction = level >= 50 ? "KEY_VOLUP" : "KEY_VOLDOWN"
        for _ in 0..<5 { sendKey(cmd: "Click", key: direction) }
    }

    // MARK: - Channels

    func channelUp()   { sendKey(cmd: "Click", key: "KEY_CHUP") }
    func channelDown() { sendKey(cmd: "Click", key: "KEY_CHDOWN") }

    // MARK: - Power

    func turnOff()       { sendKey(cmd: "Click", key: "KEY_POWER") }
    func turnOnScreen()  { sendKey(cmd: "Click", key: "KEY_POWER") } // single toggle key

    // MARK: - Apps

    func launchApp(id: String) {
        // Samsung app IDs are numeric (e.g. 11101200001). Send the DEEP_LINK launch event.
        let message: [String: Any] = [
            "method": "ms.channel.emit",
            "params": [
                "event": "ed.apps.launch",
                "to": "host",
                "data": [
                    "action_type": "DEEP_LINK",
                    "appId": id
                ]
            ]
        ]
        sendJSON(message)
        // Tizen doesn't ack launches; assume success so the UI doesn't show a phantom error.
        onEvent?(.launchResult(appId: id, success: true, errorText: nil))
    }

    func openURL(_ urlString: String) {
        // Use the TV's web browser app id with a deep-link to the URL.
        let message: [String: Any] = [
            "method": "ms.channel.emit",
            "params": [
                "event": "ed.apps.launch",
                "to": "host",
                "data": ["action_type": "DEEP_LINK", "appId": "org.tizen.browser", "metaTag": urlString]
            ]
        ]
        sendJSON(message)
    }

    // MARK: - Text input

    func insertText(_ text: String) {
        guard let encoded = text.data(using: .utf8)?.base64EncodedString() else { return }
        sendKey(cmd: encoded, key: "base64", typeOfRemote: "SendInputString")
    }

    func sendEnterKey() {
        sendKey(cmd: "Click", key: "KEY_ENTER")
    }

    func deleteCharacters(_ count: Int) {
        for _ in 0..<max(0, count) {
            sendKey(cmd: "Click", key: "KEY_BACK_MB") // delete-left on Tizen's IME
        }
    }

    // MARK: - Subscriptions / queries

    /// Tizen exposes no usable volume subscription over this socket; the volume HUD will
    /// stay hidden for Samsung TVs (the manager gates it on a real reading).
    func subscribeVolume() {}

    /// Same for power state — no clean subscription. The status line will read
    /// "On • Connected" while the socket is up.
    func subscribePowerState() { onEvent?(.powerState(on: true)) }

    /// Tizen doesn't list installed apps over the remote-control socket. Return empty so
    /// the "Apps on this TV" sheet shows the empty state with a clear message.
    func fetchInstalledApps(completion: @escaping (Result<[BackendInstalledApp], Error>) -> Void) {
        completion(.success([]))
    }

    /// Read the MAC from the TV's HTTP device-info endpoint so Wake-on-LAN works.
    func fetchMACAddress(completion: @escaping (String?) -> Void) {
        guard let host = device?.host,
              let url = URL(string: "http://\(host):8001/api/v2/") else {
            completion(nil); return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dev = json["device"] as? [String: Any] else {
                Task { @MainActor in completion(nil) }
                return
            }
            let mac = (dev["wifiMac"] as? String)
                ?? (dev["ethernetMac"] as? String)
                ?? (dev["mac"] as? String)
            Task { @MainActor in completion(mac) }
        }.resume()
    }

    // MARK: - Private helpers

    private func buildSocketURL(device: TVDevice) -> URL? {
        guard let nameData = clientName.data(using: .utf8) else { return nil }
        let nameB64 = nameData.base64EncodedString()
        var components = URLComponents()
        components.scheme = "wss"
        components.host = device.host
        components.port = device.port
        components.path = "/api/v2/channels/samsung.remote.control"
        var items = [URLQueryItem(name: "name", value: nameB64)]
        if let token = device.clientKey, !token.isEmpty {
            items.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = items
        return components.url
    }

    private func sendKey(cmd: String, key: String, typeOfRemote: String = "SendRemoteKey") {
        let message: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": cmd,
                "DataOfCmd": key,
                "Option": "false",
                "TypeOfRemote": typeOfRemote
            ]
        ]
        sendJSON(message)
    }

    private func sendJSON(_ object: [String: Any]) {
        guard let socket,
              let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return }
        socket.send(.string(string)) { _ in }
    }

    // MARK: - Receive loop

    private func receiveLoop(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .failure(let error):
                    self.handleSocketFailure(error)
                case .success(let message):
                    self.handleMessage(message)
                    if self.socket === task { self.receiveLoop(on: task) }
                }
            }
        }
    }

    private func handleSocketFailure(_ error: Error) {
        guard socket != nil else { return }
        socket = nil
        didReportReady = false
        onEvent?(.disconnected(error))
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        let event = json["event"] as? String ?? ""
        let payload = json["data"] as? [String: Any] ?? [:]

        switch event {
        case "ms.channel.connect":
            // Paired (or already paired). Token is present on first pair.
            let token = payload["token"] as? String
            if let token, !token.isEmpty {
                onEvent?(.paired(credentials: token))
            } else if let device, device.isPaired {
                // Reconnect with existing token — treat as paired with no new credential.
                onEvent?(.paired(credentials: device.clientKey))
            }
            if !didReportReady {
                didReportReady = true
                onEvent?(.ready)
            }
        case "ms.channel.unauthorized":
            onEvent?(.failed(message: "The TV denied the pairing request. Allow access on the TV and try again."))
            disconnect()
        case "ms.channel.timeOut":
            onEvent?(.failed(message: "The TV's pairing prompt timed out. Try again and accept on the TV."))
            disconnect()
        default:
            break
        }
    }

    // MARK: - Tizen key mapping

    /// Map our vendor-agnostic `RemoteButton` to a Tizen `KEY_*` code.
    private static func tizenKey(for button: RemoteButton) -> String? {
        switch button {
        case .up:           "KEY_UP"
        case .down:         "KEY_DOWN"
        case .left:         "KEY_LEFT"
        case .right:        "KEY_RIGHT"
        case .enter:        "KEY_ENTER"
        case .back:         "KEY_RETURN"
        case .exit:         "KEY_EXIT"
        case .home:         "KEY_HOME"
        case .menu:         "KEY_MENU"
        case .info:         "KEY_INFO"
        case .dash:         "KEY_MINUS"
        case .asterisk:     "KEY_MORE"
        case .channelUp:    "KEY_CHUP"
        case .channelDown:  "KEY_CHDOWN"
        case .volumeUp:     "KEY_VOLUP"
        case .volumeDown:   "KEY_VOLDOWN"
        case .mute:         "KEY_MUTE"
        case .play:         "KEY_PLAY"
        case .pause:        "KEY_PAUSE"
        case .stop:         "KEY_STOP"
        case .rewind:       "KEY_REWIND"
        case .fastForward:  "KEY_FF"
        case .red:          "KEY_RED"
        case .green:        "KEY_GREEN"
        case .yellow:       "KEY_YELLOW"
        case .blue:         "KEY_BLUE"
        case .num0:         "KEY_0"
        case .num1:         "KEY_1"
        case .num2:         "KEY_2"
        case .num3:         "KEY_3"
        case .num4:         "KEY_4"
        case .num5:         "KEY_5"
        case .num6:         "KEY_6"
        case .num7:         "KEY_7"
        case .num8:         "KEY_8"
        case .num9:         "KEY_9"
        }
    }
}

// MARK: - Self-signed TLS

extension TizenBackend: URLSessionDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                didReceive challenge: URLAuthenticationChallenge,
                                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
