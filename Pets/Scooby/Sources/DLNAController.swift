import DeviceDiscovery
import Foundation

enum DLNAControllerError: LocalizedError {
    case invalidResponse
    case unsuccessfulResponse(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The TV returned an invalid response."
        case .unsuccessfulResponse(let status): "The TV rejected the command (HTTP \(status))."
        }
    }
}

struct DLNAController {
    let device: MediaDevice
    let session: URLSession

    init(device: MediaDevice, session: URLSession = .shared) {
        self.device = device
        self.session = session
    }

    func play(mediaURL: URL, title: String, mimeType: String) async throws {
        let metadata = didlMetadata(title: title, mediaURL: mediaURL, mimeType: mimeType)
        try await send(action: "SetAVTransportURI", body: """
        <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
          <InstanceID>0</InstanceID><CurrentURI>\(escape(mediaURL.absoluteString))</CurrentURI><CurrentURIMetaData>\(metadata)</CurrentURIMetaData>
        </u:SetAVTransportURI>
        """)
        try await resume()
    }

    func resume() async throws {
        try await send(action: "Play", body: "<u:Play xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID><Speed>1</Speed></u:Play>")
    }

    func pause() async throws {
        try await send(action: "Pause", body: "<u:Pause xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Pause>")
    }

    func stop() async throws {
        try await send(action: "Stop", body: "<u:Stop xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Stop>")
    }

    func seek(to seconds: Int) async throws {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remaining = seconds % 60
        let time = String(format: "%02d:%02d:%02d", hours, minutes, remaining)
        try await send(action: "Seek", body: "<u:Seek xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID><Unit>REL_TIME</Unit><Target>\(time)</Target></u:Seek>")
    }

    private func send(action: String, body: String) async throws {
        let envelope = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>\(body)</s:Body></s:Envelope>
        """
        var request = URLRequest(url: device.controlURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.httpBody = Data(envelope.utf8)
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"urn:schemas-upnp-org:service:AVTransport:1#\(action)\"", forHTTPHeaderField: "SOAPAction")
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw DLNAControllerError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else { throw DLNAControllerError.unsuccessfulResponse(httpResponse.statusCode) }
    }

    private func didlMetadata(title: String, mediaURL: URL, mimeType: String) -> String {
        let value = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="0" parentID="-1" restricted="1"><dc:title>\(title)</dc:title><upnp:class>object.item.videoItem</upnp:class><res protocolInfo="http-get:*:\(mimeType):*">\(mediaURL.absoluteString)</res></item></DIDL-Lite>
        """
        return escape(value)
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
