import Foundation
import Network

/// Sends a Wake-on-LAN "magic packet" so a powered-off LG TV (in network standby) turns
/// back on. webOS TVs wake on this packet when "Mobile TV On" / network standby is enabled
/// (the same capability that lets AirPlay wake the TV).
enum WakeOnLAN {
    /// Send the magic packet for the given MAC. Broadcasts to the subnet-directed address
    /// derived from `ipAddress` (and the global broadcast) on the usual WoL ports 9 and 7.
    static func send(macAddress: String, ipAddress: String?) {
        guard let packet = magicPacket(for: macAddress) else { return }

        var targets = ["255.255.255.255"]
        if let subnetBroadcast = Self.subnetBroadcast(for: ipAddress) {
            targets.insert(subnetBroadcast, at: 0)
        }
        let ports: [NWEndpoint.Port] = [9, 7]

        for host in targets {
            for port in ports {
                sendPacket(packet, host: host, port: port)
            }
        }
    }

    // MARK: - Packet building

    private static func magicPacket(for mac: String) -> Data? {
        let bytes = mac
            .split(whereSeparator: { $0 == ":" || $0 == "-" || $0 == "." })
            .compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return nil }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }
        return packet
    }

    /// Turn "192.168.1.42" into "192.168.1.255".
    private static func subnetBroadcast(for ip: String?) -> String? {
        guard let ip else { return nil }
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return "\(parts[0]).\(parts[1]).\(parts[2]).255"
    }

    // MARK: - Sending

    private static func sendPacket(_ packet: Data, host: String, port: NWEndpoint.Port) {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        // Permit sending to broadcast addresses.
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: params)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: packet, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }
}
