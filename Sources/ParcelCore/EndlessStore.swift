import Foundation

public struct SavedEndless: Codable, Equatable, Sendable {
    public var version = 1
    public var best: Int
    public var state: EndlessState?

    public init(best: Int, state: EndlessState?) {
        self.best = best
        self.state = state
    }

    private enum CodingKeys: String, CodingKey { case version, best, state }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        best = try container.decode(Int.self, forKey: .best)
        // Preserve a valid record even when a nested active run cannot be decoded.
        state = try? container.decodeIfPresent(EndlessState.self, forKey: .state)
    }

    public var hasValidBest: Bool {
        version == 1 && (0...EndlessState.scoreLimit).contains(best) && best.isMultiple(of: 10)
    }

    public var isValid: Bool {
        hasValidBest && (state.map { $0.isValid && $0.score <= best } ?? true)
    }
}

public struct EndlessStore {
    public static let key = "parcel-pack.endless.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> SavedEndless? {
        guard let data = defaults.data(forKey: Self.key), data.count <= 32_000,
              var saved = try? JSONDecoder().decode(SavedEndless.self, from: data), saved.hasValidBest else { return nil }
        if let state = saved.state {
            if state.isValid { saved.best = max(saved.best, state.score) }
            else { saved.state = nil }
        }
        return saved
    }

    @discardableResult public func save(_ saved: SavedEndless) -> Bool {
        guard saved.isValid, let data = try? JSONEncoder().encode(saved), data.count <= 32_000 else { return false }
        defaults.set(data, forKey: Self.key)
        return true
    }
}
