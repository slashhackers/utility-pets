import SwiftUI

/// The common contract that every Utility Pet implements.
@MainActor
public protocol PetPlugin: AnyObject, Identifiable where ID == String {
    var id: String { get }
    var displayName: String { get }
    var icon: String { get }
    var tagline: String { get }
    func start() async
    func stop() async
    func commands() -> [PetCommand]
    func makeView() -> AnyView
}

public struct PetCommand: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}
