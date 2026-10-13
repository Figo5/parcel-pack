import Foundation

public struct TycoonTeam: Equatable, Codable, Sendable {
    public static let maxWorkers = 20
    public static let storageCapacity = 3
    public var workers: Int
    public var hasManager: Bool
    public var pendingCash: Int
    public var pendingOrders: Int
    public var progressSeconds: Double

    public init(workers: Int = 0, hasManager: Bool = false, pendingCash: Int = 0,
                pendingOrders: Int = 0, progressSeconds: Double = 0) {
        self.workers = workers; self.hasManager = hasManager; self.pendingCash = pendingCash
        self.pendingOrders = pendingOrders; self.progressSeconds = progressSeconds
    }

    private enum CodingKeys: String, CodingKey { case workers, hasManager, pendingCash, pendingOrders, progressSeconds }

    public init(from decoder: any Decoder) throws {
        let saved = try decoder.container(keyedBy: CodingKeys.self)
        workers = try saved.decodeIfPresent(Int.self, forKey: .workers) ?? 0
        hasManager = try saved.decodeIfPresent(Bool.self, forKey: .hasManager) ?? false
        pendingCash = try saved.decodeIfPresent(Int.self, forKey: .pendingCash) ?? 0
        pendingOrders = try saved.decodeIfPresent(Int.self, forKey: .pendingOrders) ?? 0
        progressSeconds = try saved.decodeIfPresent(Double.self, forKey: .progressSeconds) ?? 0
    }

    public var isValid: Bool {
        guard (0...Self.maxWorkers).contains(workers), (0...Self.storageCapacity).contains(pendingOrders),
              (0...50_000).contains(pendingCash), progressSeconds.isFinite,
              progressSeconds >= 0 && progressSeconds < 120 else { return false }
        if workers == 0 { return !hasManager && pendingOrders == 0 && pendingCash == 0 && progressSeconds == 0 }
        return pendingOrders == 0 ? pendingCash == 0 : pendingCash > 0
    }
}

public struct StaffReport: Equatable, Sendable {
    public var earned: Int
    public var packedOrders: Int
    public init(earned: Int = 0, packedOrders: Int = 0) { self.earned = earned; self.packedOrders = packedOrders }
    public var isEmpty: Bool { earned == 0 && packedOrders == 0 }
}

extension TycoonCustomer {
    public static var automatableCustomers: [TycoonCustomer] { Array(allCases.prefix(6)) }
    public var canAutomate: Bool { Self.automatableCustomers.contains(self) }
}

extension TycoonAccount {
    public static var automatableCustomers: [TycoonCustomer] { TycoonCustomer.automatableCustomers }

    public func workerCost(for customer: TycoonCustomer) -> Int? {
        let team = teams[customer] ?? TycoonTeam()
        guard customer.canAutomate, team.isValid, team.workers < TycoonTeam.maxWorkers else { return nil }
        return customer.basePay * 6 * (100 + 25 * team.workers) / 100
    }

    public func managerCost(for customer: TycoonCustomer) -> Int? {
        guard customer.canAutomate, !(teams[customer]?.hasManager ?? false) else { return nil }
        return customer.basePay * 15
    }

    public func canHireWorker(for customer: TycoonCustomer) -> Bool {
        guard isValid, isUnlocked(customer), let cost = workerCost(for: customer) else { return false }
        return cash >= cost
    }

    public func canHireManager(for customer: TycoonCustomer) -> Bool {
        guard isValid, isUnlocked(customer), let team = teams[customer], team.workers > 0,
              let cost = managerCost(for: customer) else { return false }
        return cash >= cost
    }

    @discardableResult public mutating func hireWorker(for customer: TycoonCustomer) -> Bool {
        guard canHireWorker(for: customer), let cost = workerCost(for: customer) else { return false }
        var team = teams[customer] ?? TycoonTeam()
        cash -= cost; team.workers += 1; teams[customer] = team
        return true
    }

    @discardableResult public mutating func hireManager(for customer: TycoonCustomer) -> Bool {
        guard canHireManager(for: customer), let cost = managerCost(for: customer), var team = teams[customer] else { return false }
        cash -= cost; team.hasManager = true; teams[customer] = team
        _ = collectStaff(for: customer)
        return true
    }

    @discardableResult public mutating func collectStaff(for customer: TycoonCustomer) -> Int {
        guard isValid, var team = teams[customer], team.pendingOrders > 0,
              automatedOrders <= TycoonLimits.automatedOrders - team.pendingOrders,
              cash <= TycoonLimits.money - team.pendingCash,
              totalEarned <= TycoonLimits.money - team.pendingCash else { return 0 }
        let collected = team.pendingCash
        cash += collected; totalEarned += collected; automatedOrders += team.pendingOrders
        team.pendingCash = 0; team.pendingOrders = 0; teams[customer] = team
        return collected
    }

    public func workerInterval(for customer: TycoonCustomer) -> Double {
        guard customer.canAutomate, let team = teams[customer], team.isValid, team.workers > 0,
              (0...DepotUpgrade.maxLevel).contains(level(.conveyor)) else { return 0 }
        return 120 / (1 + 0.15 * Double(team.workers - 1)) / (1 + 0.05 * Double(level(.conveyor)))
    }

    public func workerPayout(for customer: TycoonCustomer) -> Int {
        guard customer.canAutomate, levels.values.allSatisfy({ (0...DepotUpgrade.maxLevel).contains($0) }) else { return 0 }
        let equipment = customer.basePay + 8 * level(.workbench) + 4 * level(.shelves) + 6 * level(.labels)
        return equipment * (100 + 10 * level(.van)) * (100 + 5 * level(.dispatchDesk)) / 20_000
    }

    static func maximumWorkerPayout(for customer: TycoonCustomer) -> Int {
        (customer.basePay + 18 * DepotUpgrade.maxLevel) * (100 + 10 * DepotUpgrade.maxLevel)
            * (100 + 5 * DepotUpgrade.maxLevel) / 20_000
    }

    /// Packed orders may wait on an unmanaged team's shelf; earned cash is money already banked.
    @discardableResult public mutating func advanceStaff(by elapsed: TimeInterval) -> StaffReport {
        guard isValid, elapsed.isFinite, elapsed > 0 else { return StaffReport() }
        let elapsed = min(elapsed, 8 * 60 * 60)
        var report = StaffReport()
        for customer in Self.automatableCustomers {
            guard let existing = teams[customer], existing.workers > 0 else { continue }
            if existing.hasManager { report.earned += collectStaff(for: customer) }
            guard var team = teams[customer] else { continue }
            if !team.hasManager && team.pendingOrders == TycoonTeam.storageCapacity {
                team.progressSeconds = 0; teams[customer] = team
                continue
            }
            let interval = workerInterval(for: customer)
            let payout = workerPayout(for: customer)
            guard interval > 0, payout > 0 else { continue }
            let progress = team.progressSeconds + elapsed
            let possible = Int(floor((progress + 0.000_000_001) / interval))
            let pendingCash = teams.values.reduce(0) { $0 + $1.pendingCash }
            let pendingOrders = teams.values.reduce(0) { $0 + $1.pendingOrders }
            let moneyCapacity = max(0, min(TycoonLimits.money - cash, TycoonLimits.money - totalEarned) - pendingCash) / payout
            let counterCapacity = max(0, TycoonLimits.automatedOrders - automatedOrders - pendingOrders)
            let shelfCapacity = team.hasManager ? possible : TycoonTeam.storageCapacity - team.pendingOrders
            let produced = min(min(possible, shelfCapacity), min(moneyCapacity, counterCapacity))
            // Time while a shelf or business limit is full is not queued as future work.
            if produced < possible || (!team.hasManager && team.pendingOrders + produced == TycoonTeam.storageCapacity) {
                team.progressSeconds = 0
            } else {
                team.progressSeconds = max(0, progress - Double(produced) * interval)
            }
            if team.hasManager {
                cash += produced * payout; totalEarned += produced * payout; automatedOrders += produced
                report.earned += produced * payout
            } else {
                team.pendingCash += produced * payout; team.pendingOrders += produced
            }
            report.packedOrders += produced
            teams[customer] = team
        }
        return report
    }
}
