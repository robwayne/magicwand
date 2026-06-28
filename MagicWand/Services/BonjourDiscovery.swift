import Foundation
import Network

/// Discovers smart TVs on the local Wi-Fi network using Bonjour / mDNS via `NWBrowser`.
///
/// Browses AirPlay/RAOP plus LG and Samsung vendor service types, then resolves each
/// service to an IPv4 address and reports it with the right vendor tag. Works with only
/// the standard Local Network permission (no multicast entitlement required).
@MainActor
final class BonjourDiscovery {
    private var browsers: [NWBrowser] = []
    private var resolvers: [NWConnection] = []
    private var onFound: ((DiscoveredTV) -> Void)?
    private var resolvingKeys: Set<String> = []
    private var reportedHosts: Set<String> = []

    /// (serviceType, vendorHintIfUnambiguous). For shared protocols like AirPlay we leave
    /// the vendor unset and rely on name/metadata to classify per-result.
    private let serviceTypes: [(String, TVVendor?)] = [
        ("_lg-smart-device._tcp", .lg),
        ("_samsungmsf._tcp",      .samsung),
        ("_airplay._tcp",         nil),
        ("_raop._tcp",            nil)
    ]

    func start(onFound: @escaping (DiscoveredTV) -> Void) {
        self.onFound = onFound
        stop()

        for (type, hint) in serviceTypes {
            let params = NWParameters()
            params.includePeerToPeer = false
            let browser = NWBrowser(for: .bonjour(type: type, domain: "local."), using: params)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor in self?.handle(results, serviceType: type, hint: hint) }
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

    private func handle(_ results: Set<NWBrowser.Result>, serviceType: String, hint: TVVendor?) {
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            let key = "\(serviceType)/\(name)"
            guard !resolvingKeys.contains(key) else { continue }

            guard let vendor = classify(name: name, hint: hint, metadata: result.metadata) else {
                continue // not a TV we know how to control
            }

            resolvingKeys.insert(key)
            resolve(endpoint: result.endpoint, displayName: name, vendor: vendor)
        }
    }

    /// Decide whether a Bonjour service is a TV we control, and which vendor it is.
    private func classify(name: String,
                          hint: TVVendor?,
                          metadata: NWBrowser.Result.Metadata) -> TVVendor? {
        if let hint { return hint } // vendor-specific service type

        var haystack = name.lowercased()
        if case let .bonjour(txt) = metadata {
            for (k, entry) in txt {
                haystack += " " + k.lowercased()
                if case let .string(value) = entry { haystack += " " + value.lowercased() }
            }
        }

        // Exclude obvious non-TV AirPlay devices.
        let blocked = ["appletv", "audioaccessory", "homepod", "macbook", "macmini", "imac", "iphone", "ipad"]
        if blocked.contains(where: haystack.contains) { return nil }

        if haystack.contains("samsung") || haystack.contains("tizen") { return .samsung }
        if haystack.contains("lg") || haystack.contains("webos") { return .lg }
        if haystack.contains("tv") { return .lg } // safest default for generic "TV"-named AirPlay devices
        return nil
    }

    // MARK: - Resolving to an IP

    private func resolve(endpoint: NWEndpoint, displayName: String, vendor: TVVendor) {
        let conn = NWConnection(to: endpoint, using: .tcp)
        resolvers.append(conn)
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let remote = conn.currentPath?.remoteEndpoint
                let host = remote.flatMap(Self.host(from:))
                Task { @MainActor in self?.report(host: host, name: displayName, vendor: vendor) }
                conn.cancel()
            case .failed, .cancelled:
                conn.cancel()
            default:
                break
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
    }

    private func report(host: String?, name: String, vendor: TVVendor) {
        guard let host, !host.isEmpty, !reportedHosts.contains(host) else { return }
        reportedHosts.insert(host)
        onFound?(DiscoveredTV(host: host,
                              name: prettyName(name, vendor: vendor),
                              modelName: "",
                              vendor: vendor))
    }

    private func prettyName(_ raw: String, vendor: TVVendor) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return vendor == .samsung ? "Samsung TV" : "LG TV"
        }
        let lower = trimmed.lowercased()
        if lower.contains("tv") || lower.contains("lg") || lower.contains("samsung") { return trimmed }
        return vendor == .samsung ? "Samsung TV \(trimmed)" : "LG TV \(trimmed)"
    }

    /// Extract a usable IPv4 string (or hostname) from a resolved endpoint, dropping
    /// the interface zone and skipping IPv6.
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
