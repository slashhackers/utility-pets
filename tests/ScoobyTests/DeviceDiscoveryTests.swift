import DeviceDiscovery
import Foundation
import XCTest

final class DeviceDiscoveryTests: XCTestCase {
    func testMediaDeviceStoresControlEndpoint() throws {
        let controlURL = try XCTUnwrap(URL(string: "http://tv.local/upnp/control"))
        let descriptionURL = try XCTUnwrap(URL(string: "http://tv.local/device.xml"))
        let device = MediaDevice(id: "uuid:test", name: "Living Room", controlURL: controlURL, descriptionURL: descriptionURL)
        XCTAssertEqual(device.controlURL, controlURL)
        XCTAssertEqual(device.name, "Living Room")
    }
}
