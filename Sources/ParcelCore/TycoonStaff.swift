import Foundation

public struct TycoonTeam: Equatable, Codable, Sendable {
    public static let maxWorkers = 20
    public static let storageCapacity = 3
    public var workers: Int
    public var hasManager: Bool
    public var pendingCash: Int
    public var pendingOrders: Int
    public var progressSeconds: Double
    public var specialty: CrewSpecialty

    public init(workers: Int = 0, hasManager: Bool = false, pendingCash: Int = 0,
                pendingOrders: Int = 0, progressSeconds: Double = 0, specialty: CrewSpecialty = .general) {
        self.workers = workers; self.hasManager = hasManager; self.pendingCash = pendingCash
        self.pendingOrders = pendingOrders; self.progressSeconds = progressSeconds
        self.specialty = specialty
    }

    private enum CodingKeys: String, CodingKey { case workers, hasManager, pendingCash, pendingOrders, progressSeconds, specialty }

    public init(from decoder: any Decoder) throws {
        let saved = try decoder.container(keyedBy: CodingKeys.self)
        workers = try saved.decodeIfPresent(Int.self, forKey: .workers) ?? 0
        hasManager = try saved.decodeIfPresent(Bool.self, forKey: .hasManager) ?? false
        pendingCash = try saved.decodeIfPresent(Int.self, forKey: .pendingCash) ?? 0
        pendingOrders = try saved.decodeIfPresent(Int.self, forKey: .pendingOrders) ?? 0
        progressSeconds = try saved.decodeIfPresent(Double.self, forKey: .progressSeconds) ?? 0
        specialty = (try? saved.decodeIfPresent(CrewSpecialty.self, forKey: .specialty)) ?? .general
        if !hasManager { specialty = .general }
    }

    public var isValid: Bool {
        guard (0...Self.maxWorkers).contains(workers), (0...Self.storageCapacity).contains(pendingOrders),
              (0...200_000).contains(pendingCash), progressSeconds.isFinite,
              progressSeconds >= 0 && progressSeconds < 120 else { return false }
        guard hasManager || specialty == .general else { return false }
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
    public static var automatableCustomers: [TycoonCustomer] { Array(allCases.prefix(6)) + [.harborOutfitters, .galleryStore, .uptownBoutique] }
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
        recordEarnings(collected, automated: team.pendingOrders); automatedOrders += team.pendingOrders
        addRelationship(team.pendingOrders * (team.specialty == .mentor ? 2 : 1), for: customer)
        let reward = progressContract(customer: customer, manual: false, count: team.pendingOrders)
        team.pendingCash = 0; team.pendingOrders = 0; teams[customer] = team
        return collected + reward
    }

    public func workerInterval(for customer: TycoonCustomer) -> Double {
        guard customer.canAutomate, let team = teams[customer], team.isValid, team.workers > 0,
              (0...DepotUpgrade.maxLevel).contains(level(.conveyor)) else { return 0 }
        return 120 / (1 + 0.15 * Double(team.workers - 1)) / (1 + 0.05 * Double(level(.conveyor)))
            / (team.hasManager ? 1.25 : 1)
            / (1 + 0.1 * Double(milestoneCount(.conveyor)))
            / (1 + 0.1 * Double(franchiseUpgradeLevel(.training)))
            / (team.specialty == .express ? 1.15 : 1)
    }

    public func workerPayout(for customer: TycoonCustomer) -> Int {
        guard customer.canAutomate, levels.values.allSatisfy({ (0...DepotUpgrade.maxLevel).contains($0) }) else { return 0 }
        let equipment = customer.basePay + 8 * level(.workbench) + 4 * level(.shelves) + 6 * level(.labels)
        let payout = equipment * (100 + 10 * level(.van)) * (100 + 5 * level(.dispatchDesk)) / 20_000
        var pay = teams[customer]?.hasManager == true ? payout * 125 / 100 : payout
        pay = pay * (100 + 10 * milestoneCount(.dispatchDesk)) / 100
        pay = pay * (100 + 10 * milestoneCount(.van)) / 100
        pay = pay * (100 + 3 * relationshipLevel(for: customer)) / 100
        pay = pay * (teams[customer]?.specialty == .careful ? 115 : 100) / 100
        return pay * (progression.manualBoostOrders > 0 ? 120 : 100) / 100
    }

    static func maximumWorkerPayout(for customer: TycoonCustomer) -> Int {
        let payout = (customer.basePay + 18 * DepotUpgrade.maxLevel) * (100 + 10 * DepotUpgrade.maxLevel)
            * (100 + 5 * DepotUpgrade.maxLevel) / 20_000
        return payout * 125 / 100 * 140 / 100 * 140 / 100 * 115 / 100 * 115 / 100 * 120 / 100
    }

    /// Settle shelves saved by earlier versions without changing a manual order's sequence.
    @discardableResult public mutating func settlePendingStaff() -> StaffReport {
        guard isValid else { return StaffReport() }
        var report = StaffReport()
        for customer in Self.automatableCustomers {
            guard let team = teams[customer], team.pendingOrders > 0 else { continue }
            let collected = collectStaff(for: customer)
            if collected > 0 {
                report.earned += collected
                report.packedOrders += team.pendingOrders
            }
        }
        return report
    }

    /// Every worker team ships completed boxes directly; managers improve its speed and pay.
    @discardableResult public mutating func advanceStaff(by elapsed: TimeInterval) -> StaffReport {
        guard isValid, elapsed.isFinite, elapsed >= 0 else { return StaffReport() }
        var report = settlePendingStaff()
        guard elapsed > 0 else { return report }
        var remaining = min(elapsed, Double(offlineHours * 60 * 60))
        let clients = Self.automatableCustomers.filter { (teams[$0]?.workers ?? 0) > 0 }
        let districts = Neighborhood.allCases.filter { progression.branches[$0] != nil }
        var blockedClients = Set<TycoonCustomer>()
        var blockedDistricts = Set<Neighborhood>()
        // Pay in event order, so XP rank-ups and finite dispatch boosts have the same
        // effect in a single offline catch-up as in one-second foreground ticks.
        while remaining > 0.000_000_001 {
            let working = clients.filter { !blockedClients.contains($0) }
            let branches = districts.filter { !blockedDistricts.contains($0) }
            let intervals = Dictionary(uniqueKeysWithValues: working.map { ($0, workerInterval(for: $0)) })
            let branchPay = Dictionary(uniqueKeysWithValues: branches.map { ($0, branchPayout($0)) })
            var next = remaining
            for client in working {
                next = min(next, max(0, (intervals[client] ?? 120) - (teams[client]?.progressSeconds ?? 0)))
            }
            for district in branches { next = min(next, max(0, 60 - (progression.branches[district]?.progressSeconds ?? 0))) }
            for client in working { teams[client]?.progressSeconds += next }
            for district in branches { progression.branches[district]?.progressSeconds += next }
            remaining = max(0, remaining - next)
            var event = false
            for client in working {
                let interval = intervals[client] ?? 120
                guard (teams[client]?.progressSeconds ?? 0) + 0.000_000_001 >= interval else { continue }
                event = true
                let pay = workerPayout(for: client)
                if canBankAutomated(pay) {
                    let left = max(0, (teams[client]?.progressSeconds ?? 0) - interval)
                    teams[client]?.progressSeconds = left
                    recordEarnings(pay, automated: 1); automatedOrders += 1
                    if progression.manualBoostOrders > 0 { progression.manualBoostOrders -= 1 }
                    addRelationship(teams[client]?.specialty == .mentor ? 2 : 1, for: client)
                    let reward = progressContract(customer: client, manual: false)
                    report.earned += pay + reward; report.packedOrders += 1
                } else {
                    teams[client]?.progressSeconds = 0; blockedClients.insert(client)
                }
            }
            for district in branches {
                guard (progression.branches[district]?.progressSeconds ?? 0) + 0.000_000_001 >= 60 else { continue }
                event = true
                let pay = branchPay[district] ?? 0
                if canBankAutomated(pay) {
                    let left = max(0, (progression.branches[district]?.progressSeconds ?? 0) - 60)
                    progression.branches[district]?.progressSeconds = left
                    recordEarnings(pay, automated: 1); automatedOrders += 1
                    report.earned += pay; report.packedOrders += 1
                } else {
                    progression.branches[district]?.progressSeconds = 0; blockedDistricts.insert(district)
                }
            }
            if next == 0 && !event { break }
        }
        return report
    }

    private func canBankAutomated(_ pay: Int) -> Bool {
        pay > 0 && automatedOrders < TycoonLimits.automatedOrders
            && cash <= TycoonLimits.money - pay - pendingStaffCash - contractReserve
            && totalEarned <= TycoonLimits.money - pay - pendingStaffCash - contractReserve
    }
}
