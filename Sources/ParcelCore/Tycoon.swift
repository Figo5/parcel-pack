import Foundation

public enum DepotStage: Int, CaseIterable, Codable, Sendable {
    case spareRoom, shopfront, depot, warehouse, hub

    public var title: String {
        switch self {
        case .spareRoom: "Spare room"
        case .shopfront: "Shopfront"
        case .depot: "Local depot"
        case .warehouse: "Warehouse"
        case .hub: "Shipping hub"
        }
    }

    public var detail: String {
        switch self {
        case .spareRoom: "One desk, a few boxes, and your first customers."
        case .shopfront: "A proper storefront with room for bigger orders."
        case .depot: "A busy neighborhood depot serving growing businesses."
        case .warehouse: "Long packing benches and a steady stream of shipments."
        case .hub: "Your own shipping hub, trusted with the largest contracts."
        }
    }
}

public enum DepotUpgrade: String, CaseIterable, Codable, Sendable {
    case workbench, shelves, van, labels, conveyor, dispatchDesk
    public static let maxLevel = 30

    public var title: String {
        switch self {
        case .workbench: "Workbench"
        case .shelves: "Storage shelves"
        case .van: "Delivery van"
        case .labels: "Label printer"
        case .conveyor: "Conveyor"
        case .dispatchDesk: "Dispatch desk"
        }
    }

    public var detail: String {
        switch self {
        case .workbench: "Earn $8 more per shipment with each level."
        case .shelves: "Earn $4 more per shipment with each level."
        case .van: "Add 10% to the order and equipment payout with each level."
        case .labels: "Earn $6 more per shipment with each level."
        case .conveyor: "Workers pack 5% faster with each level."
        case .dispatchDesk: "Workers earn 5% more per shipment with each level."
        }
    }
}

public enum TycoonCustomer: String, CaseIterable, Codable, Sendable {
    case cornerMarket, bookshop, plantShop, gadgetShop, homeGoods, artStudio, arcadeWorkshop, makerCollective
    case harborOutfitters, galleryStore, uptownBoutique

    public var title: String {
        switch self {
        case .cornerMarket: "Corner Market"
        case .bookshop: "Chapter & Co."
        case .plantShop: "Little Leaf"
        case .gadgetShop: "Circuit Supply"
        case .homeGoods: "Sunday Home"
        case .artStudio: "Color House"
        case .arcadeWorkshop: "Replay Workshop"
        case .makerCollective: "Maker Collective"
        case .harborOutfitters: "Harbor Outfitters"
        case .galleryStore: "Gallery Store"
        case .uptownBoutique: "Uptown Boutique"
        }
    }

    public var detail: String {
        switch self {
        case .cornerMarket: "Everyday goods for the neighborhood."
        case .bookshop: "Books and stationery for eager readers."
        case .plantShop: "Planters, pots, and gardening supplies."
        case .gadgetShop: "Electronics and carefully boxed accessories."
        case .homeGoods: "Homewares that need a little more space."
        case .artStudio: "Art supplies for the city's creative studios."
        case .arcadeWorkshop: "Parts and collectibles from the arcade workshop."
        case .makerCollective: "Large orders from a whole community of makers."
        case .harborOutfitters: "Outdoor goods and supplies for waterfront adventures."
        case .galleryStore: "Gallery pieces and carefully packed creative collections."
        case .uptownBoutique: "Premium goods bound for the city's finest shops."
        }
    }

    public var size: BoxSize {
        switch self {
        case .cornerMarket, .bookshop: .small
        case .plantShop, .gadgetShop, .homeGoods: .medium
        case .artStudio, .arcadeWorkshop, .makerCollective, .harborOutfitters, .galleryStore, .uptownBoutique: .large
        }
    }

    public var basePay: Int {
        switch self {
        case .cornerMarket: 90
        case .bookshop: 125
        case .plantShop: 175
        case .gadgetShop: 240
        case .homeGoods: 325
        case .artStudio: 410
        case .arcadeWorkshop: 525
        case .makerCollective: 750
        case .harborOutfitters: 900
        case .galleryStore: 1_150
        case .uptownBoutique: 1_400
        }
    }

    public var minStage: DepotStage {
        switch self {
        case .cornerMarket, .bookshop: .spareRoom
        case .plantShop, .gadgetShop: .shopfront
        case .homeGoods, .artStudio: .depot
        case .arcadeWorkshop: .warehouse
        case .makerCollective, .harborOutfitters, .galleryStore, .uptownBoutique: .hub
        }
    }

    public var minDeliveries: Int {
        switch self {
        case .cornerMarket: 0
        case .bookshop: 3
        case .plantShop: 7
        case .gadgetShop: 15
        case .homeGoods: 25
        case .artStudio: 40
        case .arcadeWorkshop: 65
        case .makerCollective: 130
        case .harborOutfitters, .galleryStore, .uptownBoutique: 130
        }
    }

    public var neighborhood: Neighborhood {
        switch self { case .harborOutfitters: .harbor; case .galleryStore: .artsQuarter; case .uptownBoutique: .uptown; default: .oldTown }
    }
}

enum TycoonLimits {
    static let orders = 1_000_000
    static let automatedOrders = 10_000_000
    static let money = 1_000_000_000
    static let expansionCosts = [650, 2_500, 9_000, 25_000]
    static let expansionDeliveries = [7, 25, 65, 130]
}

public struct TycoonOrder: Equatable, Codable, Sendable {
    public let sequence: Int
    public let choice: Int
    public let customer: TycoonCustomer
    public let seed: UInt64

    public init(sequence: Int, choice: Int, customer: TycoonCustomer, seed: UInt64) {
        self.sequence = sequence; self.choice = choice; self.customer = customer; self.seed = seed
    }

    public var puzzle: Puzzle { .generate(seed: seed, size: customer.size, fixedOrientations: true) }
    public var isValid: Bool { (1...TycoonLimits.orders).contains(sequence) && (0..<3).contains(choice) }

    public static func generate(accountSeed: UInt64, sequence: Int, choice: Int, customer: TycoonCustomer) -> TycoonOrder {
        let customerIndex = TycoonCustomer.allCases.firstIndex(of: customer) ?? 0
        var random = SeededRandom(state: accountSeed
            ^ (UInt64(truncatingIfNeeded: sequence) &* 0xD6E8FEB86659FD93)
            ^ (UInt64(truncatingIfNeeded: choice) &* 0xA0761D6478BD642F)
            ^ (UInt64(customerIndex) &* 0xE7037ED1A0B428DB))
        return TycoonOrder(sequence: sequence, choice: choice, customer: customer, seed: random.next())
    }
}

public struct TycoonSession: Equatable, Codable, Sendable {
    public let order: TycoonOrder
    public var state: PackingState
    public var hintsUsed: Int

    public init(order: TycoonOrder) {
        self.order = order; state = PackingState(puzzle: order.puzzle); hintsUsed = 0
    }

    public var isValid: Bool {
        order.isValid && (0...1_000).contains(hintsUsed) && state.isValid
            && state.puzzle == order.puzzle && state.placements.allSatisfy { $0.rotation == 0 }
    }
}

public struct ShipmentReceipt: Equatable, Codable, Sendable {
    public let order: TycoonOrder
    public let payout: Int
    public let cleanBonus: Int

    public init(order: TycoonOrder, payout: Int, cleanBonus: Int) {
        self.order = order; self.payout = payout; self.cleanBonus = cleanBonus
    }

    public var isValid: Bool {
        guard order.isValid, cleanBonus == 0 || cleanBonus == order.customer.basePay / 5 else { return false }
        let maximum = (order.customer.basePay + 18 * DepotUpgrade.maxLevel)
            * (100 + 10 * DepotUpgrade.maxLevel) / 100 * 220 / 100 * 140 / 100
            * 150 / 100 * 120 / 100 * 115 / 100 + cleanBonus
        return (order.customer.basePay + cleanBonus...maximum).contains(payout)
    }
}

public struct TycoonAccount: Equatable, Codable, Sendable {
    public let seed: UInt64
    public var cash: Int
    public var totalEarned: Int
    public var completedOrders: Int
    public var stage: DepotStage
    public var levels: [DepotUpgrade: Int]
    public var lastDelivery: ShipmentReceipt?
    public var teams: [TycoonCustomer: TycoonTeam]
    public var automatedOrders: Int
    public var progression: TycoonProgression

    public init(seed: UInt64) {
        self.seed = seed; cash = 0; totalEarned = 0; completedOrders = 0; stage = .spareRoom
        levels = Dictionary(uniqueKeysWithValues: DepotUpgrade.allCases.map { ($0, 0) })
        lastDelivery = nil
        teams = [:]; automatedOrders = 0
        progression = TycoonProgression()
    }

    private enum CodingKeys: String, CodingKey {
        case seed, cash, totalEarned, completedOrders, stage, levels, lastDelivery, teams, automatedOrders, progression
    }

    private enum LifetimeKeys: String, CodingKey { case lifetimeManualOrders, lifetimeAutomatedOrders, lifetimeEarned }

    public init(from decoder: any Decoder) throws {
        let saved = try decoder.container(keyedBy: CodingKeys.self)
        seed = try saved.decode(UInt64.self, forKey: .seed)
        cash = try saved.decode(Int.self, forKey: .cash)
        totalEarned = try saved.decode(Int.self, forKey: .totalEarned)
        completedOrders = try saved.decode(Int.self, forKey: .completedOrders)
        stage = try saved.decode(DepotStage.self, forKey: .stage)
        levels = try saved.decode([DepotUpgrade: Int].self, forKey: .levels)
        lastDelivery = try saved.decodeIfPresent(ShipmentReceipt.self, forKey: .lastDelivery)
        teams = try saved.decodeIfPresent([TycoonCustomer: TycoonTeam].self, forKey: .teams) ?? [:]
        automatedOrders = try saved.decodeIfPresent(Int.self, forKey: .automatedOrders) ?? 0
        let decoded = try? saved.decodeIfPresent(TycoonProgression.self, forKey: .progression)
        if let decoded, decoded.isValid {
            progression = decoded
            let fields = try? saved.nestedContainer(keyedBy: LifetimeKeys.self, forKey: .progression)
            if fields?.contains(.lifetimeManualOrders) != true { progression.lifetimeManualOrders = max(0, min(completedOrders, 1_000_000_000_000)) }
            if fields?.contains(.lifetimeAutomatedOrders) != true { progression.lifetimeAutomatedOrders = max(0, min(automatedOrders, 1_000_000_000_000)) }
            if fields?.contains(.lifetimeEarned) != true { progression.lifetimeEarned = max(0, min(totalEarned, 1_000_000_000_000)) }
        } else {
            progression = TycoonProgression()
            progression.lifetimeManualOrders = max(0, min(completedOrders, 1_000_000_000_000))
            progression.lifetimeAutomatedOrders = max(0, min(automatedOrders, 1_000_000_000_000))
            progression.lifetimeEarned = max(0, min(totalEarned, 1_000_000_000_000))
        }
        if let contract = progression.activeContract {
            let slot = (max(1, contract.id) - 1) % 3
            let kindMatches = slot == 0 ? contract.kind == .supply
                : (contract.kind == .premium || (slot == 2 && contract.kind == .landmark && stage == .hub))
            let canonical = makeContract(customer: contract.customer, kind: contract.kind, slot: slot,
                                         completed: progression.completedContracts)
            if !isUnlocked(contract.customer) || !kindMatches || contract.id != canonical.id
                || contract.target != canonical.target || contract.reward != canonical.reward || contract.title != canonical.title {
                progression.activeContract = nil
            }
        }
        if progression.branches.count > 0 && stage != .hub { progression.branches = [:]; progression.district = .oldTown }
    }

    public var deliveryCount: Int {
        guard (0..<TycoonLimits.orders).contains(completedOrders),
              (0...TycoonLimits.automatedOrders).contains(automatedOrders) else { return 0 }
        return completedOrders + automatedOrders
    }

    public var isValid: Bool {
        guard (0...TycoonLimits.money).contains(cash), (0...TycoonLimits.money).contains(totalEarned),
              cash <= totalEarned, (0..<TycoonLimits.orders).contains(completedOrders),
              (0...TycoonLimits.automatedOrders).contains(automatedOrders),
              levels.count <= DepotUpgrade.allCases.count,
              levels.values.allSatisfy({ (0...DepotUpgrade.maxLevel).contains($0) }), progression.isValid else { return false }
        if let contract = progression.activeContract {
            guard isUnlocked(contract.customer), contract.id > progression.completedContracts * 3,
                  contract.id <= progression.completedContracts * 3 + 3 else { return false }
            let canonical = makeContract(customer: contract.customer, kind: contract.kind,
                                         slot: (contract.id - 1) % 3, completed: progression.completedContracts)
            let slot = (contract.id - 1) % 3
            let kindMatches = slot == 0 ? contract.kind == .supply
                : (contract.kind == .premium || (slot == 2 && contract.kind == .landmark && stage == .hub))
            guard contract.id == canonical.id, contract.target == canonical.target, contract.reward == canonical.reward,
                  contract.title == canonical.title, kindMatches else { return false }
        }
        guard progression.branches.isEmpty || stage == .hub else { return false }
        if stage != .spareRoom {
            guard deliveryCount >= TycoonLimits.expansionDeliveries[stage.rawValue - 1] else { return false }
        }
        guard teams.count <= TycoonCustomer.automatableCustomers.count,
              teams.allSatisfy({ customer, team in
                  customer.canAutomate && isUnlocked(customer) && team.isValid
                      && (team.pendingOrders == 0 || (team.pendingOrders * (customer.basePay / 2)...team.pendingOrders * Self.maximumWorkerPayout(for: customer)).contains(team.pendingCash))
              }),
              automatedOrders <= TycoonLimits.automatedOrders - teams.values.reduce(0, { $0 + $1.pendingOrders }),
              cash <= TycoonLimits.money - pendingStaffCash - contractReserve,
              totalEarned <= TycoonLimits.money - pendingStaffCash - contractReserve,
              totalEarned >= completedOrders * TycoonCustomer.cornerMarket.basePay + automatedOrders * (TycoonCustomer.cornerMarket.basePay / 2) else { return false }
        guard deliveryCount > 0 else {
            if progression.franchises > 0 {
                return totalEarned <= 1_250 && lastDelivery == nil && stage == .spareRoom
            }
            return cash == 0 && totalEarned == 0 && lastDelivery == nil
                && levels.values.allSatisfy { $0 == 0 } && teams.values.allSatisfy { $0.workers == 0 }
        }
        guard completedOrders > 0 else { return lastDelivery == nil }
        guard let receipt = lastDelivery, receipt.isValid,
              receipt.order.sequence == completedOrders,
              receipt.order == canonical(receipt.order), isUnlocked(receipt.order.customer),
              totalEarned >= receipt.payout else { return false }
        return true
    }

    public func isUnlocked(_ customer: TycoonCustomer) -> Bool {
        stage.rawValue >= customer.minStage.rawValue && deliveryCount >= customer.minDeliveries
            && (customer.neighborhood == .oldTown || progression.branches[customer.neighborhood] != nil)
    }

    public var offers: [TycoonOrder] {
        guard isValid else { return [] }
        let local = TycoonCustomer.allCases.filter { isUnlocked($0) && $0.neighborhood == progression.district }
        let unlocked = local.isEmpty ? TycoonCustomer.allCases.filter { isUnlocked($0) } : local
        guard let highest = unlocked.last else { return [] }
        var random = SeededRandom(state: seed ^ (UInt64(completedOrders) &* 0x8EBC6AF09C88C6E3))
        let clients = [unlocked[0], unlocked[random.index(unlocked.count)], highest]
        return clients.enumerated().map { choice, customer in
            .generate(accountSeed: seed, sequence: completedOrders + 1, choice: choice, customer: customer)
        }
    }

    public func level(_ upgrade: DepotUpgrade) -> Int { levels[upgrade] ?? 0 }

    public func upgradeCost(_ upgrade: DepotUpgrade) -> Int? {
        let current = level(upgrade)
        guard (0..<DepotUpgrade.maxLevel).contains(current) else { return nil }
        let base = switch upgrade {
        case .workbench: 120
        case .shelves: 160
        case .van: 350
        case .labels: 140
        case .conveyor: 225
        case .dispatchDesk: 275
        }
        return base * (current + 1) * (current + 1) * (100 - 5 * franchiseUpgradeLevel(.buyingPower)) / 100
    }

    public func canBuy(_ upgrade: DepotUpgrade) -> Bool {
        guard isValid, let cost = upgradeCost(upgrade) else { return false }
        return cash >= cost
    }

    @discardableResult public mutating func buy(_ upgrade: DepotUpgrade) -> Bool {
        guard canBuy(upgrade), let cost = upgradeCost(upgrade) else { return false }
        cash -= cost; levels[upgrade] = level(upgrade) + 1
        return true
    }

    public var nextExpansionCost: Int? {
        stage == .hub ? nil : TycoonLimits.expansionCosts[stage.rawValue]
    }

    public var nextExpansionDeliveries: Int? {
        stage == .hub ? nil : TycoonLimits.expansionDeliveries[stage.rawValue]
    }

    public var canExpand: Bool {
        guard isValid, let cost = nextExpansionCost, let deliveries = nextExpansionDeliveries else { return false }
        return cash >= cost && deliveryCount >= deliveries
    }

    @discardableResult public mutating func expand() -> Bool {
        guard canExpand, let cost = nextExpansionCost, let next = DepotStage(rawValue: stage.rawValue + 1) else { return false }
        cash -= cost; stage = next
        return true
    }

    public func accepts(_ order: TycoonOrder) -> Bool {
        isValid && order.isValid && order.sequence == completedOrders + 1
            && isUnlocked(order.customer) && order == canonical(order)
    }

    public func payout(for session: TycoonSession) -> Int {
        guard accepts(session.order), session.isValid else { return 0 }
        let base = session.order.customer.basePay
        let equipmentPay = base + 8 * level(.workbench) + 4 * level(.shelves) + 6 * level(.labels)
        var pay = equipmentPay * (100 + 10 * level(.van)) / 100
        pay = pay * (100 + 10 * (milestoneCount(.workbench) + milestoneCount(.shelves) + milestoneCount(.labels))) / 100
        pay = pay * (100 + 10 * milestoneCount(.van)) / 100
        pay = pay * (100 + 10 * franchiseUpgradeLevel(.premiumService)) / 100
        pay = pay * (100 + 2 * progression.blueprints) / 100
        pay = pay * (100 + 3 * relationshipLevel(for: session.order.customer)) / 100
        return pay + (session.hintsUsed == 0 ? base / 5 : 0)
    }

    @discardableResult public mutating func ship(_ session: TycoonSession) -> ShipmentReceipt? {
        guard accepts(session.order), session.isValid, session.state.isComplete,
              completedOrders < TycoonLimits.orders - 1 else { return nil }
        let earned = payout(for: session)
        let reserved = pendingStaffCash + contractReserve
        guard earned > 0, cash <= TycoonLimits.money - earned - reserved,
              totalEarned <= TycoonLimits.money - earned - reserved else { return nil }
        let receipt = ShipmentReceipt(order: session.order, payout: earned,
                                      cleanBonus: session.hintsUsed == 0 ? session.order.customer.basePay / 5 : 0)
        recordEarnings(earned, manual: 1); completedOrders += 1; lastDelivery = receipt
        addRelationship(3, for: session.order.customer)
        progression.manualBoostOrders = min(120, progression.manualBoostOrders + 2)
        _ = progressContract(customer: session.order.customer, manual: true)
        return receipt
    }

    private func canonical(_ order: TycoonOrder) -> TycoonOrder {
        .generate(accountSeed: seed, sequence: order.sequence, choice: order.choice, customer: order.customer)
    }
}
