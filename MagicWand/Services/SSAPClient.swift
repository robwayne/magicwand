import Foundation

/// Events emitted by the SSAP client as the connection / pairing progresses.
enum SSAPEvent {
    case connecting
    /// The TV is now showing a PIN on screen and is waiting for us to send it.
    case awaitingPIN
    /// Pairing succeeded; `clientKey` should be persisted for silent reconnects.
    case registered(clientKey: String)
    /// Fully connected and ready to accept commands (pointer socket is up).
    case ready
    case disconnected(Error?)
    case failed(SSAPError)
}

enum SSAPError: LocalizedError {
    case invalidURL
    case socketClosed
    case pairingRejected
    case pinIncorrect
    case timeout
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The TV address is invalid."
        case .socketClosed: "The connection to the TV was closed."
        case .pairingRejected: "Pairing was rejected on the TV."
        case .pinIncorrect: "That PIN was incorrect. Please try again."
        case .timeout: "The TV did not respond in time."
        case .notConnected: "Not connected to a TV."
        }
    }
}

/// A minimal but real webOS SSAP (Secure Socket Application Protocol) client.
///
/// Talks to LG webOS televisions over a WebSocket on port 3000/3001. It performs the
/// registration handshake (with PIN pairing to match the app's pairing screen),
/// sends `ssap://` requests, and opens the secondary "pointer input" socket used to
/// deliver hardware button presses (D-pad, colour keys, media transport, etc.).
@MainActor
final class SSAPClient: NSObject {
    /// Called for every lifecycle event. Always invoked on the main actor.
    var onEvent: ((SSAPEvent) -> Void)?

    private var session: URLSession!
    private var socket: URLSessionWebSocketTask?
    private var pointerSocket: URLSessionWebSocketTask?

    private var device: TVDevice?
    private var commandCounter = 0
    /// Pending SSAP responses keyed by message id.
    private var pending: [String: (Result<[String: Any], Error>) -> Void] = [:]

    private var registerMessageID: String?
    private var didReportReady = false

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        // Allow the TV's self-signed certificate when connecting over wss (port 3001).
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Lifecycle

    func connect(to device: TVDevice) {
        guard let url = device.socketURL else {
            onEvent?(.failed(.invalidURL))
            return
        }
        disconnect(notify: false)
        self.device = device
        self.didReportReady = false
        onEvent?(.connecting)

        let task = session.webSocketTask(with: url)
        // webOS replies (e.g. listLaunchPoints with app icons) can exceed the default
        // 1 MB limit, which would silently drop the message. Allow much larger frames.
        task.maximumMessageSize = 16 * 1024 * 1024
        self.socket = task
        task.resume()
        receiveLoop(on: task)
        sendRegister(clientKey: device.clientKey)
    }

    func disconnect(notify: Bool = true) {
        pointerSocket?.cancel(with: .goingAway, reason: nil)
        socket?.cancel(with: .goingAway, reason: nil)
        pointerSocket = nil
        socket = nil
        pending.removeAll()
        registerMessageID = nil
        if notify { onEvent?(.disconnected(nil)) }
    }

    var isConnected: Bool { socket != nil }

    // MARK: - Registration handshake

    private func nextID(_ prefix: String) -> String {
        commandCounter += 1
        return "\(prefix)_\(commandCounter)"
    }

    private func sendRegister(clientKey: String?) {
        let id = nextID("register")
        registerMessageID = id
        let manifest: [String: Any] = [
            "manifestVersion": 1,
            "appVersion": "1.1",
            "signed": [
                "created": "20140509",
                "appId": "com.lge.test",
                "vendorId": "com.lge",
                "localizedAppNames": ["": "MagicWand Remote"],
                "localizedVendorNames": ["": "LG Electronics"],
                "permissions": [
                    "TEST_SECURE", "CONTROL_INPUT_TEXT", "CONTROL_MOUSE_AND_KEYBOARD",
                    "READ_INSTALLED_APPS", "READ_LGE_SDX", "READ_NOTIFICATIONS",
                    "SEARCH", "WRITE_SETTINGS", "WRITE_NOTIFICATION_ALERT",
                    "CONTROL_POWER", "READ_CURRENT_CHANNEL", "READ_RUNNING_APPS",
                    "READ_UPDATE_INFO", "UPDATE_FROM_REMOTE_APP",
                    "READ_LGE_TV_INPUT_EVENTS", "READ_TV_CURRENT_TIME"
                ],
                "serial": "2f930e2d2cfe083771f68e4fe7bb07"
            ],
            "permissions": [
                "LAUNCH", "LAUNCH_WEBAPP", "APP_TO_APP", "CLOSE",
                "TEST_OPEN", "TEST_PROTECTED", "CONTROL_AUDIO",
                "CONTROL_DISPLAY", "CONTROL_INPUT_JOYSTICK",
                "CONTROL_INPUT_MEDIA_RECORDING", "CONTROL_INPUT_MEDIA_PLAYBACK",
                "CONTROL_INPUT_TV", "CONTROL_POWER", "CONTROL_TV_SCREEN",
                "READ_APP_STATUS", "READ_CURRENT_CHANNEL", "READ_INPUT_DEVICE_LIST",
                "READ_NETWORK_STATE", "READ_RUNNING_APPS", "READ_TV_CHANNEL_LIST",
                "WRITE_NOTIFICATION_TOAST", "READ_POWER_STATE", "READ_COUNTRY_INFO",
                "READ_SETTINGS", "CONTROL_INPUT_TEXT", "CONTROL_MOUSE_AND_KEYBOARD",
                "CONTROL_INPUT_JOYSTICK", "MOVE_CURSOR"
            ]
        ]

        var payload: [String: Any] = [
            "forcePairing": false,
            "manifest": manifest
        ]
        if let clientKey, !clientKey.isEmpty {
            // We already trust this TV; no PIN prompt will be shown.
            payload["client-key"] = clientKey
        } else {
            // Ask the TV to show a PIN that the user will type on the pairing screen.
            payload["pairingType"] = "PIN"
        }

        let message: [String: Any] = [
            "id": id,
            "type": "register",
            "payload": payload
        ]
        rawSend(message, on: socket)
    }

    /// Called by the pairing screen once the user has typed the code shown on the TV.
    func submitPIN(_ pin: String) {
        let id = nextID("setpin")
        let message: [String: Any] = [
            "id": id,
            "type": "request",
            "uri": "ssap://pairing/setPin",
            "payload": ["pin": pin]
        ]
        rawSend(message, on: socket)
    }

    // MARK: - Sending SSAP requests

    @discardableResult
    func send(_ request: SSAPRequest,
              completion: ((Result<[String: Any], Error>) -> Void)? = nil) -> Bool {
        guard let socket else {
            completion?(.failure(SSAPError.notConnected))
            return false
        }
        let id = nextID("req")
        var message: [String: Any] = [
            "id": id,
            "type": "request",
            "uri": request.uri
        ]
        if let payload = request.payload { message["payload"] = payload }
        if let completion { pending[id] = completion }
        rawSend(message, on: socket)
        return true
    }

    // MARK: - Pointer input (hardware buttons)

    private func requestPointerSocket() {
        send(.init(rawURI: "ssap://com.webos.service.networkinput/getPointerInputSocket")) { [weak self] result in
            guard let self else { return }
            if case .success(let payload) = result,
               let path = payload["socketPath"] as? String,
               let url = URL(string: path) {
                self.openPointerSocket(url)
            } else {
                // Even without the pointer socket we can still send SSAP commands.
                self.reportReadyIfNeeded()
            }
        }
    }

    private func openPointerSocket(_ url: URL) {
        let task = session.webSocketTask(with: url)
        task.maximumMessageSize = 16 * 1024 * 1024
        pointerSocket = task
        task.resume()
        // The pointer socket only needs a drain loop to stay alive.
        drainPointer(task)
        reportReadyIfNeeded()
    }

    /// Send a hardware button press over the pointer input socket.
    func sendButton(_ button: RemoteButton) {
        let text = "type:button\nname:\(button.rawValue)\n\n"
        pointerSocket?.send(.string(text)) { _ in }
    }

    /// Send a relative trackpad move (used by the central D-pad surface).
    func sendMove(dx: CGFloat, dy: CGFloat, drag: Bool) {
        let text = "type:move\ndx:\(Int(dx))\ndy:\(Int(dy))\ndown:\(drag ? 1 : 0)\n\n"
        pointerSocket?.send(.string(text)) { _ in }
    }

    /// Send a trackpad click (center select via tap).
    func sendClick() {
        pointerSocket?.send(.string("type:click\n\n")) { _ in }
    }

    private func drainPointer(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            if case .success = result {
                Task { @MainActor in self.drainPointer(task) }
            }
        }
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
        pointerSocket?.cancel(with: .goingAway, reason: nil)
        pointerSocket = nil
        onEvent?(.disconnected(error))
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let type = json["type"] as? String ?? ""
        let id = json["id"] as? String
        let payload = json["payload"] as? [String: Any] ?? [:]

        // Route generic request responses to their waiting completion handler.
        if let id, let handler = pending[id] {
            if type == "error" {
                let errText = (json["error"] as? String) ?? "error"
                handler(.failure(NSError(domain: "SSAP", code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: errText])))
            } else {
                handler(.success(payload))
            }
            pending.removeValue(forKey: id)
            return
        }

        // Registration / pairing flow.
        if id == registerMessageID || type == "registered" || (id?.hasPrefix("register") ?? false) {
            handleRegistration(type: type, payload: payload, json: json)
        }
    }

    private func handleRegistration(type: String, payload: [String: Any], json: [String: Any]) {
        switch type {
        case "registered":
            if let key = payload["client-key"] as? String, !key.isEmpty {
                onEvent?(.registered(clientKey: key))
                // Bring up the pointer socket, then announce readiness.
                requestPointerSocket()
            }
        case "response":
            // The TV is now displaying a PIN and waiting for `setPin`.
            if (payload["pairingType"] as? String) == "PIN" || payload["returnValue"] == nil {
                onEvent?(.awaitingPIN)
            }
        case "error":
            let errText = (json["error"] as? String ?? "").lowercased()
            if errText.contains("pin") {
                onEvent?(.failed(.pinIncorrect))
            } else {
                onEvent?(.failed(.pairingRejected))
            }
        default:
            break
        }
    }

    private func reportReadyIfNeeded() {
        guard !didReportReady else { return }
        didReportReady = true
        onEvent?(.ready)
    }

    // MARK: - Raw send

    private func rawSend(_ object: [String: Any], on task: URLSessionWebSocketTask?) {
        guard let task,
              let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return }
        task.send(.string(string)) { _ in }
    }
}

// MARK: - Self-signed TLS for wss://<tv>:3001

extension SSAPClient: URLSessionDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                didReceive challenge: URLAuthenticationChallenge,
                                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // webOS TVs present a self-signed certificate; trust it for local control.
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// Convenience to build an SSAPRequest from a raw URI (for one-off internal calls).
private extension SSAPRequest {
    init(rawURI: String) { self = .raw(rawURI) }
}
