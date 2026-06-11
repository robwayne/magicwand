import Foundation
import Network

/// Last-resort discovery: scans the phone's local /24 subnet for hosts that have the
/// webOS control port (3000) open, and reports them as candidate TVs.
///
/// This needs no special entitlement — it's just outbound TCP probes on the LAN — so it
/// works whenever the Local Network permission is granted, even if Bonjour and SSDP both
/// come up empty. Results stream in as each host responds.
@MainActor
final class SubnetScanner {
    private var scanTask: Task<Void, Never>?
    private var reportedHosts: Set<String> = []

    /// webOS plain-WebSocket control port.
    private let port: NWEndpoint.Port = 3000

    func start(onFound: @escaping (DiscoveredTV) -> Void) {
        stop()
        reportedHosts.removeAll()
        guard let base = Self.localSubnetBase() else { return }
        scanTask = Task { [weak self] in
            await self?.scan(base: base, onFound: onFound)
        }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
    }

    // MARK: - Scanning

    private func scan(base: String, onFound: @escaping (DiscoveredTV) -> Void) async {
        let port = self.port
        let batchSize = 24
        var lower = 1
        while lower <= 254 {
            if Task.isCancelled { return }
            let upper = min(lower + batchSize - 1, 254)

            let openHosts = await withTaskGroup(of: String?.self) { group -> [String] in
                for h in lower...upper {
                    let ip = "\(base).\(h)"
                    group.addTask {
                        await Self.probe(host: ip, port: port) ? ip : nil
                    }
                }
                var found: [String] = []
                for await result in group {
                    if let ip = result { found.append(ip) }
                }
                return found
            }

            for ip in openHosts where !reportedHosts.contains(ip) {
                reportedHosts.insert(ip)
                onFound(DiscoveredTV(host: ip, name: "LG TV UP7500PVG", modelName: "UP7500PVG"))
            }

            lower = upper + 1
        }
    }

    /// One TCP probe. Resolves `true` if the host accepts a connection on `port`.
    nonisolated private static func probe(host: String,
                                          port: NWEndpoint.Port,
                                          timeout: TimeInterval = 1.2) async -> Bool {
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        let state = ProbeState()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                func finish(_ value: Bool) {
                    guard state.claim() else { return }
                    connection.cancel()
                    continuation.resume(returning: value)
                }
                connection.stateUpdateHandler = { newState in
                    switch newState {
                    case .ready: finish(true)
                    case .failed, .cancelled: finish(false)
                    default: break
                    }
                }
                connection.start(queue: .global(qos: .userInitiated))
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
            }
        } onCancel: {
            connection.cancel()
        }
    }

    // MARK: - Local subnet

    /// The first three octets of the phone's Wi-Fi (en0) IPv4 address, e.g. "192.168.1".
    nonisolated private static func localSubnetBase() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var address: String?
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let interface = current.pointee
            if let sa = interface.ifa_addr,
               sa.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" { // Wi-Fi
                    var addr = sa.pointee
                    let length = socklen_t(sa.pointee.sa_len)
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = withUnsafePointer(to: &addr) { ptr in
                        getnameinfo(ptr, length, &hostBuffer, socklen_t(hostBuffer.count),
                                    nil, 0, NI_NUMERICHOST)
                    }
                    if result == 0 {
                        address = String(cString: hostBuffer)
                        break
                    }
                }
            }
            pointer = interface.ifa_next
        }

        guard let ip = address else { return nil }
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }
}

/// Tiny thread-safe latch so each probe resumes its continuation exactly once.
private final class ProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    /// Returns `true` exactly once, for the first caller.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
