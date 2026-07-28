import Foundation

/// A DLNA/UPnP media renderer discovered on the local network.
public struct MediaDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let controlURL: URL
    public let descriptionURL: URL

    public init(id: String, name: String, controlURL: URL, descriptionURL: URL) {
        self.id = id
        self.name = name
        self.controlURL = controlURL
        self.descriptionURL = descriptionURL
    }
}
