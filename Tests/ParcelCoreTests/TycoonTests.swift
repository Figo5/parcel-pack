import Foundation
import Testing
@testable import ParcelCore

@Suite struct TycoonTests {
    private func completed(_ order: TycoonOrder, hints: Int = 0) -> TycoonSession {
        var session = TycoonSession(order: order)
        session.hintsUsed = hints
        for placement in session.state.puzzle.solution { _ = session.state.place(placement) }
        return session
    }

    @Test func everyCustomerProducesDeterministicFixedOrientationOrders() {
        for customer in TycoonCustomer.allCases {
            for sequence in 1...20 {
                let order = TycoonOrder.generate(accountSeed: 42, sequence: sequence, choice: sequence % 3, customer: customer)
                #expect(order == .generate(accountSeed: 42, sequence: sequence, choice: sequence % 3, customer: customer))
                #expect(order.isValid)
                #expect(order.puzzle.size == customer.size)
                #expect(order.puzzle.isFixedOrientation)
                #expect(order.puzzle.solution.allSatisfy { $0.rotation == 0 })
                #expect(completed(order).state.isComplete)
            }
        }
    }

    @Test func aNewDepotHasThreeDistinctOrdersForItsFirstCustomer() {
        let account = TycoonAccount(seed: 123)
        #expect(account.isValid)
        #expect(account.cash == 0)
        #expect(account.stage == .spareRoom)
        #expect(account.offers.count == 3)
        #expect(Set(account.offers.map(\.seed)).count == 3)
        #expect(account.offers.allSatisfy { $0.customer == .cornerMarket && $0.sequence == 1 && account.accepts($0) })
        #expect(!account.isUnlocked(.makerCollective))
        #expect(DepotUpgrade.allCases.allSatisfy { account.level($0) == 0 && !account.canBuy($0) })
    }

    @Test func paymentRequiresCompleteCurrentOrderAndCannotBeCollectedTwice() throws {
        var account = TycoonAccount(seed: 55)
        let order = try #require(account.offers.first)
        let unfinished = TycoonSession(order: order)
        let rejected = account.ship(unfinished)
        #expect(rejected == nil)
        #expect(account.cash == 0)
        let session = completed(order)
        let receipt = try #require({ account.ship(session) }())
        #expect(receipt.payout == 108)
        #expect(receipt.cleanBonus == 18)
        #expect(receipt.isValid)
        #expect(account.cash == receipt.payout)
        #expect(account.totalEarned == receipt.payout)
        #expect(account.completedOrders == 1)
        #expect(account.lastDelivery == receipt)
        let paidAccount = account
        let duplicate = account.ship(session)
        #expect(duplicate == nil)
        #expect(account == paidAccount)
        #expect(account.offers.allSatisfy { $0.sequence == 2 })
    }

    @Test func hintsOnlyRemoveTheCleanBonusAndUndoIsFree() throws {
        let account = TycoonAccount(seed: 99)
        let order = try #require(account.offers.first)
        var clean = completed(order)
        let undo = clean.state.undo()
        #expect(undo)
        let last = try #require(clean.state.hint())
        let replaced = clean.state.place(last)
        #expect(replaced)
        let guided = completed(order, hints: 1)
        #expect(account.payout(for: clean) == 108)
        #expect(account.payout(for: guided) == 90)
    }

    @Test func purchasesSpendOnceRaisePayoutAndNeverOverdraft() throws {
        var account = TycoonAccount(seed: 1)
        let before = account
        let emptyPurchase = account.buy(.workbench)
        #expect(!emptyPurchase)
        #expect(account == before)
        for _ in 0..<4 {
            let session = completed(try #require(account.offers.first))
            #expect({ account.ship(session) != nil }())
        }
        let session = completed(try #require(account.offers.first))
        let oldPayout = account.payout(for: session)
        let price = try #require(account.upgradeCost(.workbench))
        let oldCash = account.cash
        let bought = account.buy(.workbench)
        #expect(bought)
        #expect(account.cash == oldCash - price)
        #expect(account.level(.workbench) == 1)
        #expect(account.payout(for: session) == oldPayout + 8)
        let cannotBuyNext = account.buy(.workbench)
        #expect(!cannotBuyNext)
        #expect(account.cash >= 0)
        #expect(account.totalEarned == oldCash)
        #expect(account.isValid)
    }

    @Test func equipmentCapsAreFiniteAndVanScalesBasePlusEquipment() throws {
        var account = TycoonAccount(seed: 4)
        account.cash = 1_000_000
        account.totalEarned = 1_000_000
        account.completedOrders = 1_000
        account.stage = .hub
        let prior = TycoonOrder.generate(accountSeed: account.seed, sequence: 1_000, choice: 0, customer: .makerCollective)
        account.lastDelivery = ShipmentReceipt(order: prior, payout: 900, cleanBonus: 150)
        for upgrade in DepotUpgrade.allCases {
            for _ in 0..<DepotUpgrade.maxLevel {
                let bought = account.buy(upgrade)
                #expect(bought)
            }
            #expect(account.level(upgrade) == DepotUpgrade.maxLevel)
            #expect(account.upgradeCost(upgrade) == nil)
            #expect(!account.canBuy(upgrade))
            #expect({ !account.buy(upgrade) }())
        }
        let order = try #require(account.offers.first)
        let base = order.customer.basePay + 8 * DepotUpgrade.maxLevel + 4 * DepotUpgrade.maxLevel
        #expect(account.payout(for: completed(order)) == base * 220 / 100 + order.customer.basePay / 5)
    }

    @Test func expandingKeepsTheAlreadyAcceptedOrderValid() throws {
        var account = TycoonAccount(seed: 700)
        for _ in 0..<7 {
            let order = try #require(account.offers.max { $0.customer.basePay < $1.customer.basePay })
            #expect({ account.ship(completed(order)) != nil }())
        }
        let active = completed(try #require(account.offers.first))
        #expect(account.canExpand)
        let expanded = account.expand()
        #expect(expanded)
        #expect(account.stage == .shopfront)
        #expect(account.accepts(active.order))
        #expect({ account.ship(active) != nil }())
        #expect(account.isUnlocked(.plantShop))
        #expect(account.offers.contains { $0.customer == .plantShop })
    }

    @Test func allEightClientsAndLocationsAreReachableWithAndWithoutHints() throws {
        for hints in [0, 1] {
            var account = TycoonAccount(seed: UInt64(hints + 17))
            var clients = Set<TycoonCustomer>()
            var locations: Set<DepotStage> = [account.stage]
            for _ in 0..<250 {
                let order = try #require(account.offers.max { $0.customer.basePay < $1.customer.basePay })
                clients.insert(order.customer)
                #expect({ account.ship(completed(order, hints: hints)) != nil }())
                if account.canExpand {
                    #expect({ account.expand() }())
                    locations.insert(account.stage)
                }
                #expect(account.isValid)
            }
            #expect(locations == Set(DepotStage.allCases))
            #expect(clients == Set(TycoonCustomer.allCases))
            #expect(account.stage == .hub)
            #expect(account.completedOrders == 250)
            #expect(account.nextExpansionCost == nil)
            #expect(account.nextExpansionDeliveries == nil)
            #expect(!account.canExpand)
        }
    }

    @Test func canonicalSeedsRejectForeignForgedAndLockedOrders() throws {
        let account = TycoonAccount(seed: 14)
        let order = try #require(account.offers.first)
        let forged = TycoonOrder(sequence: order.sequence, choice: order.choice, customer: order.customer, seed: order.seed &+ 1)
        let foreign = TycoonOrder.generate(accountSeed: 15, sequence: 1, choice: 0, customer: .cornerMarket)
        let locked = TycoonOrder.generate(accountSeed: 14, sequence: 1, choice: 0, customer: .makerCollective)
        #expect(!account.accepts(forged))
        #expect(!account.accepts(foreign))
        #expect(!account.accepts(locked))
        #expect(!TycoonOrder(sequence: -1, choice: 0, customer: .cornerMarket, seed: 0).isValid)
        #expect(!TycoonOrder(sequence: 0, choice: 0, customer: .cornerMarket, seed: 0).isValid)
        #expect(!TycoonOrder(sequence: 1, choice: 3, customer: .cornerMarket, seed: 0).isValid)
    }

    @Test func invalidSessionsAndCountersAreRejectedBeforePayment() throws {
        var account = TycoonAccount(seed: 13)
        let order = try #require(account.offers.first)
        var session = completed(order)
        session.hintsUsed = -1
        #expect(!session.isValid)
        #expect({ account.ship(session) == nil }())
        session.hintsUsed = 0
        session.state = PackingState(puzzle: .generate(seed: order.seed &+ 1, size: order.customer.size))
        #expect(!session.isValid)
        #expect({ account.ship(session) == nil }())
        let clean = completed(order)
        for counter in [Int.min, -1, Int.max] {
            var corrupt = account
            corrupt.completedOrders = counter
            #expect(!corrupt.isValid)
            #expect(corrupt.offers.isEmpty)
            #expect({ corrupt.ship(clean) == nil }())
            #expect({ !corrupt.buy(.van) }())
            #expect({ !corrupt.expand() }())
        }
        account.cash = Int.max
        account.totalEarned = Int.max
        #expect(!account.isValid)
        #expect({ account.ship(clean) == nil }())
    }

    @Test func decodedDuplicatePlacementsAndRotationsCannotPayOut() throws {
        let account = TycoonAccount(seed: 900)
        let session = completed(try #require(account.offers.first))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        var state = try #require(json["state"] as? [String: Any])
        var placements = try #require(state["placements"] as? [[String: Any]])
        let originalPlacements = placements
        placements[1] = placements[0]
        state["placements"] = placements
        json["state"] = state
        let duplicate = try JSONDecoder().decode(TycoonSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!duplicate.isValid)
        placements = originalPlacements
        placements[0]["rotation"] = 1
        state["placements"] = placements
        json["state"] = state
        let rotated = try JSONDecoder().decode(TycoonSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!rotated.isValid)
    }

    @Test func savesRoundTripAndReceiptSequenceMustMatchDeliveryCount() throws {
        var account = TycoonAccount(seed: 81)
        let session = completed(try #require(account.offers.first))
        #expect({ account.ship(session) != nil }())
        let saved = try JSONEncoder().encode(account)
        let restored = try JSONDecoder().decode(TycoonAccount.self, from: saved)
        #expect(restored == account)
        #expect(restored.isValid)
        account.completedOrders += 1
        #expect(!account.isValid)
        var badLevel = restored
        badLevel.levels[.van] = Int.max
        #expect(!badLevel.isValid)
        #expect(badLevel.upgradeCost(.van) == nil)
    }
}
