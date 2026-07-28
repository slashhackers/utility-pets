import SwiftUI

/// Owns installed pets and their lifecycle; the host injects it instead of using global state.
@MainActor
public final class PetRegistry: ObservableObject {
    public let pets: [any PetPlugin]
    @Published public var selectedPetID: String
    public init(pets: [any PetPlugin]) {
        precondition(!pets.isEmpty, "Utility Pets needs at least one registered pet.")
        self.pets = pets
        self.selectedPetID = pets[0].id
    }
    public var selectedPet: (any PetPlugin)? { pets.first { $0.id == selectedPetID } }
    public func startAll() async { for pet in pets { await pet.start() } }
    public func stopAll() async { for pet in pets { await pet.stop() } }
}
