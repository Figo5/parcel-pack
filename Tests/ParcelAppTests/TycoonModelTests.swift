import Foundation
import Testing
@testable import ParcelPackApp
import ParcelCore

@Suite @MainActor struct TycoonModelTests {
    private func defaults() -> (String, UserDefaults) {
        let name = "ParcelTycoonModel.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    private func pack(_ model: TycoonModel) {
        for placement in model.state.puzzle.solution {
            let placed = model.place(parcelID: placement.parcelID, x: placement.origin.x, y: placement.origin.y)
            #expect(placed)
        }
    }

    @Test func shippingPaysOnceAndRelaunchKeepsTheReceipt() {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let model = TycoonModel(defaults: prefs)
        model.ship()
        #expect(model.account.cash == 0)
        pack(model)
        let payout = model.projectedPayout
        #expect(model.account.cash == 0)
        model.ship()
        #expect(model.account.cash == payout)
        #expect(model.account.completedOrders == 1)
        #expect(model.isShipped)
        model.ship()
        model.undo()
        #expect(model.account.cash == payout)
        #expect(model.state.isComplete)
        let restored = TycoonModel(defaults: prefs)
        #expect(restored.account == model.account)
        #expect(restored.receipt == model.receipt)
        restored.ship()
        #expect(restored.account.completedOrders == 1)
        restored.nextOrder()
        #expect(!restored.isShipped)
        #expect(restored.order.sequence == 2)
        #expect(restored.state.placements.isEmpty)
    }

    @Test func partialPackingAndFreeHintsSurviveRelaunch() {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let model = TycoonModel(defaults: prefs)
        let before = model.account
        model.hint()
        #expect(model.account == before)
        #expect(model.session.hintsUsed == 1)
        #expect(!model.cleanBonusAvailable)
        #expect(model.state.placements.first?.rotation == 0)
        let restored = TycoonModel(defaults: prefs)
        #expect(restored.session == model.session)
        #expect(restored.account == model.account)
    }

    @Test func changingAPartialOrderRequiresConfirmationAndCannotChangeTheBank() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let model = TycoonModel(defaults: prefs)
        model.hint()
        let previous = model.session
        let bank = model.account
        let other = try #require(model.offeredOrders.first(where: { $0 != model.order }))
        model.requestOrder(other)
        #expect(model.pendingOrder == other)
        #expect(model.session == previous)
        model.cancelOrderChange()
        #expect(model.pendingOrder == nil)
        #expect(model.session == previous)
        model.requestOrder(other)
        model.confirmOrderChange()
        #expect(model.order == other)
        #expect(model.state.placements.isEmpty)
        #expect(model.account == bank)
    }

    @Test func buyingEquipmentKeepsAnActiveOrderAndItsPaidReceipt() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let model = TycoonModel(defaults: prefs)
        for index in 0..<4 {
            pack(model)
            model.ship()
            if index < 3 { model.nextOrder() }
        }
        let receipt = try #require(model.receipt)
        let cash = model.account.cash
        let cost = try #require(model.account.upgradeCost(.workbench))
        #expect(cash >= cost)
        model.buy(.workbench)
        #expect(model.account.cash == cash - cost)
        #expect(model.receipt == receipt)
        #expect(model.projectedPayout == receipt.payout)
        model.nextOrder()
        let session = model.session
        let before = model.projectedPayout
        model.buy(.shelves)
        #expect(model.session == session)
        #expect(model.projectedPayout >= before)
        let restored = TycoonModel(defaults: prefs)
        #expect(restored.session == model.session)
        #expect(restored.account == model.account)
    }

    @Test func invalidPlacementLeavesTheOrderAndSelectionAlone() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let model = TycoonModel(defaults: prefs)
        let parcel = try #require(model.availableParcels.first)
        model.select(parcel.id)
        let state = model.state
        let placed = model.placeSelected(x: -1, y: -1)
        #expect(!placed)
        #expect(model.state == state)
        #expect(model.selectedID == parcel.id)
    }

    @Test func chosenCustomerPersistsAcrossShippingNextOrderAndRelaunch() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        var business = TycoonAccount(seed: 742)
        for _ in 0..<15 {
            var box = TycoonSession(order: business.offers[0])
            for placement in box.state.puzzle.solution { _ = box.state.place(placement) }
            _ = business.ship(box)
        }
        let expanded = business.expand()
        #expect(expanded)
        let chosen = TycoonOrder.generate(accountSeed: business.seed, sequence: 16, choice: 0, customer: .gadgetShop)
        #expect(TycoonStore(defaults: prefs).save(SavedTycoon(account: business, session: TycoonSession(order: chosen))))
        let model = TycoonModel(defaults: prefs)
        pack(model)
        model.ship()
        model.nextOrder()
        #expect(model.order.customer == .gadgetShop)
        #expect(model.order.sequence == 17)
        let restored = TycoonModel(defaults: prefs)
        pack(restored)
        restored.ship()
        restored.nextOrder()
        #expect(restored.order.customer == .gadgetShop)
        #expect(restored.order.sequence == 18)
    }

    @Test func workerCatchupPersistsOnceAndDoesNotBoostPastWorkWithNewEquipment() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        var business = TycoonAccount(seed: 911)
        for _ in 0..<30 {
            var box = TycoonSession(order: business.offers[0])
            for placement in box.state.puzzle.solution { _ = box.state.place(placement) }
            _ = business.ship(box)
        }
        let worker = business.hireWorker(for: .cornerMarket)
        let manager = business.hireManager(for: .cornerMarket)
        #expect(worker && manager)
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        let active = TycoonSession(order: business.offers[0])
        #expect(TycoonStore(defaults: prefs).save(SavedTycoon(account: business, session: active, staffUpdatedAt: time)))
        let model = TycoonModel(defaults: prefs, now: { time })
        let oldPay = business.workerPayout(for: .cornerMarket)
        let interval = business.workerInterval(for: .cornerMarket)
        let oldCash = business.cash
        let upgradePrice = try #require(business.upgradeCost(.workbench))
        time = time.addingTimeInterval(interval * 2)
        model.buy(.workbench)
        #expect(model.account.cash == oldCash + 2 * oldPay - upgradePrice)
        #expect(model.account.automatedOrders == 2)
        #expect(model.session == active)
        let restored = TycoonModel(defaults: prefs, now: { time })
        #expect(restored.account == model.account)
        restored.refreshStaff()
        #expect(restored.account.automatedOrders == 2)
        time = time.addingTimeInterval(-60)
        restored.refreshStaff()
        #expect(restored.account.automatedOrders == 2)
        time = time.addingTimeInterval(60)
        restored.refreshStaff()
        #expect(restored.account.automatedOrders == 2)
        time = time.addingTimeInterval(60)
        restored.refreshStaff()
        #expect(restored.account.automatedOrders == 2)
        time = time.addingTimeInterval(60)
        restored.refreshStaff()
        #expect(restored.account.automatedOrders == 3)
    }

    @Test func waitingLegacyOrdersAreBankedOnLaunchWithoutAnElapsedTick() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        var business = TycoonAccount(seed: 164)
        for _ in 0..<12 {
            var box = TycoonSession(order: business.offers[0])
            for placement in box.state.puzzle.solution { _ = box.state.place(placement) }
            _ = business.ship(box)
        }
        let hired = business.hireWorker(for: .cornerMarket)
        #expect(hired)
        let oldPay = business.workerPayout(for: .cornerMarket)
        business.teams[.cornerMarket]?.pendingOrders = 2
        business.teams[.cornerMarket]?.pendingCash = 2 * oldPay
        let cash = business.cash
        let receipt = business.lastDelivery
        let active = TycoonSession(order: business.offers[0])
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(TycoonStore(defaults: prefs).save(SavedTycoon(account: business, session: active, staffUpdatedAt: time)))
        let model = TycoonModel(defaults: prefs, now: { time })
        #expect(model.account.cash == cash + 2 * oldPay)
        #expect(model.account.automatedOrders == 2)
        #expect(model.account.teams[.cornerMarket]?.pendingOrders == 0)
        #expect(model.account.lastDelivery == receipt)
        #expect(model.session == active)
        let restored = TycoonModel(defaults: prefs, now: { time })
        #expect(restored.account == model.account)
    }
}
