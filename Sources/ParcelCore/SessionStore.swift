import Foundation

/// A saved box is validated before it can become playable state.
public struct SavedSession: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var state: PackingState
    public var rotations: [Int: Int]
    public var shipped: Int
    public var boxNumber: Int
    public var completionCredited: Bool

    public init(state: PackingState, rotations: [Int: Int] = [:], shipped: Int = 0,
                boxNumber: Int = 1, completionCredited: Bool = false) {
        self.state = state
        self.rotations = rotations
        self.shipped = shipped
        self.boxNumber = boxNumber
        self.completionCredited = completionCredited
    }

    public var isValid: Bool {
        version == 1 && state.isValid && shipped >= 0 && shipped < Int.max
            && boxNumber > 0 && boxNumber < Int.max
            && rotations.count <= state.puzzle.parcels.count
            && rotations.allSatisfy { entry in
                state.puzzle.parcels.contains { $0.id == entry.key }
                    && (0..<4).contains(entry.value)
            }
    }
}

public struct SessionStore {
    private let defaults: UserDefaults
    public static let key = "parcel-pack.session.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SavedSession? {
        guard let data = defaults.data(forKey: Self.key), data.count <= 64_000,
              let session = try? JSONDecoder().decode(SavedSession.self, from: data),
              session.isValid else { return nil }
        return session
    }

    @discardableResult
    public func save(_ session: SavedSession) -> Bool {
        guard session.isValid, let data = try? JSONEncoder().encode(session) else {
            return false
        }
        defaults.set(data, forKey: Self.key)
        return true
    }
}
