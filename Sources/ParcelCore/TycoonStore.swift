import Foundation

public struct SavedTycoon: Codable, Equatable, Sendable {
    public var version: Int = 2
    public var account: TycoonAccount
    public var session: TycoonSession?
    public var staffUpdatedAt: Date?

    public init(account: TycoonAccount, session: TycoonSession?, staffUpdatedAt: Date? = nil) {
        self.account = account
        self.session = session
        self.staffUpdatedAt = staffUpdatedAt
    }

    private enum CodingKeys: String, CodingKey { case version, account, session, staffUpdatedAt }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        account = try container.decode(TycoonAccount.self, forKey: .account)
        // A broken board must not make the separately decoded business disappear.
        session = try? container.decodeIfPresent(TycoonSession.self, forKey: .session)
        staffUpdatedAt = try? container.decodeIfPresent(Date.self, forKey: .staffUpdatedAt)
    }

    public func accepts(_ candidate: TycoonSession) -> Bool {
        guard account.isValid, candidate.isValid else { return false }
        if account.accepts(candidate.order) { return true }
        return candidate.state.isComplete && candidate.order.sequence == account.completedOrders
            && candidate.order == account.lastDelivery?.order
    }

    public var isValid: Bool {
        (1...2).contains(version) && account.isValid && (session.map(accepts) ?? true)
            && (staffUpdatedAt.map(Self.validDate) ?? true)
    }

    public static func validDate(_ date: Date) -> Bool {
        let seconds = date.timeIntervalSince1970
        return seconds.isFinite && (0...4_102_444_800).contains(seconds)
    }
}

public struct TycoonStore {
    public static let key = "parcel-pack.tycoon.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> SavedTycoon? {
        guard let data = defaults.data(forKey: Self.key), data.count <= 128_000,
              var saved = try? JSONDecoder().decode(SavedTycoon.self, from: data),
              (1...2).contains(saved.version), saved.account.isValid else { return nil }
        if let session = saved.session, !saved.accepts(session) { saved.session = nil }
        if let date = saved.staffUpdatedAt, !SavedTycoon.validDate(date) { saved.staffUpdatedAt = nil }
        return saved
    }

    @discardableResult public func save(_ saved: SavedTycoon) -> Bool {
        guard saved.isValid, let data = try? JSONEncoder().encode(saved), data.count <= 128_000 else { return false }
        // Bank, equipment, and receipt are one snapshot; payment cannot outlive its receipt.
        defaults.set(data, forKey: Self.key)
        return true
    }
}
