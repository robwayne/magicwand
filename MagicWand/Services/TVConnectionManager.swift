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

    /// Which top-level UI to show. Onboarding is only for first launch or "add a new TV";
    /// otherwise we go straight to the main app and (re)connect in the background.
    enum Route {
        case onboarding
        case main
    }

    // Live state the UI observes.
    private(set) var status: Status = .disconnected
    private(set) var route: Route = .onboarding
    private(set) var activeDevice: TVDevice?
    private(set) var discovered: [DiscoveredTV] = []
    private(set) var volumeMuted = false

    /// Transient banner message (e.g. a launch error reported by the TV), shown briefly.
    var toast: String?

    /// Real launch-points reported by the TV (id + title), used to resolve app launches.
    private(set) var installedApps: [InstalledApp] = []
    /// Why the installed-app list couldn't be read, if it failed (for diagnostics/UI).
    private(set) var appListError: String?

    struct InstalledApp: Identifiable, Hashable {
        let id: String
        let title: String
    }

    /// Bridged to `TVStore` so successful pairings get persisted.
    var onPaired: ((TVDevice) -> Void)?

    private let client = SSAPClient()
    private let discovery = SSDPDiscovery()
    private let bonjour = BonjourDiscovery()
    private let scanner = SubnetScanner()
    private var pendingDevice: TVDevice?
    private var capturedClientKey: String?

    init() {
        client.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    // MARK: - Launch

    /// Called once at launch. If we have a previously-paired TV, go straight to the
    /// main app and silently reconnect using the stored client-key (no PIN prompt).
    /// Otherwise show the onboarding flow.
    func bootstrap(using store: TVStore) {
        let candidate = store.device(withID: store.lastSelectedID)
            ?? store.sortedForLibrary.first(where: { $0.isPaired })
        if let device = candidate, device.isPaired {
            route = .main
            connect(to: device)
        } else {
            route = .onboarding
        }
    }

    // MARK: - Discovery

    func startDiscovery() {
        discovered.removeAll()
        status = .discovering
        let onFound: (DiscoveredTV) -> Void = { [weak self] tv in
            guard let self else { return }
            // Dedupe by host so Bonjour + SSDP don't list the same TV twice.
            if !self.discovered.contains(where: { $0.host == tv.host }) {
                self.discovered.append(tv)
            }
        }
        bonjour.start(onFound: onFound)   // primary: works with just Local Network permission
        discovery.start(onFound: onFound) // secondary: SSDP (needs multicast entitlement)
        scanner.start(onFound: onFound)   // fallback: probe the /24 subnet for the webOS port
    }

    func stopDiscovery() {
        bonjour.stop()
        discovery.stop()
        scanner.stop()
        if status == .discovering { status = .disconnected }
    }

    // MARK: - Connecting

    /// Connect to a discovered TV (no stored key yet → will trigger a PIN prompt).
    func connect(to discoveredTV: DiscoveredTV) {
        let device = TVDevice(
            name: discoveredTV.name,
            modelName: discoveredTV.modelName,
            host: discoveredTV.host,
            deviceType: "webOS Smart TV",
            ipType: discoveredTV.host.contains(":") ? "IPv6" : "IPv4"
        )
        connect(to: device)
    }

    /// Connect to a known/saved TV. If it already has a client-key the TV won't prompt.
    func connect(to device: TVDevice) {
        bonjour.stop()
        discovery.stop()
        scanner.stop()
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
        route = .onboarding
        startDiscovery()
    }

    /// Called when the app returns to the foreground. The control socket is dropped while
    /// backgrounded, so silently reconnect to whatever TV we were last using.
    func reconnectAfterForeground(using store: TVStore) {
        guard route == .main else { return }      // don't interrupt onboarding/pairing
        guard status != .connected, status != .connecting else { return }
        let device = activeDevice
            ?? store.device(withID: store.lastSelectedID)
            ?? store.sortedForLibrary.first(where: { $0.isPaired })
        if let device, device.isPaired {
            connect(to: device)
        }
    }

    /// Force a reconnect to the active (or last-used) TV. Used by the refresh buttons.
    func refreshConnection(using store: TVStore) {
        let device = activeDevice
            ?? store.device(withID: store.lastSelectedID)
            ?? store.sortedForLibrary.first(where: { $0.isPaired })
        if let device, device.isPaired {
            connect(to: device)
        }
    }

    /// Re-pair the currently-active TV (e.g. to upgrade a key that lacks permissions).
    func reestablishActive() {
        if let device = activeDevice { reestablish(device) }
    }

    /// Re-run the full pairing process for a device (clears the stored key so the TV
    /// shows a fresh PIN). Used by the device detail screen.
    func reestablish(_ device: TVDevice) {
        var fresh = device
        fresh.clientKey = nil
        route = .onboarding
        connect(to: fresh)
    }

    // MARK: - Event handling

    private func handle(_ event: SSAPEvent) {
        switch event {
        case .connecting:
            status = .connecting
        case .awaitingPIN:
            status = .awaitingPIN
            // A PIN is needed (first pairing, or the saved key expired) — make sure the
            // onboarding pairing screen is what's on-screen.
            route = .onboarding
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
        route = .main
        onPaired?(device)
        // Sync the mute indicator and fetch the TV's real app list once connected.
        refreshVolume()
        fetchLaunchPoints()
    }

    /// Re-fetch the TV's installed apps (used by the "Apps on this TV" list).
    func refreshInstalledApps() { fetchLaunchPoints() }

    private var fetchToken = UUID()

    private func fetchLaunchPoints(completion: (() -> Void)? = nil) {
        appListError = nil
        let token = UUID()
        fetchToken = token

        func finish() {
            guard fetchToken == token else { return }
            fetchToken = UUID() // invalidate; ignore any late responses
            completion?()
        }

        // Guarantee feedback even if the TV never replies.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard fetchToken == token else { return }
            if installedApps.isEmpty {
                appListError = appListError ?? "no response from TV (timed out)"
            }
            finish()
        }

        // Primary source: the home-screen launch points.
        client.send(.listApps) { [weak self] result in
            guard let self, self.fetchToken == token else { return }
            let (points, error1) = Self.parseApps(result, key: "launchPoints")
            if !points.isEmpty {
                self.installedApps = points
                finish()
                return
            }
            // Fallback: the full installed-apps list (different API / permission).
            self.client.send(.listAllApps) { [weak self] result2 in
                guard let self, self.fetchToken == token else { return }
                let (apps, error2) = Self.parseApps(result2, key: "apps")
                if !apps.isEmpty {
                    self.installedApps = apps
                } else {
                    self.appListError = error1 ?? error2 ?? "no apps returned"
                }
                finish()
            }
        }
    }

    /// Parse an app/launch-point list response, returning the apps and (if it failed)
    /// a short reason string for diagnostics.
    private static func parseApps(_ result: Result<[String: Any], Error>,
                                  key: String) -> ([InstalledApp], String?) {
        switch result {
        case .failure(let error):
            return ([], error.localizedDescription)
        case .success(let payload):
            guard let entries = payload[key] as? [[String: Any]] else {
                if let ret = payload["returnValue"] as? Bool, ret == false {
                    return ([], (payload["errorText"] as? String) ?? "request returned false")
                }
                return ([], "missing \"\(key)\" in response")
            }
            let apps = entries.compactMap { entry -> InstalledApp? in
                guard let id = entry["id"] as? String,
                      let title = entry["title"] as? String else { return nil }
                return InstalledApp(id: id, title: title)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return (apps, apps.isEmpty ? "empty list" : nil)
        }
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
        // If we haven't received the TV's app list yet, fetch it first so we can resolve
        // the real launch-point id (fixes apps whose default id is wrong, e.g. Disney+).
        if installedApps.isEmpty {
            fetchLaunchPoints { [weak self] in
                guard let self else { return }
                if self.installedApps.isEmpty {
                    let reason = self.appListError.map { " (\($0))" } ?? ""
                    self.toast = "Can't read the TV's app list\(reason); using default id for \(app.name)."
                }
                self.launch(appId: self.resolveLaunchId(for: app), label: app.name)
            }
        } else {
            launch(appId: resolveLaunchId(for: app), label: app.name)
        }
    }

    /// Launch a specific TV launch-point id directly (from the "Apps on this TV" list).
    func launch(appId: String, label: String? = nil) {
        let name = label ?? appId
        client.send(.launchApp(appId: appId)) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let payload):
                if let ret = payload["returnValue"] as? Bool, ret == false {
                    self.toast = "TV refused to launch \(name) [id: \(appId)]."
                }
            case .failure(let error):
                self.toast = "Couldn't launch \(name) [id: \(appId)]: \(error.localizedDescription)"
            }
        }
    }

    func clearToast() { toast = nil }

    /// Match a known app to the TV's actual launch-point id, by normalized title first
    /// (most reliable across regions/firmware), then by the best-effort default id.
    private func resolveLaunchId(for app: StreamingApp) -> String {
        let target = Self.normalize(app.name)

        if let exact = installedApps.first(where: { Self.normalize($0.title) == target }) {
            return exact.id
        }
        if !target.isEmpty, let partial = installedApps.first(where: {
            let title = Self.normalize($0.title)
            return title.contains(target) || target.contains(title)
        }) {
            return partial.id
        }
        if let byId = installedApps.first(where: { $0.id == app.webOSId }) {
            return byId.id
        }
        return app.webOSId
    }

    /// Lowercase, drop the word "plus"/"+", and keep only alphanumerics so titles like
    /// "Disney+", "Disney Plus", and "Prime Video" all compare cleanly.
    private static func normalize(_ string: String) -> String {
        string.lowercased()
            .replacingOccurrences(of: "plus", with: "")
            .filter { $0.isLetter || $0.isNumber }
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
