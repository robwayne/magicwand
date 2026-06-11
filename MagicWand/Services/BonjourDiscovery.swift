import Foundation
import Network

/// Discovers LG webOS TVs using Bonjour / mDNS via `NWBrowser`.
///
/// Unlike SSDP (which needs the `com.apple.developer.networking.multicast`
/// entitlement), Bonjour browsing works with only the standard Local Network
/// permission. LG 2021+ webOS TVs (including the UP7500) advertise AirPlay/RAOP
/// services, so we browse those plus LG's own service type, then resolve each match
/// to an IPv4 address we can open the webOS control socket against.
@MainActor
final class BonjourDiscovery {
    private var browsers: [NWBrowser] = []
    private var resolvers: [NWConnection] = []
    private var onFound: ((DiscoveredTV) -> Void)?
    private var resolvingKeys: Set<String> = []
    private var reportedHosts: Set<String> = []

    /// Service types LG webOS TVs are known to advertise.
    private let serviceTypes = [
        "_lg-smart-device._tcp",
        "_airplay._tcp",
        "_raop._tcp"
    ]

    func start(onFound: @escaping (DiscoveredTV) -> Void) {
        self.onFound = onFound
        stop()

        for type in serviceTypes {
            let params = NWParameters()
            params.includePeerToPeer = false
            let browser = NWBrowser(for: .bonjour(type: type, domain: "local."), using: params)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor in self?.handle(results, serviceType: type) }
            }
            browser.start(queue: .global(qos: .userInitiated))
            browsers.append(browser)
        }
    }

    func stop() {
        browsers.forEach { $0.cancel() }
        resolvers.forEach { $0.cancel() }
        browsers.removeAll()
        resolvers.removeAll()
        resolvingKeys.removeAll()
    }

    // MARK: - Browsing

    private func handle(_ results: Set<NWBrowser.Result>, serviceType: String) {
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            let key = "\(serviceType)/\(name)"
            guard !resolvingKeys.contains(key) else { continue }

            // Decide whether this looks like an LG TV before we bother resolving it,
            // so we don't list HomePods / Apple TVs / speakers.
            guard looksLikeLG(name: name, serviceType: serviceType, metadata: result.metadata) else { continue }

            resolvingKeys.insert(key)
            resolve(endpoint: result.endpoint, displayName: name)
        }
    }

    private func looksLikeLG(name: String,
                             serviceType: String,
                             metadata: NWBrowser.Result.Metadata) -> Bool {
        // LG's own service type is unambiguous.
        if serviceType == "_lg-smart-device._tcp" { return true }

        var haystack = name.lowercased()
        if case let .bonjour(txt) = metadata {
            for (k, entry) in txt {
                haystack += " " + k.lowercased()
                if case let .string(value) = entry { haystack += " " + value.lowercased() }
            }
        }
        // Exclude obvious non-LG AirPlay devices.
        let blocked = ["appletv", "audioaccessory", "homepod", "macbook", "macmini", "imac", "iphone", "ipad"]
        if blocked.contains(where: haystack.contains) { return false }

        return haystack.contains("lg") || haystack.contains("webos") || haystack.contains("tv")
    }

    // MARK: - Resolving to an IP

    private func resolve(endpoint: NWEndpoint, displayName: String) {
        let conn = NWConnection(to: endpoint, using: .tcp)
        resolvers.append(conn)
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let remote = conn.currentPath?.remoteEndpoint
                let host = remote.flatMap(Self.host(from:))
                Task { @MainActor in self?.report(host: host, name: displayName) }
                conn.cancel()
            case .failed, .cancelled:
                conn.cancel()
            default:
                break
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
    }

    private func report(host: String?, name: String) {
        guard let host, !host.isEmpty, !reportedHosts.contains(host) else { return }
        reportedHosts.insert(host)
        onFound?(DiscoveredTV(host: host, name: prettyName(name, host: host), modelName: ""))
    }

    private func prettyName(_ raw: String, host: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "LG TV" }
        if trimmed.lowercased().contains("lg") || trimmed.lowercased().contains("tv") { return trimmed }
        return "LG TV \(trimmed)"
    }

    /// Extract a usable IPv4 string (or hostname) from a resolved endpoint, dropping
    /// the interface zone and skipping IPv6 (webOS control prefers IPv4).
    nonisolated private static func host(from endpoint: NWEndpoint) -> String? {
        guard case let .hostPort(host, _) = endpoint else { return nil }
        switch host {
        case .ipv4(let address):
            return "\(address)".components(separatedBy: "%").first
        case .ipv6:
            return nil
        case .name(let name, _):
            return name
        @unknown default:
            return nil
        }
    }
}
