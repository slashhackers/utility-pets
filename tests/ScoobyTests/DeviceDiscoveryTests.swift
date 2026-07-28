import DeviceDiscovery
import Foundation
import Testing

@Test("Media devices preserve the control endpoint needed for DLNA commands")
func mediaDeviceStoresControlEndpoint() throws {
    let controlURL = try #require(URL(string: "http://tv.local/upnp/control"))
    let descriptionURL = try #require(URL(string: "http://tv.local/device.xml"))
    let device = MediaDevice(id: "uuid:test", name: "Living Room", controlURL: controlURL, descriptionURL: descriptionURL)
    #expect(device.controlURL == controlURL)
    #expect(device.name == "Living Room")
}
