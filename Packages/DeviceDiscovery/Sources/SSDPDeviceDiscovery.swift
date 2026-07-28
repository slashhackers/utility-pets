import Darwin
import Foundation

/// Discovers DLNA media renderers with the standard SSDP M-SEARCH protocol.
public struct SSDPDeviceDiscovery: Sendable {
    public init() {}

    public func scan(timeout: TimeInterval = 3) async -> [MediaDevice] {
        await Task.detached(priority: .userInitiated) {
            let locations = receiveLocations(timeout: timeout)
            var devices: [String: MediaDevice] = [:]
            for location in locations {
                if let device = await fetchDevice(at: location) {
                    devices[device.id] = device
                }
            }
            return devices.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
    }
}

private func receiveLocations(timeout: TimeInterval) -> Set<URL> {
    let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard socketFD >= 0 else { return [] }
    defer { close(socketFD) }

    var reuse: Int32 = 1
    setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
    var receiveTimeout = timeval(tv_sec: 0, tv_usec: 250_000)
    setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &receiveTimeout, socklen_t(MemoryLayout<timeval>.size))

    let query = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n"
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(1900).bigEndian
    inet_pton(AF_INET, "239.255.255.250", &address.sin_addr)

    _ = query.withCString { bytes in
        withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(socketFD, bytes, strlen(bytes), 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    let deadline = Date().addingTimeInterval(timeout)
    var locations = Set<URL>()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while Date() < deadline {
        let length = recv(socketFD, &buffer, buffer.count, 0)
        guard length > 0, let response = String(bytes: buffer.prefix(Int(length)), encoding: .utf8),
              let location = header(named: "LOCATION", in: response), let url = URL(string: location) else { continue }
        locations.insert(url)
    }
    return locations
}

private func fetchDevice(at descriptionURL: URL) async -> MediaDevice? {
    guard let (data, _) = try? await URLSession.shared.data(from: descriptionURL),
          let xml = String(data: data, encoding: .utf8),
          let controlPath = firstAVTransportControlURL(in: xml) else { return nil }

    let name = xmlValue("friendlyName", in: xml) ?? "Smart TV"
    let id = xmlValue("UDN", in: xml) ?? descriptionURL.absoluteString
    guard let controlURL = URL(string: controlPath, relativeTo: descriptionURL)?.absoluteURL else { return nil }
    return MediaDevice(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), controlURL: controlURL, descriptionURL: descriptionURL)
}

private func header(named name: String, in response: String) -> String? {
    response.split(whereSeparator: \.isNewline).first { line in
        line.lowercased().hasPrefix("\(name.lowercased()):")
    }.map { $0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces) }
}

private func xmlValue(_ element: String, in xml: String) -> String? {
    let pattern = "<\(element)>(.*?)</\(element)>"
    guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(xml.startIndex..., in: xml)
    guard let match = expression.firstMatch(in: xml, range: range), let valueRange = Range(match.range(at: 1), in: xml) else { return nil }
    return String(xml[valueRange])
}

private func firstAVTransportControlURL(in xml: String) -> String? {
    let pattern = "<service>.*?<serviceType>[^<]*AVTransport[^<]*</serviceType>.*?<controlURL>(.*?)</controlURL>.*?</service>"
    guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
    let range = NSRange(xml.startIndex..., in: xml)
    guard let match = expression.firstMatch(in: xml, range: range), let valueRange = Range(match.range(at: 1), in: xml) else { return nil }
    return String(xml[valueRange])
}
