import Foundation
import Network

/// A TV found on the local network during an SSDP scan.
struct DiscoveredTV: Identifiable, Hashable {
    var id: String { host }
    let host: String
    let name: String
    let modelName: String
}

/// Discovers LG webOS TVs on the local Wi-Fi network using SSDP (UPnP) over UDP.
///
/// Sends an `M-SEARCH` multicast and collects the unicast replies, extracting the
/// TV's IP address. Note: UDP multicast on iOS requires the
/// `com.apple.developer.networking.multicast` entitlement (see README). When that
/// isn't granted, the onboarding flow falls back to manual IP entry via the
/// "I don't see the device" link.
@MainActor
final class SSDPDiscovery {
    private var connection: NWConnection?
    private var onFound: ((DiscoveredTV) -> Void)?
    private var seenHosts: Set<String> = []

    private let multicastHost = NWEndpoint.Host("239.255.255.250")
    private let multicastPort = NWEndpoint.Port(rawValue: 1900)!

    // LG webOS second-screen search target.
    private let searchTargets = [
        "urn:lge-com:service:webos-second-screen:1",
        "urn:schemas-upnp-org:device:MediaRenderer:1",
        "ssdp:all"
    ]

    func start(onFound: @escaping (DiscoveredTV) -> Void) {
        self.onFound = onFound
        seenHosts.removeAll()

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        let conn = NWConnection(host: multicastHost, port: multicastPort, using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state {
                Task { @MainActor in
                    self.sendSearches()
                    self.receive(on: conn)
                }
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        connection?.cancel()
        connection = nil
        onFound = nil
    }

    private func sendSearches() {
        for target in searchTargets {
            let message = """
            M-SEARCH * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            MAN: "ssdp:discover"\r
            MX: 2\r
            ST: \(target)\r
            \r

            """
            connection?.send(content: message.data(using: .utf8),
                             completion: .contentProcessed { _ in })
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, _ in
            guard let self else { return }
            if let data, let text = String(data: data, encoding: .utf8) {
                Task { @MainActor in self.parse(response: text) }
            }
            Task { @MainActor in
                if self.connection === conn { self.receive(on: conn) }
            }
        }
    }

    private func parse(response: String) {
        // Pull the host out of the LOCATION header, e.g. "LOCATION: http://192.168.1.42:1754/...".
        guard let host = extractHost(from: response) else { return }
        guard !seenHosts.contains(host) else { return }

        // Only surface LG / webOS devices.
        let lower = response.lowercased()
        let looksLikeLG = lower.contains("lg") || lower.contains("webos")
        guard looksLikeLG else { return }

        seenHosts.insert(host)
        let model = extractModel(from: response)
        let name = model.isEmpty ? "LG TV" : "LG TV \(model)"
        onFound?(DiscoveredTV(host: host, name: name, modelName: model))
    }

    private func extractHost(from response: String) -> String? {
        for line in response.split(separator: "\r\n") where line.uppercased().hasPrefix("LOCATION:") {
            let value = line.dropFirst("LOCATION:".count).trimmingCharacters(in: .whitespaces)
            if let url = URL(string: value), let host = url.host { return host }
        }
        return nil
    }

    private func extractModel(from response: String) -> String {
        for line in response.split(separator: "\r\n") {
            let upper = line.uppercased()
            if upper.contains("UP7500") { return "UP7500PVG" }
            if upper.hasPrefix("SERVER:"), let range = line.range(of: "LG", options: .caseInsensitive) {
                return String(line[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }
}
