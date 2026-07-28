import Darwin
import Foundation

enum NetworkAddress {
    static func localIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = current?.pointee {
            defer { current = interface.ifa_next }
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name != "lo0" else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                let address = String(cString: hostname)
                if address != "127.0.0.1" { return address }
            }
        }
        return nil
    }
}
