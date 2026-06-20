import Foundation
import Darwin

/// Sends a Wake-on-LAN "magic packet" so a powered-off LG TV (in network standby) turns
/// back on — the same capability that lets AirPlay wake the TV.
///
/// Uses a raw BSD datagram socket with `SO_BROADCAST` enabled, which is the reliable way
/// to emit broadcast UDP on iOS (NWConnection does not dependably deliver to broadcast
/// addresses). The packet is sent to the subnet-directed broadcast, the global broadcast,
/// and the last-known unicast IP, on the usual WoL ports, a few times for good measure.
enum WakeOnLAN {
    static func send(macAddress: String, ipAddress: String?) {
        guard let packet = magicPacket(for: macAddress) else { return }

        var hosts: [String] = ["255.255.255.255"]
        if let subnet = subnetBroadcast(for: ipAddress) { hosts.insert(subnet, at: 0) }
        if let ip = ipAddress, !ip.isEmpty { hosts.append(ip) } // in case ARP is still valid
        let ports: [UInt16] = [9, 7]

        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<3 {
                for host in hosts {
                    for port in ports {
                        sendPacket(packet, host: host, port: port)
                    }
                }
                usleep(150_000) // 150ms between bursts
            }
        }
    }

    // MARK: - Packet

    private static func magicPacket(for mac: String) -> Data? {
        let bytes = mac
            .split(whereSeparator: { $0 == ":" || $0 == "-" || $0 == "." || $0 == " " })
            .compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return nil }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }
        return packet
    }

    /// "192.168.1.42" -> "192.168.1.255".
    private static func subnetBroadcast(for ip: String?) -> String? {
        guard let ip else { return nil }
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return "\(parts[0]).\(parts[1]).\(parts[2]).255"
    }

    // MARK: - Raw socket send

    private static func sendPacket(_ packet: Data, host: String, port: UInt16) {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }

        var enable: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &enable, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else { return }

        _ = packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    sendto(fd, raw.baseAddress, packet.count, 0, saPtr,
                           socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}
