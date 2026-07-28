/// Provider-neutral contract for the future Sage AI pet.
public protocol AIProvider: Sendable { func respond(to prompt: String) async throws -> String }
