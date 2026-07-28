import Foundation

/// Typed events let pets collaborate without direct dependencies.
public actor PetEventBus {
    private var continuations: [UUID: AsyncStream<PetEvent>.Continuation] = [:]
    public init() {}
    public func stream() -> AsyncStream<PetEvent> {
        let token = UUID()
        return AsyncStream<PetEvent> { [weak self] continuation in
            Task { [weak self] in
                await self?.register(continuation, for: token)
            }
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.remove(token)
                }
            }
        }
    }
    public func publish(_ event: PetEvent) { continuations.values.forEach { $0.yield(event) } }
    private func register(_ continuation: AsyncStream<PetEvent>.Continuation, for token: UUID) {
        continuations[token] = continuation
    }
    private func remove(_ token: UUID) { continuations[token] = nil }
}

public enum PetEvent: Sendable, Equatable {
    case petStarted(id: String)
    case petStopped(id: String)
    case commandRequested(petID: String, commandID: String)
}
