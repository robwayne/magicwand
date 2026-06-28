import Foundation
import Network

/// Last-resort discovery: scans the phone's local /24 subnet for hosts that have a
/// known TV control port open and reports them, tagged with the matching vendor.
///
/// Works whenever the Local Network permission is granted (no entitlement required).
/// Two ports are probed per host:
/// - 3000 → LG webOS (plain WebSocket)
/// - 8001 → Samsung Tizen (the device-info HTTP endpoint)
@MainActor
final class SubnetScanner {
    private var scanTask: Task<Void, Never>?
    private var reportedHosts: Set<String> = []

    /// Ports we probe and the vendor each one identifies.
    private let probes: [(port: NWEndpoint.Port, vendor: TVVendor)] = [
        (3000, .lg),
        (8001, .samsung)
    ]

    func start(onFound: @escaping (DiscoveredTV) -> Void) {
        stop()
        reportedHosts.removeAll()
        guard let base = Self.localSubnetBase() else { return }
        let probes = self.probes
        scanTask = Task { [weak self] in
            await self?.scan(base: base, probes: probes, onFound: onFound)
        }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
    }

    // MARK: - Scanning

    private func scan(base: String,
                      probes: [(port: NWEndpoint.Port, vendor: TVVendor)],
                      onFound: @escaping (DiscoveredTV) -> Void) async {
        let batchSize = 24
        var lower = 1
        while lower <= 254 {
            if Task.isCancelled { return }
            let upper = min(lower + batchSize - 1, 254)

            let hits = await withTaskGroup(of: (String, TVVendor)?.self) { group -> [(String, TVVendor)] in
                for h in lower...upper {
                    let ip = "\(base).\(h)"
                    for probe in probes {
                        let port = probe.port
                        let vendor = probe.vendor
                        group.addTask {
                            await Self.probe(host: ip, port: port) ? (ip, vendor) : nil
                        }
                    }
                }
                var found: [(String, TVVendor)] = []
                for await result in group {
                    if let result { found.append(result) }
                }
                return found
            }

            // Prefer the vendor-specific hit if the same host answered on multiple ports
            // (very unlikely — LG and Samsung don't share ports — but be safe).
            let bestByHost = Dictionary(grouping: hits, by: { $0.0 })
                .compactMapValues { entries in
                    entries.first(where: { $0.1 != .generic }) ?? entries.first
                }

            for (ip, entry) in bestByHost where !reportedHosts.contains(ip) {
                reportedHosts.insert(ip)
                onFound(Self.makeDiscovery(host: ip, vendor: entry.1))
            }

            lower = upper + 1
        }
    }

    private static func makeDiscovery(host: String, vendor: TVVendor) -> DiscoveredTV {
        switch vendor {
        case .samsung:
            return DiscoveredTV(host: host, name: "Samsung TV", modelName: "", vendor: .samsung)
        case .lg:
            return DiscoveredTV(host: host, name: "LG TV", modelName: "", vendor: .lg)
        case .generic:
            return DiscoveredTV(host: host, name: "Smart TV", modelName: "", vendor: .generic)
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
                        address = hostBuffer.withUnsafeBufferPointer {
                            String(cString: $0.baseAddress!)
                        }
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

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
