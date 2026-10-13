import Foundation

public enum ContractKind: String, CaseIterable, Codable, Sendable {
    case supply, premium, landmark
    public var title: String { switch self { case .supply: "Supply run"; case .premium: "Premium packing"; case .landmark: "Landmark contract" } }
    public var detail: String { switch self { case .supply: "You or your crew can ship these orders."; case .premium: "Pack these boxes yourself for dispatch boosts and a permanent blueprint."; case .landmark: "Complete this major job yourself to qualify for a franchise." } }
}

public enum CrewSpecialty: String, CaseIterable, Codable, Sendable {
    case general, express, careful, mentor
    public var title: String { switch self { case .general: "General"; case .express: "Express"; case .careful: "Careful"; case .mentor: "Mentor" } }
    public var detail: String { switch self { case .general: "Balanced packing with no extra bonus."; case .express: "+15% packing speed."; case .careful: "+15% worker pay."; case .mentor: "Earn 2 relationship XP per crew delivery." } }
}

public enum FranchiseUpgrade: String, CaseIterable, Codable, Sendable {
    case training, buyingPower, premiumService, establishedBusiness, logistics
    public static let maxLevel = 5
    public var title: String { switch self { case .training: "Training"; case .buyingPower: "Buying power"; case .premiumService: "Premium service"; case .establishedBusiness: "Established business"; case .logistics: "Logistics" } }
    public var detail: String { switch self { case .training: "+10% crew speed and +5% branch pay per level."; case .buyingPower: "Equipment costs 5% less per level."; case .premiumService: "+10% manual shipment pay per level."; case .establishedBusiness: "Start your next franchise with $250 per level and a Corner Market worker."; case .logistics: "Earn offline for 2 extra hours per level." } }
}

public enum Neighborhood: String, CaseIterable, Codable, Sendable {
    case oldTown, harbor, artsQuarter, uptown
    public var title: String { switch self { case .oldTown: "Old Town"; case .harbor: "Harbor"; case .artsQuarter: "Arts Quarter"; case .uptown: "Uptown" } }
    public var detail: String { switch self { case .oldTown: "The neighborhood where your shipping business began."; case .harbor: "Waterfront shops and busy cargo routes."; case .artsQuarter: "Galleries and creative businesses need careful deliveries."; case .uptown: "A thriving district with premium dispatch routes." } }
    public var requiredFranchises: Int { switch self { case .oldTown: 0; case .harbor: 1; case .artsQuarter: 2; case .uptown: 3 } }
    var openingPrice: Int { switch self { case .oldTown: 0; case .harbor: 15_000; case .artsQuarter: 25_000; case .uptown: 40_000 } }
    var baseBranchPay: Int { switch self { case .oldTown: 0; case .harbor: 250; case .artsQuarter: 400; case .uptown: 650 } }
}

public struct TycoonBranch: Equatable, Codable, Sendable {
    public static let maxLevel = 10
    public var level: Int
    public var progressSeconds: Double
    public init(level: Int = 1, progressSeconds: Double = 0) { self.level = level; self.progressSeconds = progressSeconds }
    public var isValid: Bool { (1...Self.maxLevel).contains(level) && progressSeconds.isFinite && (0..<60).contains(progressSeconds) }
}

public struct TycoonContract: Equatable, Codable, Sendable, Identifiable {
    public let id: Int
    public let customer: TycoonCustomer
    public let kind: ContractKind
    public let title: String
    public let target: Int
    public let reward: Int
    public var progress: Int
    public init(id: Int, customer: TycoonCustomer, kind: ContractKind, title: String, target: Int, reward: Int, progress: Int = 0) {
        self.id = id; self.customer = customer; self.kind = kind; self.title = title
        self.target = target; self.reward = reward; self.progress = progress
    }
    public var isComplete: Bool { progress == target }
    var isValid: Bool { (1...300_000).contains(id) && (1...40).contains(target) && (1...1_000_000).contains(reward) && (0...target).contains(progress) && title.count <= 160 }
}

public struct TycoonProgression: Equatable, Codable, Sendable {
    public var relationships: [TycoonCustomer: Int] = [:]
    public var activeContract: TycoonContract?
    public var lastContract: TycoonContract?
    public var completedContracts = 0
    public var lifetimeContracts = 0
    public var majorContracts = 0
    public var manualBoostOrders = 0
    public var blueprints = 0
    public var franchises = 0
    public var stars = 0
    public var earnedStars = 0
    public var headOffice: [FranchiseUpgrade: Int] = [:]
    public var lifetimeManualOrders = 0
    public var lifetimeAutomatedOrders = 0
    public var lifetimeEarned = 0
    public var branches: [Neighborhood: TycoonBranch] = [:]
    public var district: Neighborhood = .oldTown
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case relationships, activeContract, lastContract, completedContracts, lifetimeContracts, majorContracts,
             manualBoostOrders, blueprints, franchises, stars, earnedStars, headOffice, lifetimeManualOrders,
             lifetimeAutomatedOrders, lifetimeEarned, branches, district
    }
    public init(from decoder: any Decoder) throws {
        let saved = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ type: T.Type, _ key: CodingKeys, default fallback: T) -> T {
            (try? saved.decodeIfPresent(type, forKey: key)) ?? fallback
        }
        relationships = value([TycoonCustomer: Int].self, .relationships, default: [:])
            .filter { (0...1_000_000).contains($0.value) }
        activeContract = try? saved.decodeIfPresent(TycoonContract.self, forKey: .activeContract)
        lastContract = try? saved.decodeIfPresent(TycoonContract.self, forKey: .lastContract)
        completedContracts = value(Int.self, .completedContracts, default: 0)
        if !(0...99_999).contains(completedContracts) { completedContracts = 0 }
        lifetimeContracts = value(Int.self, .lifetimeContracts, default: completedContracts)
        if !(completedContracts...1_000_000).contains(lifetimeContracts) { lifetimeContracts = completedContracts }
        majorContracts = value(Int.self, .majorContracts, default: 0)
        if !(0...completedContracts).contains(majorContracts) { majorContracts = 0 }
        manualBoostOrders = value(Int.self, .manualBoostOrders, default: 0)
        if !(0...120).contains(manualBoostOrders) { manualBoostOrders = 0 }
        blueprints = value(Int.self, .blueprints, default: 0)
        if !(0...10).contains(blueprints) { blueprints = 0 }
        franchises = value(Int.self, .franchises, default: 0)
        if !(0...1_000).contains(franchises) { franchises = 0 }
        earnedStars = value(Int.self, .earnedStars, default: 0)
        if !(0...1_000_000).contains(earnedStars) { earnedStars = 0 }
        stars = value(Int.self, .stars, default: 0)
        if !(0...earnedStars).contains(stars) { stars = 0 }
        headOffice = value([FranchiseUpgrade: Int].self, .headOffice, default: [:])
            .filter { (0...5).contains($0.value) }
        lifetimeManualOrders = value(Int.self, .lifetimeManualOrders, default: 0)
        if !(0...1_000_000_000_000).contains(lifetimeManualOrders) { lifetimeManualOrders = 0 }
        lifetimeAutomatedOrders = value(Int.self, .lifetimeAutomatedOrders, default: 0)
        if !(0...1_000_000_000_000).contains(lifetimeAutomatedOrders) { lifetimeAutomatedOrders = 0 }
        lifetimeEarned = value(Int.self, .lifetimeEarned, default: 0)
        if !(0...1_000_000_000_000).contains(lifetimeEarned) { lifetimeEarned = 0 }
        branches = value([Neighborhood: TycoonBranch].self, .branches, default: [:])
            .filter { $0.key != .oldTown && $0.key.requiredFranchises <= franchises && $0.value.isValid }
        district = value(Neighborhood.self, .district, default: .oldTown)
        if district != .oldTown && branches[district] == nil { district = .oldTown }
        if let contract = activeContract,
           !contract.isValid || contract.isComplete || !(completedContracts * 3 + 1...completedContracts * 3 + 3).contains(contract.id) {
            activeContract = nil
        }
        if let contract = lastContract, !contract.isValid || !contract.isComplete { lastContract = nil }
    }

    public var isValid: Bool {
        relationships.count <= TycoonCustomer.allCases.count && relationships.values.allSatisfy { (0...1_000_000).contains($0) }
            && (0...99_999).contains(completedContracts) && (completedContracts...1_000_000).contains(lifetimeContracts)
            && (0...completedContracts).contains(majorContracts) && (0...120).contains(manualBoostOrders)
            && (0...10).contains(blueprints) && (0...1_000).contains(franchises)
            && (0...1_000_000).contains(earnedStars) && (0...earnedStars).contains(stars)
            && headOffice.count <= FranchiseUpgrade.allCases.count && headOffice.values.allSatisfy { (0...5).contains($0) }
            && (0...1_000_000_000_000).contains(lifetimeManualOrders) && (0...1_000_000_000_000).contains(lifetimeAutomatedOrders)
            && (0...1_000_000_000_000).contains(lifetimeEarned) && branches.count <= 3
            && branches.allSatisfy { $0.key != .oldTown && $0.key.requiredFranchises <= franchises && $0.value.isValid }
            && district.requiredFranchises <= franchises && (district == .oldTown || branches[district] != nil)
            && (activeContract.map { $0.isValid && !$0.isComplete && $0.id / 3 <= completedContracts + 1 } ?? true)
            && (lastContract.map { $0.isValid && $0.isComplete } ?? true)
    }
}

extension TycoonAccount {
    public func relationshipXP(for customer: TycoonCustomer) -> Int { progression.relationships[customer] ?? 0 }
    public func relationshipLevel(for customer: TycoonCustomer) -> Int {
        let xp = relationshipXP(for: customer)
        return [10, 30, 75, 150, 300].filter { xp >= $0 }.count
    }
    public func relationshipTarget(for customer: TycoonCustomer) -> Int? { [10, 30, 75, 150, 300].first { $0 > relationshipXP(for: customer) } }
    public var offlineHours: Int { 8 + 2 * franchiseUpgradeLevel(.logistics) }
    public func franchiseUpgradeLevel(_ upgrade: FranchiseUpgrade) -> Int { max(0, min(5, progression.headOffice[upgrade] ?? 0)) }

    public var contractOffers: [TycoonContract] {
        guard isValid, progression.completedContracts < 99_999 else { return [] }
        let local = TycoonCustomer.allCases.filter { $0.neighborhood == progression.district && isUnlocked($0) }
        let available = local.isEmpty ? TycoonCustomer.allCases.filter { isUnlocked($0) } : local
        guard !available.isEmpty else { return [] }
        let count = progression.completedContracts
        return (0..<3).map { slot in
            let customer = available[(count + slot) % available.count]
            let kind: ContractKind = slot == 0 ? .supply : (slot == 2 && stage == .hub ? .landmark : .premium)
            return makeContract(customer: customer, kind: kind, slot: slot, completed: count)
        }
    }
    func makeContract(customer: TycoonCustomer, kind: ContractKind, slot: Int, completed: Int) -> TycoonContract {
        let tier = min(20, completed / 3)
        let target = switch kind {
        case .supply: 8 + completed % 9
        case .premium: (slot == 2 ? 4 : 3) + completed % 3
        case .landmark: 8
        }
        let factor = switch kind { case .supply: 2; case .premium: 4; case .landmark: 8 }
        let reward = customer.basePay * target * factor * (100 + 10 * tier) / 100
        let action = switch kind {
        case .supply: "Restock"
        case .premium: slot == 2 ? "Gift collection for" : "Special delivery for"
        case .landmark: "New location for"
        }
        return TycoonContract(id: completed * 3 + slot + 1, customer: customer, kind: kind,
                              title: "\(action) \(customer.title)", target: target, reward: reward)
    }
    public func canAcceptContract(_ contract: TycoonContract) -> Bool {
        isValid && progression.activeContract == nil && progression.lifetimeContracts < 1_000_000
            && contractOffers.contains(contract) && cash <= TycoonLimits.money - contract.reward - pendingStaffCash
            && totalEarned <= TycoonLimits.money - contract.reward - pendingStaffCash
    }
    @discardableResult public mutating func acceptContract(_ contract: TycoonContract) -> Bool {
        guard canAcceptContract(contract) else { return false }
        progression.activeContract = contract
        return true
    }

    public func equipmentMilestoneTitle(_ upgrade: DepotUpgrade) -> String {
        let identities = switch upgrade {
        case .workbench: ["Packing desk", "Twin packing bench", "Precision workstation", "Packing studio", "Master packing floor"]
        case .shelves: ["Stock shelves", "Stockroom racks", "Inventory wall", "High bay storage", "Smart stockroom"]
        case .van: ["Delivery van", "Delivery fleet", "City fleet", "Regional fleet", "Flagship fleet"]
        case .labels: ["Label printer", "Batch label printer", "Smart labeling", "Print station", "Precision labeling"]
        case .conveyor: ["Conveyor", "Two lane conveyor", "Sorting conveyor", "Sorting machine", "Automated sorting floor"]
        case .dispatchDesk: ["Dispatch desk", "Dispatch station", "Route planning desk", "Dispatch center", "Logistics command"]
        }
        return identities[milestoneCount(upgrade)]
    }
    public func nextEquipmentMilestone(_ upgrade: DepotUpgrade) -> Int? { [5, 10, 20, 30].first { $0 > level(upgrade) } }
    public func equipmentMilestoneDetail(_ upgrade: DepotUpgrade) -> String {
        let bonus = milestoneCount(upgrade) * 10
        return switch upgrade {
        case .workbench, .shelves, .labels: "Milestone bonus: +\(bonus)% manual packing pay."
        case .conveyor: "Milestone bonus: +\(bonus)% crew speed."
        case .dispatchDesk: "Milestone bonus: +\(bonus)% crew pay."
        case .van: "Milestone bonus: +\(bonus)% shipment pay."
        }
    }
    func milestoneCount(_ upgrade: DepotUpgrade) -> Int { [5, 10, 20, 30].filter { level(upgrade) >= $0 }.count }

    public func canVisit(_ neighborhood: Neighborhood) -> Bool { isValid && (neighborhood == .oldTown || progression.branches[neighborhood] != nil) }
    @discardableResult public mutating func visit(_ neighborhood: Neighborhood) -> Bool {
        guard canVisit(neighborhood) else { return false }
        progression.district = neighborhood; return true
    }
    public func branchCost(_ neighborhood: Neighborhood) -> Int? {
        guard neighborhood != .oldTown else { return nil }
        if let branch = progression.branches[neighborhood] {
            guard branch.isValid, branch.level < TycoonBranch.maxLevel else { return nil }
            return neighborhood.openingPrice * (branch.level + 1)
        }
        return neighborhood.openingPrice
    }
    public func canOpenBranch(_ neighborhood: Neighborhood) -> Bool {
        guard isValid, stage == .hub, neighborhood != .oldTown, progression.branches[neighborhood] == nil,
              progression.franchises >= neighborhood.requiredFranchises, let cost = branchCost(neighborhood) else { return false }
        return cash >= cost
    }
    @discardableResult public mutating func openBranch(_ neighborhood: Neighborhood) -> Bool {
        guard canOpenBranch(neighborhood), let cost = branchCost(neighborhood) else { return false }
        cash -= cost; progression.branches[neighborhood] = TycoonBranch(); return true
    }
    public func branchPayout(_ neighborhood: Neighborhood) -> Int {
        guard let branch = progression.branches[neighborhood], branch.isValid else { return 0 }
        return neighborhood.baseBranchPay * branch.level * (100 + 5 * franchiseUpgradeLevel(.training)) / 100
    }
    public func canUpgradeBranch(_ neighborhood: Neighborhood) -> Bool {
        guard isValid, progression.branches[neighborhood] != nil, let cost = branchCost(neighborhood) else { return false }
        return cash >= cost
    }
    @discardableResult public mutating func upgradeBranch(_ neighborhood: Neighborhood) -> Bool {
        guard canUpgradeBranch(neighborhood), let cost = branchCost(neighborhood) else { return false }
        cash -= cost; progression.branches[neighborhood]?.level += 1; return true
    }
    public func canSetSpecialty(_ specialty: CrewSpecialty, for customer: TycoonCustomer) -> Bool { isValid && teams[customer]?.hasManager == true }
    @discardableResult public mutating func setSpecialty(_ specialty: CrewSpecialty, for customer: TycoonCustomer) -> Bool {
        guard canSetSpecialty(specialty, for: customer) else { return false }
        teams[customer]?.specialty = specialty; return true
    }

    public var franchiseReward: Int {
        guard (0...TycoonLimits.money).contains(totalEarned), (0...99_999).contains(progression.majorContracts) else { return 0 }
        return 3 + Int(Double(totalEarned / 10_000).squareRoot()) + 2 * progression.majorContracts
    }
    public var canFranchise: Bool {
        isValid && stage == .hub && progression.majorContracts > 0 && progression.franchises < 1_000
            && progression.earnedStars <= 1_000_000 - franchiseReward
    }
    public var franchiseRequirement: String {
        if stage != .hub { return "Reach Shipping hub to franchise." }
        if progression.majorContracts == 0 { return "Complete a landmark contract to franchise." }
        return canFranchise ? "Ready to franchise for \(franchiseReward) stars." : "Your franchise record has reached its limit."
    }
    public var nextFranchiseStarTarget: Int? {
        guard (0...TycoonLimits.money).contains(totalEarned) else { return nil }
        let next = Int(Double(totalEarned / 10_000).squareRoot()) + 1
        let target = next * next * 10_000
        return target <= TycoonLimits.money ? target : nil
    }
    @discardableResult public mutating func franchise() -> Bool {
        guard canFranchise else { return false }
        var permanent = progression
        permanent.franchises += 1; permanent.stars += franchiseReward; permanent.earnedStars += franchiseReward
        permanent.activeContract = nil; permanent.lastContract = nil; permanent.completedContracts = 0; permanent.majorContracts = 0
        permanent.manualBoostOrders = 0; permanent.branches = [:]; permanent.district = .oldTown
        var random = SeededRandom(state: seed ^ UInt64(permanent.franchises) &* 0xD6E8FEB86659FD93)
        var next = TycoonAccount(seed: random.next())
        next.progression = permanent
        let starterLevel = permanent.headOffice[.establishedBusiness] ?? 0
        next.cash = 250 * starterLevel; next.totalEarned = next.cash
        if starterLevel > 0 { next.teams[.cornerMarket] = TycoonTeam(workers: 1) }
        guard next.isValid else { return false }
        self = next; return true
    }
    public func franchiseUpgradeCost(_ upgrade: FranchiseUpgrade) -> Int? {
        let level = franchiseUpgradeLevel(upgrade)
        return (0..<FranchiseUpgrade.maxLevel).contains(level) ? level + 1 : nil
    }
    public func canBuyFranchiseUpgrade(_ upgrade: FranchiseUpgrade) -> Bool {
        guard isValid, progression.franchises > 0, let cost = franchiseUpgradeCost(upgrade) else { return false }
        return progression.stars >= cost
    }
    @discardableResult public mutating func buyFranchiseUpgrade(_ upgrade: FranchiseUpgrade) -> Bool {
        guard canBuyFranchiseUpgrade(upgrade), let cost = franchiseUpgradeCost(upgrade) else { return false }
        progression.stars -= cost; progression.headOffice[upgrade] = franchiseUpgradeLevel(upgrade) + 1; return true
    }

    var pendingStaffCash: Int { teams.values.reduce(0) { $0 + $1.pendingCash } }
    var contractReserve: Int { progression.activeContract?.reward ?? 0 }
    mutating func recordEarnings(_ amount: Int, manual: Int = 0, automated: Int = 0) {
        cash += amount; totalEarned += amount
        progression.lifetimeEarned = min(1_000_000_000_000, progression.lifetimeEarned + amount)
        progression.lifetimeManualOrders = min(1_000_000_000_000, progression.lifetimeManualOrders + manual)
        progression.lifetimeAutomatedOrders = min(1_000_000_000_000, progression.lifetimeAutomatedOrders + automated)
    }
    mutating func addRelationship(_ amount: Int, for customer: TycoonCustomer) {
        progression.relationships[customer] = min(1_000_000, relationshipXP(for: customer) + amount)
    }
    @discardableResult mutating func progressContract(customer: TycoonCustomer, manual: Bool, count: Int = 1) -> Int {
        guard var contract = progression.activeContract, contract.customer == customer,
              contract.kind == .supply || manual else { return 0 }
        contract.progress = min(contract.target, contract.progress + count)
        guard contract.isComplete else { progression.activeContract = contract; return 0 }
        // Acceptance reserves this exact reward, so completion and payment are one mutation.
        progression.activeContract = nil; progression.lastContract = contract
        progression.completedContracts += 1; progression.lifetimeContracts += 1
        if contract.kind == .landmark { progression.majorContracts += 1 }
        if contract.kind == .premium {
            progression.manualBoostOrders = min(120, progression.manualBoostOrders + 12)
            progression.blueprints = min(10, progression.blueprints + 1)
        }
        recordEarnings(contract.reward)
        return contract.reward
    }
}
