import Foundation
import Testing
@testable import ParcelCore

@Suite struct TycoonStaffTests {
    private func funded(seed: UInt64 = 12) -> TycoonAccount {
        var account = TycoonAccount(seed: seed)
        account.cash = 10_000_000
        account.totalEarned = 10_000_000
        account.completedOrders = 1_000
        account.stage = .hub
        let previous = TycoonOrder.generate(accountSeed: seed, sequence: 1_000, choice: 0, customer: .makerCollective)
        account.lastDelivery = ShipmentReceipt(order: previous, payout: 900, cleanBonus: 150)
        return account
    }

    private func complete(_ order: TycoonOrder) -> TycoonSession {
        var session = TycoonSession(order: order)
        for placement in session.state.puzzle.solution { _ = session.state.place(placement) }
        return session
    }

    @Test func hiringHasSafeCostsCapsAndCustomerUnlocks() throws {
        var empty = TycoonAccount(seed: 1)
        #expect(empty.workerCost(for: .cornerMarket) == 540)
        #expect(!empty.canHireWorker(for: .cornerMarket))
        #expect(!empty.canHireWorker(for: .plantShop))
        #expect({ !empty.hireWorker(for: .cornerMarket) }())
        var account = funded()
        let initial = account.cash
        for level in 0..<20 {
            let cost = try #require(account.workerCost(for: .cornerMarket))
            #expect(cost == 540 * (100 + 25 * level) / 100)
            #expect({ account.hireWorker(for: .cornerMarket) }())
            #expect(account.teams[.cornerMarket]?.workers == level + 1)
        }
        #expect(account.cash < initial)
        #expect(account.workerCost(for: .cornerMarket) == nil)
        #expect(!account.canHireWorker(for: .cornerMarket))
        #expect(account.workerCost(for: .makerCollective) == nil)
        #expect(!account.canHireManager(for: .makerCollective))
        #expect(!account.canHireManager(for: .bookshop))
        #expect(account.isValid)
    }

    @Test func allWorkersContinuouslyShipWithoutAStorageOrCollectionBottleneck() throws {
        var account = funded()
        #expect({ account.hireWorker(for: .cornerMarket) }())
        let cash = account.cash
        let manual = account.completedOrders
        let interval = account.workerInterval(for: .cornerMarket)
        let pay = account.workerPayout(for: .cornerMarket)
        #expect(interval == 120)
        #expect(pay == 45)
        var reference = account
        var expected = 0
        for _ in 0..<100 { expected += reference.advanceStaff(by: interval).earned }
        let first = account.advanceStaff(by: interval * 100)
        #expect(first.packedOrders == 100)
        #expect(first.earned == expected)
        #expect(account.teams[.cornerMarket]?.pendingOrders == 0)
        #expect(account.teams[.cornerMarket]?.pendingCash == 0)
        #expect(account.cash == cash + first.earned)
        #expect(account.automatedOrders == 100)
        #expect(account.completedOrders == manual)
        #expect({ account.collectStaff(for: .cornerMarket) == 0 }())
        #expect({ account.advanceStaff(by: interval).packedOrders == 1 }())
        #expect(account.automatedOrders == 101)
        #expect(account.isValid)
    }

    @Test func managerCollectsExistingWorkAndAutomaticallyShipsFutureOrders() throws {
        var account = funded()
        #expect({ account.hireWorker(for: .bookshop) }())
        let pay = account.workerPayout(for: .bookshop)
        account.teams[.bookshop]?.pendingCash = pay * 2
        account.teams[.bookshop]?.pendingOrders = 2
        let cost = try #require(account.managerCost(for: .bookshop))
        let cash = account.cash
        #expect({ account.hireManager(for: .bookshop) }())
        #expect(account.cash == cash - cost + 2 * pay)
        #expect(account.teams[.bookshop]?.hasManager == true)
        #expect(account.teams[.bookshop]?.pendingOrders == 0)
        #expect(account.automatedOrders == 2)
        let interval = account.workerInterval(for: .bookshop)
        let managerPay = account.workerPayout(for: .bookshop)
        #expect(interval == 96)
        #expect(managerPay == pay * 125 / 100)
        let report = account.advanceStaff(by: interval * 5)
        #expect(report.packedOrders == 5)
        #expect(report.earned == managerPay * 5)
        #expect(account.automatedOrders == 7)
        #expect(account.managerCost(for: .bookshop) == nil)
        #expect({ !account.hireManager(for: .bookshop) }())
        #expect(account.isValid)
    }

    @Test func fractionalProgressPersistsAndCatchupIsCappedAtEightHours() {
        var account = funded()
        #expect({ account.hireWorker(for: .cornerMarket) }())
        #expect({ account.advanceStaff(by: 119).isEmpty }())
        #expect(account.teams[.cornerMarket]?.progressSeconds == 119)
        let one = account.advanceStaff(by: 1)
        #expect(one.packedOrders == 1)
        #expect(account.teams[.cornerMarket]?.progressSeconds == 0)
        let before = account.automatedOrders
        let capped = account.advanceStaff(by: 60 * 60 * 24 * 365)
        #expect(capped.packedOrders == 240)
        #expect(account.automatedOrders == before + 240)
        #expect({ account.advanceStaff(by: 0).isEmpty }())
    }

    @Test func equipmentImprovesBothKindsOfPayoutAndWorkerSpeed() throws {
        var account = funded()
        #expect({ account.hireWorker(for: .cornerMarket) }())
        let session = complete(try #require(account.offers.first))
        let before = account.payout(for: session)
        account.levels[.labels] = 1
        #expect(account.payout(for: session) == before + 6)
        #expect(account.workerPayout(for: .cornerMarket) == 48)
        account.levels[.workbench] = 1
        account.levels[.shelves] = 1
        account.levels[.van] = 1
        account.levels[.dispatchDesk] = 1
        #expect(account.workerPayout(for: .cornerMarket) == 108 * 110 * 105 / 20_000)
        let originalInterval = account.workerInterval(for: .cornerMarket)
        account.levels[.conveyor] = 1
        #expect(account.workerInterval(for: .cornerMarket) < originalInterval)
        #expect({ account.hireWorker(for: .cornerMarket) }())
        #expect(account.workerInterval(for: .cornerMarket) == 120 / 1.15 / 1.05)
    }

    @Test func automationDoesNotChangeTheAcceptedManualOrderOrReceipt() throws {
        var account = funded()
        let accepted = complete(try #require(account.offers.first))
        let receipt = account.lastDelivery
        #expect({ account.hireWorker(for: .cornerMarket) }())
        #expect({ account.hireManager(for: .cornerMarket) }())
        _ = account.advanceStaff(by: 3_600)
        #expect(account.completedOrders == 1_000)
        #expect(account.lastDelivery == receipt)
        #expect(account.accepts(accepted.order))
        let delivered = try #require({ account.ship(accepted) }())
        #expect(delivered.order.sequence == 1_001)
        #expect(account.completedOrders == 1_001)
        #expect(account.automatedOrders == 37)
        #expect(account.isValid)
    }

    @Test func collectedDeliveriesUnlockCustomersAndExpansionWithoutManualShipments() {
        var account = TycoonAccount(seed: 34)
        account.automatedOrders = 7
        account.cash = 650
        account.totalEarned = 650
        #expect(account.isValid)
        #expect(account.deliveryCount == 7)
        #expect(account.isUnlocked(.bookshop))
        let active = account.offers[0]
        #expect(account.canExpand)
        #expect({ account.expand() }())
        #expect(account.isUnlocked(.plantShop))
        #expect(account.accepts(active))
        #expect(account.completedOrders == 0)
        #expect(account.lastDelivery == nil)
    }

    @Test func nonfiniteElapsedAndCorruptStaffCannotMutateTheBank() {
        var account = funded()
        #expect({ account.hireWorker(for: .cornerMarket) }())
        account.teams[.cornerMarket]?.pendingOrders = 3
        account.teams[.cornerMarket]?.pendingCash = 135
        let saved = account
        for elapsed in [-1.0, .infinity, -.infinity, .nan] {
            #expect({ account.advanceStaff(by: elapsed).isEmpty }())
            #expect(account == saved)
        }
        for workers in [-1, 21, Int.max] {
            account = saved
            account.teams[.cornerMarket]?.workers = workers
            #expect(!account.isValid)
            #expect({ account.advanceStaff(by: 1_000).isEmpty }())
            #expect({ account.collectStaff(for: .cornerMarket) == 0 }())
        }
        account = saved
        account.teams[.cornerMarket]?.progressSeconds = .infinity
        #expect(!account.isValid)
        #expect({ account.advanceStaff(by: 1_000).isEmpty }())
        account = saved
        account.teams[.makerCollective] = TycoonTeam(workers: 1)
        #expect(!account.isValid)
    }

    @Test func productionStopsSafelyAtMoneyAndAutomaticCounterCaps() {
        var account = funded()
        #expect({ account.hireWorker(for: .cornerMarket) }())
        #expect({ account.hireManager(for: .cornerMarket) }())
        account.totalEarned = 1_000_000_000 - 44
        account.cash = account.totalEarned
        let saved = account
        #expect({ account.advanceStaff(by: 1_000).isEmpty }())
        #expect(account.cash == saved.cash)
        #expect(account.automatedOrders == saved.automatedOrders)
        #expect(account.isValid)
        account = funded()
        #expect({ account.hireWorker(for: .cornerMarket) }())
        #expect({ account.hireManager(for: .cornerMarket) }())
        account.automatedOrders = 10_000_000
        account.totalEarned = 500_000_000
        #expect(account.isValid)
        #expect({ account.advanceStaff(by: 28_800).isEmpty }())
        #expect(account.automatedOrders == 10_000_000)
    }

    @Test func continuouslyShippedOrdersStopAtBothBusinessLimits() {
        for limitingMoney in [true, false] {
            var account = funded()
            #expect({ account.hireWorker(for: .cornerMarket) }())
            if limitingMoney {
                account.totalEarned = 1_000_000_000 - 100
                account.cash = account.totalEarned
            } else {
                account.automatedOrders = 10_000_000 - 2
                account.totalEarned = 500_000_000
            }
            let report = account.advanceStaff(by: 28_800)
            #expect(report.packedOrders == 2)
            #expect(account.teams[.cornerMarket]?.pendingCash == 0)
            #expect(report.earned == 90)
            #expect(account.isValid)
            #expect({ account.advanceStaff(by: 28_800).isEmpty }())
            #expect({ account.collectStaff(for: .cornerMarket) == 0 }())
            #expect(account.isValid)
            #expect({ account.advanceStaff(by: 28_800).isEmpty }())
        }
    }

    @Test func alreadyPackedPayIsPreservedWhenEquipmentChanges() {
        var account = funded()
        #expect({ account.hireWorker(for: .cornerMarket) }())
        account.teams[.cornerMarket]?.pendingOrders = 1
        account.teams[.cornerMarket]?.pendingCash = 45
        #expect(account.teams[.cornerMarket]?.pendingCash == 45)
        #expect({ account.buy(.labels) }())
        #expect(account.workerPayout(for: .cornerMarket) == 48)
        #expect(account.teams[.cornerMarket]?.pendingCash == 45)
        let report = account.advanceStaff(by: 120)
        #expect(report.earned == 93)
        #expect(report.packedOrders == 2)
        #expect(account.teams[.cornerMarket]?.pendingCash == 0)
        #expect({ account.collectStaff(for: .cornerMarket) == 0 }())
        #expect(account.automatedOrders == 2)
    }

    @Test func staffAndPendingIncomeRoundTripWithTheBusiness() throws {
        var account = funded()
        #expect({ account.hireWorker(for: .artStudio) }())
        _ = account.advanceStaff(by: 121)
        let restored = try JSONDecoder().decode(TycoonAccount.self, from: JSONEncoder().encode(account))
        #expect(restored == account)
        #expect(restored.isValid)
        #expect(restored.teams[.artStudio]?.pendingOrders == 0)
        #expect(restored.automatedOrders == 1)
        #expect(restored.teams[.artStudio]?.progressSeconds == 1)
    }

    @Test func ownedManagersIncreaseSpeedAndRoundedWorkerPayout() {
        var account = funded()
        account.teams[.cornerMarket] = TycoonTeam(workers: 1)
        let interval = account.workerInterval(for: .cornerMarket)
        let pay = account.workerPayout(for: .cornerMarket)
        account.teams[.cornerMarket]?.hasManager = true
        #expect(account.workerInterval(for: .cornerMarket) == interval / 1.25)
        #expect(account.workerPayout(for: .cornerMarket) == pay * 125 / 100)
        var reference = account
        var expected = 0
        for _ in 0..<300 { expected += reference.advanceStaff(by: 96).earned }
        let report = account.advanceStaff(by: 28_800)
        #expect(report.packedOrders == 300)
        #expect(report.earned == expected)
        #expect(account.isValid)
        for upgrade in DepotUpgrade.allCases { account.levels[upgrade] = DepotUpgrade.maxLevel }
        let maximumPay = account.workerPayout(for: .cornerMarket)
        account.teams[.cornerMarket]?.pendingOrders = 3
        account.teams[.cornerMarket]?.pendingCash = maximumPay * 3
        #expect(account.isValid)
        #expect({ account.settlePendingStaff().earned == maximumPay * 3 }())
    }

    @Test func legacyPendingIsBankedExactlyOnceWithoutElapsedOrManualSequenceChanges() throws {
        var account = funded()
        account.teams[.cornerMarket] = TycoonTeam(workers: 1, pendingCash: 135, pendingOrders: 3)
        account.teams[.bookshop] = TycoonTeam(workers: 1, pendingCash: 124, pendingOrders: 2)
        let cash = account.cash
        let receipt = account.lastDelivery
        let active = try #require(account.offers.first)
        let report = account.settlePendingStaff()
        #expect(report.earned == 259)
        #expect(report.packedOrders == 5)
        #expect(account.cash == cash + 259)
        #expect(account.automatedOrders == 5)
        #expect(account.completedOrders == 1_000)
        #expect(account.lastDelivery == receipt)
        #expect(account.accepts(active))
        #expect({ account.settlePendingStaff().isEmpty }())
        #expect({ account.advanceStaff(by: 0).isEmpty }())
        let next = account.advanceStaff(by: 120)
        #expect(next.earned == 107)
        #expect(next.packedOrders == 2)
        #expect(account.automatedOrders == 7)
        #expect(account.isValid)
    }

    @Test func zeroElapsedFlushesLegacyPendingAndPreservesPartialPackingProgress() {
        var account = funded()
        account.teams[.cornerMarket] = TycoonTeam(workers: 1, pendingCash: 90, pendingOrders: 2, progressSeconds: 75)
        let report = account.advanceStaff(by: 0)
        #expect(report.earned == 90)
        #expect(report.packedOrders == 2)
        #expect(account.teams[.cornerMarket]?.progressSeconds == 75)
        #expect(account.teams[.cornerMarket]?.pendingOrders == 0)
        #expect({ account.advanceStaff(by: 44).isEmpty }())
        #expect({ account.advanceStaff(by: 1).packedOrders == 1 }())
        #expect(account.automatedOrders == 3)
    }
}
