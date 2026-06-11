import Foundation
import Observation
import SwiftUI

/// The single source of truth for the app's live connection to a TV.
///
/// Wraps `SSAPClient` (control protocol) and `SSDPDiscovery` (finding TVs) and exposes
/// simple, UI-friendly state and intent methods. Injected into the environment so any
/// screen can read `status` or fire a command.
@MainActor
@Observable
final class TVConnectionManager {
    enum Status: Equatable {
        case disconnected
        case discovering
        case connecting
        case awaitingPIN
        case connected
        case failed(String)

        var isConnected: Bool { self == .connected }
    }

    // Live state the UI observes.
    private(set) var status: Status = .disconnected
    private(set) var activeDevice: TVDevice?
    private(set) var discovered: [DiscoveredTV] = []
    private(set) var volumeMuted = false

    /// Bridged to `TVStore` so successful pairings get persisted.
    var onPaired: ((TVDevice) -> Void)?

    private let client = SSAPClient()
    private let discovery = SSDPDiscovery()
    private var pendingDevice: TVDevice?
    private var capturedClientKey: String?

    init() {
        client.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    // MARK: - Discovery

    func startDiscovery() {
        discovered.removeAll()
        status = .discovering
        discovery.start { [weak self] tv in
            guard let self else { return }
            if !self.discovered.contains(tv) {
                self.discovered.append(tv)
            }
        }
    }

    func stopDiscovery() {
        discovery.stop()
        if status == .discovering { status = .disconnected }
    }

    // MARK: - Connecting

    /// Connect to a discovered TV (no stored key yet → will trigger a PIN prompt).
    func connect(to discoveredTV: DiscoveredTV) {
        let device = TVDevice(
            name: discoveredTV.name,
            modelName: discoveredTV.modelName,
            host: discoveredTV.host
        )
        connect(to: device)
    }

    /// Connect to a known/saved TV. If it already has a client-key the TV won't prompt.
    func connect(to device: TVDevice) {
        discovery.stop()
        pendingDevice = device
        capturedClientKey = device.clientKey
        status = .connecting
        client.connect(to: device)
    }

    /// Manually add a TV by IP (the "I don't see the device" path).
    func connectManually(host: String, name: String = "LG TV UP7500PVG") {
        let device = TVDevice(name: name, modelName: "UP7500PVG", host: host)
        connect(to: device)
    }

    /// Send the PIN the user read off the TV during pairing.
    func submitPIN(_ pin: String) {
        client.submitPIN(pin)
    }

    func disconnect() {
        client.disconnect(notify: true)
        status = .disconnected
        activeDevice = nil
    }

    /// Tear down the current connection and restart discovery, sending the app back
    /// into the onboarding flow to pair with a different TV. Used by the Library's
    /// "Connect a New TV" button.
    func beginNewConnection() {
        client.disconnect(notify: false)
        activeDevice = nil
        discovered.removeAll()
        pendingDevice = nil
        capturedClientKey = nil
        startDiscovery()
    }

    // MARK: - Event handling

    private func handle(_ event: SSAPEvent) {
        switch event {
        case .connecting:
            status = .connecting
        case .awaitingPIN:
            status = .awaitingPIN
        case .registered(let key):
            capturedClientKey = key
        case .ready:
            finishConnection()
        case .disconnected:
            if status != .awaitingPIN { status = .disconnected }
        case .failed(let error):
            status = .failed(error.errorDescription ?? "Connection failed")
        }
    }

    private func finishConnection() {
        guard var device = pendingDevice else { return }
        device.clientKey = capturedClientKey ?? device.clientKey
        device.lastConnected = Date()
        activeDevice = device
        status = .connected
        onPaired?(device)
        // Sync the mute indicator once connected.
        refreshVolume()
    }

    // MARK: - Commands (high level)

    func sendButton(_ button: RemoteButton) {
        client.sendButton(button)
    }

    func move(dx: CGFloat, dy: CGFloat, drag: Bool) {
        client.sendMove(dx: dx, dy: dy, drag: drag)
    }

    func click() {
        client.sendClick()
    }

    func volumeUp() { client.send(.volumeUp) }
    func volumeDown() { client.send(.volumeDown) }
    func channelUp() { client.send(.channelUp) }
    func channelDown() { client.send(.channelDown) }

    func toggleMute() {
        volumeMuted.toggle()
        client.send(.setMute(volumeMuted))
    }

    func powerOff() { client.send(.turnOff) }

    func launchApp(_ app: StreamingApp) {
        client.send(.launchApp(appId: app.webOSId))
    }

    func openBrowser(_ urlString: String = "https://www.google.com") {
        client.send(.openURL(target: urlString))
    }

    func sendText(_ text: String) {
        client.send(.insertText(text))
    }

    func sendEnter() {
        client.send(.sendEnterKey)
    }

    private func refreshVolume() {
        client.send(.getVolume) { [weak self] result in
            guard case .success(let payload) = result else { return }
            if let muted = payload["muted"] as? Bool {
                self?.volumeMuted = muted
            }
        }
    }
}
