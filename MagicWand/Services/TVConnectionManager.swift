import Foundation
import Observation
import SwiftUI

/// The single source of truth for the app's live connection to a TV.
///
/// Owns whichever vendor backend matches the active device (LG webOS, Samsung Tizen, …),
/// the discovery services, and the UI-observable state. The rest of the app only sees
/// this manager — backends are an implementation detail.
@MainActor
@Observable
final class TVConnectionManager {
    enum Status: Equatable {
        case disconnected
        case discovering
        case connecting
        case awaitingPIN     // legacy name kept so the UI doesn't need to change; means
                             // "TV needs user input to finish pairing", per `pairingMethod`
        case connected
        case failed(String)

        var isConnected: Bool { self == .connected }
    }

    /// Which top-level UI to show. Onboarding is only for first launch or "add a new TV";
    /// otherwise we go straight to the main app and (re)connect in the background.
    enum Route { case onboarding, main }

    enum PowerState { case on, off, unknown }

    // Live state the UI observes.
    private(set) var status: Status = .disconnected
    private(set) var route: Route = .onboarding
    private(set) var activeDevice: TVDevice?
    private(set) var discovered: [DiscoveredTV] = []
    private(set) var volumeMuted = false
    private(set) var powerState: PowerState = .unknown

    /// How the active backend wants the user to pair (PIN field vs. "accept on TV").
    private(set) var pairingMethod: PairingMethod = .pin

    private(set) var currentVolume = 0
    private(set) var hasVolumeReading = false
    private(set) var isVolumeHUDVisible = false

    /// Transient banner message, shown briefly at the top of the main UI.
    var toast: String?

    private var lastSentVolume = -1
    private var hudHideToken = UUID()

    /// Real launch-points reported by the TV (id + title), used to resolve app launches.
    private(set) var installedApps: [InstalledApp] = []
    private(set) var appListError: String?

    struct InstalledApp: Identifiable, Hashable {
        let id: String
        let title: String
    }

    /// Bridged to `TVStore` so successful pairings get persisted.
    var onPaired: ((TVDevice) -> Void)?

    // MARK: - Backend + discovery

    private var backend: (any TVControlBackend)?
    private let discovery = SSDPDiscovery()
    private let bonjour = BonjourDiscovery()
    private let scanner = SubnetScanner()
    private var pendingDevice: TVDevice?
    private var capturedCredentials: String?

    // MARK: - Launch

    /// Called once at launch. If we have a previously-paired TV, go straight to the main
    /// app and silently reconnect using the stored credentials; otherwise show onboarding.
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
            if !self.discovered.contains(where: { $0.host == tv.host }) {
                self.discovered.append(tv)
            }
        }
        bonjour.start(onFound: onFound)
        discovery.start(onFound: onFound)
        scanner.start(onFound: onFound)
    }

    func stopDiscovery() {
        bonjour.stop()
        discovery.stop()
        scanner.stop()
        if status == .discovering { status = .disconnected }
    }

    // MARK: - Connecting

    func connect(to discoveredTV: DiscoveredTV) {
        let device = TVDevice(
            vendor: discoveredTV.vendor,
            name: discoveredTV.name,
            modelName: discoveredTV.modelName,
            host: discoveredTV.host,
            ipType: discoveredTV.host.contains(":") ? "IPv6" : "IPv4"
        )
        connect(to: device)
    }

    func connect(to device: TVDevice) {
        bonjour.stop()
        discovery.stop()
        scanner.stop()
        pendingDevice = device
        capturedCredentials = device.clientKey
        hasVolumeReading = false
        isVolumeHUDVisible = false
        status = .connecting

        // Pick (or rebuild) the backend matching this TV's vendor.
        let newBackend = Self.makeBackend(for: device.vendor)
        backend?.disconnect()
        backend = newBackend
        newBackend.onEvent = { [weak self] event in self?.handle(event) }
        newBackend.connect(to: device)
    }

    /// Manually add a TV by IP. Defaults to LG so existing manual-entry behaviour is
    /// unchanged; the Samsung entry point lives in the future "Add by IP" picker.
    func connectManually(host: String, name: String = "LG TV", vendor: TVVendor = .lg) {
        let device = TVDevice(vendor: vendor, name: name, host: host)
        connect(to: device)
    }

    /// Submit a pairing credential the user typed (LG: PIN). No-op for vendors that pair
    /// via the TV's own UI (Samsung).
    func submitPIN(_ pin: String) {
        backend?.submitPairingInput(pin)
    }

    func disconnect() {
        backend?.disconnect()
        status = .disconnected
        activeDevice = nil
        hasVolumeReading = false
        isVolumeHUDVisible = false
    }

    func beginNewConnection() {
        backend?.disconnect()
        activeDevice = nil
        discovered.removeAll()
        pendingDevice = nil
        capturedCredentials = nil
        route = .onboarding
        startDiscovery()
    }

    func reconnectAfterForeground(using store: TVStore) {
        guard route == .main else { return }
        guard status != .connected, status != .connecting else { return }
        let device = activeDevice
            ?? store.device(withID: store.lastSelectedID)
            ?? store.sortedForLibrary.first(where: { $0.isPaired })
        if let device, device.isPaired { connect(to: device) }
    }

    func refreshConnection(using store: TVStore) {
        let device = activeDevice
            ?? store.device(withID: store.lastSelectedID)
            ?? store.sortedForLibrary.first(where: { $0.isPaired })
        if let device, device.isPaired { connect(to: device) }
    }

    func reestablishActive() {
        if let device = activeDevice { reestablish(device) }
    }

    func reestablish(_ device: TVDevice) {
        var fresh = device
        fresh.clientKey = nil
        route = .onboarding
        connect(to: fresh)
    }

    // MARK: - Event handling

    private func handle(_ event: TVBackendEvent) {
        switch event {
        case .connecting:
            status = .connecting
        case .awaitingPairing(let method):
            pairingMethod = method
            status = .awaitingPIN
            route = .onboarding
        case .paired(let credentials):
            capturedCredentials = credentials ?? capturedCredentials
        case .ready:
            finishConnection()
        case .disconnected:
            if status != .awaitingPIN { status = .disconnected }
            resetTransientState()
        case .failed(let message):
            status = .failed(message)
            resetTransientState()
        case .volume(let level, let muted):
            if let level {
                currentVolume = level
                lastSentVolume = level
                hasVolumeReading = true
            }
            if let muted { volumeMuted = muted }
        case .powerState(let on):
            powerState = on ? .on : .off
        case .launchResult(let appId, let success, let errorText):
            if !success {
                let detail = errorText.map { ": \($0)" } ?? ""
                toast = "TV refused to launch [id: \(appId)]\(detail)."
            }
        }
    }

    private func resetTransientState() {
        hasVolumeReading = false
        isVolumeHUDVisible = false
        powerState = .unknown
    }

    private func finishConnection() {
        guard var device = pendingDevice else { return }
        device.clientKey = capturedCredentials ?? device.clientKey
        device.lastConnected = Date()
        activeDevice = device
        status = .connected
        route = .main
        onPaired?(device)
        // Bring up subscriptions and prefetch metadata.
        backend?.subscribeVolume()
        backend?.subscribePowerState()
        fetchInstalledApps()
        fetchMACAddress()
    }

    private func fetchMACAddress() {
        backend?.fetchMACAddress { [weak self] mac in
            guard let self, let mac, !mac.isEmpty, var device = self.activeDevice else { return }
            device.macAddress = mac
            self.activeDevice = device
            self.onPaired?(device) // persist
        }
    }

    // MARK: - App list

    func refreshInstalledApps() { fetchInstalledApps() }

    private var fetchToken = UUID()

    private func fetchInstalledApps(completion: (() -> Void)? = nil) {
        appListError = nil
        let token = UUID()
        fetchToken = token

        func finish() {
            guard fetchToken == token else { return }
            fetchToken = UUID()
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

        backend?.fetchInstalledApps { [weak self] result in
            guard let self, self.fetchToken == token else { return }
            switch result {
            case .success(let apps):
                if apps.isEmpty {
                    self.appListError = "empty list"
                } else {
                    self.installedApps = apps.map { InstalledApp(id: $0.id, title: $0.title) }
                }
            case .failure(let error):
                self.appListError = error.localizedDescription
            }
            finish()
        }
    }

    // MARK: - Commands (high level)

    func sendButton(_ button: RemoteButton) { backend?.sendButton(button) }
    func move(dx: CGFloat, dy: CGFloat, drag: Bool) { backend?.sendMove(dx: dx, dy: dy, drag: drag) }
    func click() { backend?.sendClick() }

    func volumeUp() {
        guard status.isConnected else { return }
        backend?.volumeUp()
        currentVolume = min(100, currentVolume + 1) // optimistic; subscription corrects
        lastSentVolume = currentVolume
        flashVolumeHUD()
    }

    func volumeDown() {
        guard status.isConnected else { return }
        backend?.volumeDown()
        currentVolume = max(0, currentVolume - 1)
        lastSentVolume = currentVolume
        flashVolumeHUD()
    }

    func setVolume(_ level: Int) {
        guard status.isConnected else { return }
        let clamped = min(100, max(0, level))
        currentVolume = clamped
        if clamped != lastSentVolume {
            lastSentVolume = clamped
            backend?.setVolume(clamped)
        }
        flashVolumeHUD()
    }

    func channelUp()   { backend?.channelUp() }
    func channelDown() { backend?.channelDown() }

    func toggleMute() {
        guard status.isConnected else { return }
        volumeMuted.toggle()
        backend?.setMute(volumeMuted)
        flashVolumeHUD()
    }

    /// Only flash the HUD when the connected backend has reported a real volume level.
    /// Vendors that don't expose volume readings (e.g. Samsung Tizen) won't show the HUD.
    func flashVolumeHUD() {
        guard status.isConnected, hasVolumeReading else { return }
        isVolumeHUDVisible = true
        let token = UUID()
        hudHideToken = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            if hudHideToken == token { isVolumeHUDVisible = false }
        }
    }

    func powerOff() { backend?.turnOff() }

    /// connected + on → turn off; connected + off → turn screen on; disconnected → wake.
    func togglePower(using store: TVStore) {
        switch (status.isConnected, powerState) {
        case (true, .on):
            backend?.turnOff()
        case (true, _):
            backend?.turnOnScreen()
        default:
            wake(using: store)
        }
    }

    func wake(using store: TVStore) {
        let device = activeDevice
            ?? store.device(withID: store.lastSelectedID)
            ?? store.sortedForLibrary.first(where: { $0.isPaired })
        guard let device else { return }
        guard let mac = device.macAddress, !mac.isEmpty else {
            toast = "Can't wake the TV yet — connect once while it's on so I can learn its MAC address."
            return
        }
        toast = "Waking \(device.displayName)…"
        Task { @MainActor in
            for attempt in 0..<10 {
                if self.status.isConnected { return }
                WakeOnLAN.send(macAddress: mac, ipAddress: device.host)
                if attempt > 0 { self.connect(to: device) }
                try? await Task.sleep(for: .seconds(3))
            }
            if !self.status.isConnected {
                self.toast = "Couldn't reach \(device.displayName). Make sure the TV's network standby (Settings › General › Mobile TV On / 'Turn on via Wi-Fi') is enabled."
            }
        }
    }

    // MARK: - Apps

    func launchApp(_ app: StreamingApp) {
        // If the live app list isn't loaded yet, fetch it first so we resolve a real id.
        if installedApps.isEmpty {
            fetchInstalledApps { [weak self] in
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
        backend?.launchApp(id: appId)
    }

    func clearToast() { toast = nil }

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

    private static func normalize(_ string: String) -> String {
        string.lowercased()
            .replacingOccurrences(of: "plus", with: "")
            .filter { $0.isLetter || $0.isNumber }
    }

    func openBrowser(_ urlString: String = "https://www.google.com") {
        backend?.openURL(urlString)
    }

    func sendText(_ text: String) { backend?.insertText(text) }
    func sendEnter()               { backend?.sendEnterKey() }

    // MARK: - Backend factory

    private static func makeBackend(for vendor: TVVendor) -> any TVControlBackend {
        switch vendor {
        case .lg:      LGWebOSBackend()
        case .samsung: TizenBackend()
        case .generic: LGWebOSBackend() // safe default; replace when a backend exists
        }
    }
}
