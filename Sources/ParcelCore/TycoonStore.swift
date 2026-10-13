import Foundation

public struct SavedTycoon: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var account: TycoonAccount
    public var session: TycoonSession?

    public init(account: TycoonAccount, session: TycoonSession?) {
        self.account = account
        self.session = session
    }

    private enum CodingKeys: String, CodingKey { case version, account, session }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        account = try container.decode(TycoonAccount.self, forKey: .account)
        // A broken board must not make the separately decoded business disappear.
        session = try? container.decodeIfPresent(TycoonSession.self, forKey: .session)
    }

    public func accepts(_ candidate: TycoonSession) -> Bool {
        guard account.isValid, candidate.isValid else { return false }
        if account.accepts(candidate.order) { return true }
        return candidate.state.isComplete && candidate.order.sequence == account.completedOrders
            && candidate.order == account.lastDelivery?.order
    }

    public var isValid: Bool {
        version == 1 && account.isValid && (session.map(accepts) ?? true)
    }
}

public struct TycoonStore {
    public static let key = "parcel-pack.tycoon.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> SavedTycoon? {
        guard let data = defaults.data(forKey: Self.key), data.count <= 128_000,
              var saved = try? JSONDecoder().decode(SavedTycoon.self, from: data),
              saved.version == 1, saved.account.isValid else { return nil }
        if let session = saved.session, !saved.accepts(session) { saved.session = nil }
        return saved
    }

    @discardableResult public func save(_ saved: SavedTycoon) -> Bool {
        guard saved.isValid, let data = try? JSONEncoder().encode(saved), data.count <= 128_000 else { return false }
        // Bank, equipment, and receipt are one snapshot; payment cannot outlive its receipt.
        defaults.set(data, forKey: Self.key)
        return true
    }
}
