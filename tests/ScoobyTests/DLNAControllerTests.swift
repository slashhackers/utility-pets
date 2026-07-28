@testable import Scooby
import DeviceDiscovery
import Foundation
import Testing

@Test("Pause sends the AVTransport SOAP action")
func pauseSendsSOAPAction() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [RecordingURLProtocol.self]
    RecordingURLProtocol.request = nil
    let device = MediaDevice(id: "tv", name: "Test TV", controlURL: URL(string: "http://tv.local/control")!, descriptionURL: URL(string: "http://tv.local/description")!)
    try await DLNAController(device: device, session: URLSession(configuration: configuration)).pause()
    #expect(RecordingURLProtocol.request?.value(forHTTPHeaderField: "SOAPAction") == "\"urn:schemas-upnp-org:service:AVTransport:1#Pause\"")
}

final class RecordingURLProtocol: URLProtocol, @unchecked Sendable {
    static var request: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.request = request
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
