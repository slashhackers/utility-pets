import Darwin
import Foundation

/// Minimal local HTTP server with byte-range support for DLNA renderers.
final class MediaStreamServer: @unchecked Sendable {
    private let fileURL: URL
    private let port: UInt16
    private let queue = DispatchQueue(label: "dev.utilitypets.scooby.media-server", qos: .userInitiated, attributes: .concurrent)
    private var socketFD: Int32 = -1
    private var running = false

    init(fileURL: URL, port: UInt16 = 8_888) { self.fileURL = fileURL; self.port = port }

    func start() throws {
        socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { throw CocoaError(.fileWriteUnknown) }
        var reuse: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = INADDR_ANY.bigEndian
        let bound = withUnsafePointer(to: &address) { pointer in pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard bound == 0, listen(socketFD, 10) == 0 else { close(socketFD); throw CocoaError(.fileWriteNoPermission) }
        running = true
        queue.async { [weak self] in self?.acceptConnections() }
    }

    func stop() { running = false; if socketFD >= 0 { close(socketFD); socketFD = -1 } }

    private func acceptConnections() {
        while running {
            let client = accept(socketFD, nil, nil)
            guard client >= 0 else { continue }
            queue.async { [weak self] in self?.respond(to: client) }
        }
    }

    private func respond(to client: Int32) {
        defer { close(client) }
        var requestBytes = [UInt8](repeating: 0, count: 4096)
        let received = recv(client, &requestBytes, requestBytes.count, 0)
        guard received > 0, let request = String(bytes: requestBytes.prefix(Int(received)), encoding: .utf8),
              let file = FileHandle(forReadingAtPath: fileURL.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let sizeNumber = attributes[.size] as? NSNumber else { return }
        defer { try? file.close() }
        let size = sizeNumber.uint64Value
        let range = byteRange(in: request, size: size)
        guard range.start < size else { write("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Length: 0\r\n\r\n", to: client); return }
        let length = range.end - range.start + 1
        let status = range.wasRequested ? "206 Partial Content" : "200 OK"
        let contentRange = range.wasRequested ? "Content-Range: bytes \(range.start)-\(range.end)/\(size)\r\n" : ""
        write("HTTP/1.1 \(status)\r\nContent-Type: \(mimeType)\r\nContent-Length: \(length)\r\nAccept-Ranges: bytes\r\n\(contentRange)Connection: close\r\n\r\n", to: client)
        try? file.seek(toOffset: range.start)
        var remaining = length
        while remaining > 0, let chunk = try? file.read(upToCount: Int(min(UInt64(64 * 1024), remaining))), !chunk.isEmpty {
            let sent = chunk.withUnsafeBytes { send(client, $0.baseAddress, chunk.count, 0) }
            guard sent > 0 else { return }
            remaining -= UInt64(sent)
        }
    }

    private var mimeType: String {
        switch fileURL.pathExtension.lowercased() { case "mp4", "m4v": "video/mp4"; case "mov": "video/quicktime"; case "mkv": "video/x-matroska"; case "mp3": "audio/mpeg"; default: "application/octet-stream" }
    }

    private func byteRange(in request: String, size: UInt64) -> (start: UInt64, end: UInt64, wasRequested: Bool) {
        guard let line = request.split(whereSeparator: \.isNewline).first(where: { $0.lowercased().hasPrefix("range:") }) else { return (0, size - 1, false) }
        let value = line.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "bytes=", with: "")
        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let start = UInt64(parts.first ?? "") ?? 0
        let end = min(UInt64(parts.count > 1 ? parts[1] : "") ?? (size - 1), size - 1)
        return (start, end, true)
    }

    private func write(_ response: String, to client: Int32) { _ = response.withCString { send(client, $0, strlen($0), 0) } }
}
