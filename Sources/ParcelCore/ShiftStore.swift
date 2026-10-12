import Foundation

public struct ShiftRecord: Codable, Equatable, Sendable {
    public var bestShiftsCleared: Int
    public var bestRunScore: Int
    public var runsFinished: Int

    public init(bestShiftsCleared: Int = 0, bestRunScore: Int = 0, runsFinished: Int = 0) {
        self.bestShiftsCleared = bestShiftsCleared
        self.bestRunScore = bestRunScore
        self.runsFinished = runsFinished
    }

    var isValid: Bool {
        bestShiftsCleared >= 0 && bestRunScore >= 0 && runsFinished >= 0
    }
}

public struct SavedShift: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var run: ShiftRun
    public var rotations: [Int: Int]

    public init(run: ShiftRun, rotations: [Int: Int] = [:]) {
        self.run = run
        self.rotations = rotations
    }

    public var isValid: Bool {
        guard version == 1, run.isValid else { return false }
        for (parcelID, rotation) in rotations {
            guard run.parcel(parcelID) != nil, (0..<4).contains(rotation) else { return false }
        }
        return true
    }
}

public struct ShiftStore: @unchecked Sendable {
    public static let key = "parcel-pack.shift.v1"
    public static let recordKey = "parcel-pack.shift-record.v1"
    private static let maxBytes = 256_000

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SavedShift? {
        guard let data = defaults.data(forKey: Self.key), data.count <= Self.maxBytes,
              let saved = try? JSONDecoder().decode(SavedShift.self, from: data),
              saved.isValid else { return nil }
        return saved
    }

    @discardableResult
    public func save(_ saved: SavedShift) -> Bool {
        guard saved.isValid, let data = try? JSONEncoder().encode(saved), data.count <= Self.maxBytes else {
            return false
        }
        defaults.set(data, forKey: Self.key)
        return true
    }

    public func loadRecord() -> ShiftRecord {
        guard let data = defaults.data(forKey: Self.recordKey),
              let record = try? JSONDecoder().decode(ShiftRecord.self, from: data),
              record.isValid else { return ShiftRecord() }
        return record
    }

    public func saveRecord(_ record: ShiftRecord) {
        guard record.isValid, let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: Self.recordKey)
    }
}
