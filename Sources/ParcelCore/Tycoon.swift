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
    case workbench, shelves, van
    public static let maxLevel = 12

    public var title: String {
        switch self { case .workbench: "Workbench"; case .shelves: "Storage shelves"; case .van: "Delivery van" }
    }

    public var detail: String {
        switch self {
        case .workbench: "Earn $8 more per shipment with each level."
        case .shelves: "Earn $4 more per shipment with each level."
        case .van: "Add 10% to the order and equipment payout with each level."
        }
    }
}

public enum TycoonCustomer: String, CaseIterable, Codable, Sendable {
    case cornerMarket, bookshop, plantShop, gadgetShop, homeGoods, artStudio, arcadeWorkshop, makerCollective

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
        }
    }

    public var size: BoxSize {
        switch self {
        case .cornerMarket, .bookshop: .small
        case .plantShop, .gadgetShop, .homeGoods: .medium
        case .artStudio, .arcadeWorkshop, .makerCollective: .large
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
        }
    }

    public var minStage: DepotStage {
        switch self {
        case .cornerMarket, .bookshop: .spareRoom
        case .plantShop, .gadgetShop: .shopfront
        case .homeGoods, .artStudio: .depot
        case .arcadeWorkshop: .warehouse
        case .makerCollective: .hub
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
        }
    }
}

private enum TycoonLimits {
    static let orders = 1_000_000
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
        let maximum = (order.customer.basePay + 12 * DepotUpgrade.maxLevel)
            * (100 + 10 * DepotUpgrade.maxLevel) / 100 + cleanBonus
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

    public init(seed: UInt64) {
        self.seed = seed; cash = 0; totalEarned = 0; completedOrders = 0; stage = .spareRoom
        levels = Dictionary(uniqueKeysWithValues: DepotUpgrade.allCases.map { ($0, 0) })
        lastDelivery = nil
    }

    public var isValid: Bool {
        guard (0...TycoonLimits.money).contains(cash), (0...TycoonLimits.money).contains(totalEarned),
              cash <= totalEarned, (0..<TycoonLimits.orders).contains(completedOrders),
              levels.count <= DepotUpgrade.allCases.count,
              levels.values.allSatisfy({ (0...DepotUpgrade.maxLevel).contains($0) }) else { return false }
        if stage != .spareRoom {
            guard completedOrders >= TycoonLimits.expansionDeliveries[stage.rawValue - 1] else { return false }
        }
        guard completedOrders > 0 else {
            return cash == 0 && totalEarned == 0 && lastDelivery == nil && levels.values.allSatisfy { $0 == 0 }
        }
        guard let receipt = lastDelivery, receipt.isValid,
              receipt.order.sequence == completedOrders,
              receipt.order == canonical(receipt.order), isUnlocked(receipt.order.customer),
              totalEarned >= completedOrders * TycoonCustomer.cornerMarket.basePay,
              totalEarned >= receipt.payout else { return false }
        return true
    }

    public func isUnlocked(_ customer: TycoonCustomer) -> Bool {
        stage.rawValue >= customer.minStage.rawValue && completedOrders >= customer.minDeliveries
    }

    public var offers: [TycoonOrder] {
        guard isValid else { return [] }
        let unlocked = TycoonCustomer.allCases.filter { isUnlocked($0) }
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
        let base = switch upgrade { case .workbench: 120; case .shelves: 160; case .van: 350 }
        return base * (current + 1) * (current + 1)
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
        return cash >= cost && completedOrders >= deliveries
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
        let equipmentPay = base + 8 * level(.workbench) + 4 * level(.shelves)
        return equipmentPay * (100 + 10 * level(.van)) / 100 + (session.hintsUsed == 0 ? base / 5 : 0)
    }

    @discardableResult public mutating func ship(_ session: TycoonSession) -> ShipmentReceipt? {
        guard accepts(session.order), session.isValid, session.state.isComplete,
              completedOrders < TycoonLimits.orders - 1 else { return nil }
        let earned = payout(for: session)
        guard earned > 0, cash <= TycoonLimits.money - earned,
              totalEarned <= TycoonLimits.money - earned else { return nil }
        let receipt = ShipmentReceipt(order: session.order, payout: earned,
                                      cleanBonus: session.hintsUsed == 0 ? session.order.customer.basePay / 5 : 0)
        cash += earned; totalEarned += earned; completedOrders += 1; lastDelivery = receipt
        return receipt
    }

    private func canonical(_ order: TycoonOrder) -> TycoonOrder {
        .generate(accountSeed: seed, sequence: order.sequence, choice: order.choice, customer: order.customer)
    }
}
