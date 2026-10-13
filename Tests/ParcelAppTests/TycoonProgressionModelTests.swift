import Foundation
import Testing
@testable import ParcelPackApp
import ParcelCore

@Suite @MainActor struct TycoonProgressionModelTests {
    private func defaults() -> (String, UserDefaults) {
        let name = "ParcelProgressionModel.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    private func pack(_ model: TycoonModel) {
        for placement in model.state.puzzle.solution {
            #expect(model.place(parcelID: placement.parcelID, x: placement.origin.x, y: placement.origin.y))
        }
    }

    private func developedBusiness() -> TycoonAccount {
        var account = TycoonAccount(seed: 9082)
        for _ in 0..<550 {
            let order = TycoonOrder.generate(accountSeed: account.seed, sequence: account.completedOrders + 1,
                                            choice: 0, customer: .cornerMarket)
            var session = TycoonSession(order: order)
            for placement in session.state.puzzle.solution { _ = session.state.place(placement) }
            let mutation1 = account.ship(session) != nil
            #expect(mutation1)
            if account.canExpand { let expanded = account.expand(); #expect(expanded) }
        }
        #expect(account.stage == .hub)
        return account
    }

    @Test func acceptingAContractKeepsThePartialBoxAndSavesTheJob() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let model = TycoonModel(defaults: prefs, now: { time })
        model.hint()
        let partial = model.session
        let contract = try #require(model.account.contractOffers.first)
        model.acceptContract(contract)
        #expect(model.session == partial)
        #expect(model.account.progression.activeContract?.id == contract.id)
        let restored = TycoonModel(defaults: prefs, now: { time })
        #expect(restored.session == partial)
        #expect(restored.account.progression.activeContract == model.account.progression.activeContract)
    }

    @Test func premiumCompletionBanksOnceAndKeepsHistoricalReceipt() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let model = TycoonModel(defaults: prefs, now: { time })
        let contract = try #require(model.account.contractOffers.first { $0.kind == .premium })
        model.acceptContract(contract)
        model.requestCustomer(contract.customer)
        var expectedCash = model.account.cash
        for index in 0..<contract.target {
            pack(model)
            expectedCash += model.projectedPayout
            model.ship()
            if index < contract.target - 1 { model.nextOrder() }
        }
        #expect(model.account.cash == expectedCash + contract.reward)
        #expect(model.account.progression.activeContract == nil)
        #expect(model.account.progression.lastContract?.id == contract.id)
        #expect(model.account.progression.completedContracts == 1)
        #expect(model.account.progression.blueprints == 1)
        let account = model.account
        let receipt = model.receipt
        model.ship()
        #expect(model.account == account)
        let restored = TycoonModel(defaults: prefs, now: { time })
        #expect(restored.account == account)
        #expect(restored.receipt == receipt)
        restored.ship()
        #expect(restored.account == account)
    }

    @Test func franchisePreviewCanBeCancelledWithoutDiscardingTheCurrentBox() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        var business = developedBusiness()
        let landmark = try #require(business.contractOffers.first { $0.kind == .landmark })
        let mutation2 = business.acceptContract(landmark)
        #expect(mutation2)
        for _ in 0..<landmark.target {
            var box = TycoonSession(order: .generate(accountSeed: business.seed, sequence: business.completedOrders + 1,
                                                    choice: 0, customer: landmark.customer))
            for placement in box.state.puzzle.solution { _ = box.state.place(placement) }
            let mutation3 = business.ship(box) != nil
            #expect(mutation3)
        }
        #expect(business.canFranchise)
        let partial = TycoonSession(order: business.offers[0])
        #expect(TycoonStore(defaults: prefs).save(SavedTycoon(account: business, session: partial, staffUpdatedAt: time)))
        let model = TycoonModel(defaults: prefs, now: { time })
        model.hint()
        let before = model.account
        let box = model.session
        model.requestFranchise()
        #expect(model.showFranchiseConfirmation)
        #expect(model.account == before)
        model.cancelFranchise()
        #expect(!model.showFranchiseConfirmation)
        #expect(model.session == box)
        #expect(model.account == before)
    }

    @Test func franchiseCommitsNewBusinessBoxAndClockAsOneSnapshot() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        var business = developedBusiness()
        let landmark = try #require(business.contractOffers.first { $0.kind == .landmark })
        let mutation4 = business.acceptContract(landmark)
        #expect(mutation4)
        for _ in 0..<landmark.target {
            var box = TycoonSession(order: .generate(accountSeed: business.seed, sequence: business.completedOrders + 1,
                                                    choice: 0, customer: landmark.customer))
            for placement in box.state.puzzle.solution { _ = box.state.place(placement) }
            let mutation5 = business.ship(box) != nil
            #expect(mutation5)
        }
        let mutation6 = business.hireWorker(for: .cornerMarket)
        #expect(mutation6)
        let oldBox = TycoonSession(order: business.offers[0])
        #expect(TycoonStore(defaults: prefs).save(SavedTycoon(account: business, session: oldBox, staffUpdatedAt: time)))
        let model = TycoonModel(defaults: prefs, now: { time })
        model.hint()
        model.selectedID = model.availableParcels.first?.id
        time = time.addingTimeInterval(300)
        model.requestFranchise()
        let reward = model.account.franchiseReward
        let trust = model.account.progression.relationships
        model.confirmFranchise()
        #expect(!model.showFranchiseConfirmation)
        #expect(model.account.progression.franchises == 1)
        #expect(model.account.progression.stars == reward)
        #expect(model.account.progression.relationships == trust)
        #expect(model.account.stage == .spareRoom)
        #expect(model.order.customer == .cornerMarket && model.order.sequence == 1)
        #expect(model.state.placements.isEmpty)
        #expect(!model.isShipped && model.receipt == nil)
        #expect(model.selectedID == nil && model.pendingOrder == nil)
        #expect(!model.account.accepts(oldBox.order))
        let reset = model.account
        let resetBox = model.session
        model.confirmFranchise()
        #expect(model.account == reset)
        let restored = TycoonModel(defaults: prefs, now: { time })
        #expect(restored.account == reset && restored.session == resetBox)
        restored.refreshStaff()
        #expect(restored.account == reset)
        restored.buyFranchiseUpgrade(.establishedBusiness)
        #expect(restored.account.franchiseUpgradeLevel(.establishedBusiness) == 1)
        #expect(restored.account.progression.stars == reward - 1)
        #expect(restored.account.cash == reset.cash)
        #expect(restored.session == resetBox)
        let upgraded = TycoonModel(defaults: prefs, now: { time })
        #expect(upgraded.account == restored.account)
        #expect(upgraded.session == resetBox)
    }

    @Test func specialtyChangeSettlesOldWorkBeforeApplyingTheNewRate() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        var business = developedBusiness()
        let mutation7 = business.hireWorker(for: .cornerMarket)
        #expect(mutation7)
        let mutation8 = business.hireManager(for: .cornerMarket)
        #expect(mutation8)
        let oldPay = business.workerPayout(for: .cornerMarket)
        let oldInterval = business.workerInterval(for: .cornerMarket)
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        let session = TycoonSession(order: business.offers[0])
        #expect(TycoonStore(defaults: prefs).save(SavedTycoon(account: business, session: session, staffUpdatedAt: time)))
        let model = TycoonModel(defaults: prefs, now: { time })
        let oldCash = model.account.cash
        time = time.addingTimeInterval(oldInterval)
        model.setSpecialty(.careful, for: .cornerMarket)
        #expect(model.account.cash == oldCash + oldPay)
        #expect(model.account.teams[.cornerMarket]?.specialty == .careful)
        let newPay = model.account.workerPayout(for: .cornerMarket)
        #expect(newPay > oldPay)
        time = time.addingTimeInterval(oldInterval)
        model.refreshStaff()
        #expect(model.account.cash == oldCash + oldPay + newPay)
        #expect(model.session == session)
        let restored = TycoonModel(defaults: prefs, now: { time })
        #expect(restored.account == model.account)
    }

    @Test func branchOnlyBusinessEarnsAndVisitingKeepsTheCurrentBox() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        var business = developedBusiness()
        let landmark = try #require(business.contractOffers.first { $0.kind == .landmark })
        let mutation9 = business.acceptContract(landmark)
        #expect(mutation9)
        for _ in 0..<landmark.target {
            var box = TycoonSession(order: .generate(accountSeed: business.seed, sequence: business.completedOrders + 1,
                                                    choice: 0, customer: landmark.customer))
            for placement in box.state.puzzle.solution { _ = box.state.place(placement) }
            let mutation10 = business.ship(box) != nil
            #expect(mutation10)
        }
        let mutation11 = business.franchise()
        #expect(mutation11)
        for _ in 0..<550 {
            var box = TycoonSession(order: .generate(accountSeed: business.seed, sequence: business.completedOrders + 1,
                                                    choice: 0, customer: .cornerMarket))
            for placement in box.state.puzzle.solution { _ = box.state.place(placement) }
            let mutation12 = business.ship(box) != nil
            #expect(mutation12)
            if business.canExpand { let expanded = business.expand(); #expect(expanded) }
        }
        let mutation13 = business.openBranch(.harbor)
        #expect(mutation13)
        var time = Date(timeIntervalSince1970: 1_800_000_000)
        let session = TycoonSession(order: business.offers[0])
        #expect(TycoonStore(defaults: prefs).save(SavedTycoon(account: business, session: session, staffUpdatedAt: time)))
        let model = TycoonModel(defaults: prefs, now: { time })
        model.hint()
        let partial = model.session
        let oldCash = model.account.cash
        let pay = model.account.branchPayout(.harbor)
        model.visitNeighborhood(.harbor)
        #expect(model.account.progression.district == .harbor)
        #expect(model.session == partial)
        #expect(model.account.teams.isEmpty)
        time = time.addingTimeInterval(60)
        model.refreshStaff()
        #expect(model.account.cash == oldCash + pay)
        #expect(model.account.automatedOrders == 1)
        #expect(model.session == partial)
        let restored = TycoonModel(defaults: prefs, now: { time })
        #expect(restored.account == model.account)
        #expect(restored.session == partial)
    }

    @Test func lockedFranchiseCannotDiscardProgress() {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let model = TycoonModel(defaults: prefs, now: { time })
        model.hint()
        let account = model.account
        let session = model.session
        model.requestFranchise()
        #expect(!model.showFranchiseConfirmation)
        model.confirmFranchise()
        #expect(model.account == account && model.session == session)
    }

    @Test func legacyFreePlaySaveIsUntouchedByTycoonLifecycle() {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let prior = Data("retained historic run".utf8)
        prefs.set(prior, forKey: EndlessStore.key)
        prefs.set("free", forKey: "parcel-pack.mode")
        let model = TycoonModel(defaults: prefs)
        model.hint()
        model.save()
        #expect(prefs.data(forKey: EndlessStore.key) == prior)
    }
}
