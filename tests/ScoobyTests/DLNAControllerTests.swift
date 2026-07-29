@testable import Scooby
import DeviceDiscovery
import Foundation
import XCTest

final class DLNAControllerTests: XCTestCase {
    private var device: MediaDevice!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingURLProtocol.self]
        session = URLSession(configuration: configuration)
        RecordingURLProtocol.recordedRequests = []
        RecordingURLProtocol.responseData = nil
        device = MediaDevice(
            id: "tv-1",
            name: "Virtual Smart TV",
            controlURL: URL(string: "http://127.0.0.1:8080/upnp/control/AVTransport")!,
            descriptionURL: URL(string: "http://127.0.0.1:8080/description.xml")!
        )
    }

    func testPlaySendsSetAVTransportURIAndPlayActions() async throws {
        let controller = DLNAController(device: device, session: session)
        let mediaURL = URL(string: "http://192.168.1.5:8888/stream")!
        
        try await controller.play(mediaURL: mediaURL, title: "TestVideo.mp4", mimeType: "video/mp4")

        XCTAssertEqual(RecordingURLProtocol.recordedRequests.count, 2)
        
        let uriRequest = RecordingURLProtocol.recordedRequests[0]
        XCTAssertEqual(uriRequest.value(forHTTPHeaderField: "SOAPAction"), "\"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI\"")
        if let body = uriRequest.httpBodyString {
            XCTAssertTrue(body.contains("<CurrentURI>http://192.168.1.5:8888/stream</CurrentURI>"))
            XCTAssertTrue(body.contains("&lt;dc:title&gt;TestVideo.mp4&lt;/dc:title&gt;"))
        } else {
            XCTFail("Missing SetAVTransportURI HTTP body")
        }

        let playRequest = RecordingURLProtocol.recordedRequests[1]
        XCTAssertEqual(playRequest.value(forHTTPHeaderField: "SOAPAction"), "\"urn:schemas-upnp-org:service:AVTransport:1#Play\"")
    }

    func testPauseSendsPauseSOAPAction() async throws {
        let controller = DLNAController(device: device, session: session)
        try await controller.pause()

        XCTAssertEqual(RecordingURLProtocol.recordedRequests.count, 1)
        let request = RecordingURLProtocol.recordedRequests[0]
        XCTAssertEqual(request.value(forHTTPHeaderField: "SOAPAction"), "\"urn:schemas-upnp-org:service:AVTransport:1#Pause\"")
        XCTAssertTrue(request.httpBodyString?.contains("<u:Pause") ?? false)
    }

    func testStopSendsStopSOAPAction() async throws {
        let controller = DLNAController(device: device, session: session)
        try await controller.stop()

        XCTAssertEqual(RecordingURLProtocol.recordedRequests.count, 1)
        let request = RecordingURLProtocol.recordedRequests[0]
        XCTAssertEqual(request.value(forHTTPHeaderField: "SOAPAction"), "\"urn:schemas-upnp-org:service:AVTransport:1#Stop\"")
        XCTAssertTrue(request.httpBodyString?.contains("<u:Stop") ?? false)
    }

    func testSeekFormatsRelTimeSOAPAction() async throws {
        let controller = DLNAController(device: device, session: session)
        // Seek to 1 hour, 15 minutes, 30 seconds = 4530 seconds
        try await controller.seek(to: 4530)

        XCTAssertEqual(RecordingURLProtocol.recordedRequests.count, 1)
        let request = RecordingURLProtocol.recordedRequests[0]
        XCTAssertEqual(request.value(forHTTPHeaderField: "SOAPAction"), "\"urn:schemas-upnp-org:service:AVTransport:1#Seek\"")
        XCTAssertTrue(request.httpBodyString?.contains("<Target>01:15:30</Target>") ?? false)
    }

    func testGetPositionInfoParsesRelTimeAndDuration() async throws {
        let responseXML = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body>
            <u:GetPositionInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <TrackDuration>01:30:00</TrackDuration>
              <RelTime>00:10:45</RelTime>
            </u:GetPositionInfoResponse>
          </s:Body>
        </s:Envelope>
        """
        RecordingURLProtocol.responseData = Data(responseXML.utf8)

        let controller = DLNAController(device: device, session: session)
        let info = try await controller.getPositionInfo()

        XCTAssertEqual(info.relTime, 645, "00:10:45 should parse to 645 seconds")
        XCTAssertEqual(info.duration, 5400, "01:30:00 should parse to 5400 seconds")
    }
}

final class RecordingURLProtocol: URLProtocol, @unchecked Sendable {
    static var recordedRequests: [URLRequest] = []
    static var responseData: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.recordedRequests.append(request)
        let data = Self.responseData ?? Data()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

extension URLRequest {
    var httpBodyString: String? {
        if let data = httpBody { return String(data: data, encoding: .utf8) }
        if let stream = httpBodyStream {
            stream.open()
            defer { stream.close() }
            var result = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read > 0 { result.append(buffer, count: read) } else { break }
            }
            return String(data: result, encoding: .utf8)
        }
        return nil
    }
}
