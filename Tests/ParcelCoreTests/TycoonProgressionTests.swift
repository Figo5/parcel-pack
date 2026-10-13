import Foundation
import Testing
@testable import ParcelCore

@Suite struct TycoonProgressionTests {
    private func funded() -> TycoonAccount {
        var account = TycoonAccount(seed: 802)
        account.cash = 1_000_000; account.totalEarned = 1_000_000
        account.completedOrders = 1_000; account.stage = .hub
        let prior = TycoonOrder.generate(accountSeed: account.seed, sequence: 1_000, choice: 0, customer: .makerCollective)
        account.lastDelivery = ShipmentReceipt(order: prior, payout: 900, cleanBonus: 150)
        return account
    }
    private func box(_ account: TycoonAccount, customer: TycoonCustomer) -> TycoonSession {
        let order = TycoonOrder.generate(accountSeed: account.seed, sequence: account.completedOrders + 1, choice: 0, customer: customer)
        var session = TycoonSession(order: order)
        for placement in order.puzzle.solution { _ = session.state.place(placement) }
        return session
    }
    private func finish(_ account: inout TycoonAccount, contract: TycoonContract) {
        #expect({ account.acceptContract(contract) }())
        for _ in 0..<contract.target { #expect({ account.ship(box(account, customer: contract.customer)) != nil }()) }
    }

    @Test func contractOffersAreDeterministicAndForgedOffersCannotReserveTheBank() throws {
        var account = funded()
        #expect(account.contractOffers == funded().contractOffers)
        #expect(account.contractOffers.count == 3)
        #expect(Set(account.contractOffers.map(\.id)).count == 3)
        let supply = try #require(account.contractOffers.first)
        #expect(supply.kind == .supply)
        let fake = TycoonContract(id: supply.id, customer: supply.customer, kind: supply.kind, title: supply.title,
                                  target: supply.target, reward: supply.reward + 1)
        #expect({ !account.acceptContract(fake) }())
        #expect({ account.acceptContract(supply) }())
        #expect({ !account.acceptContract(supply) }())
        #expect(account.isValid)
    }

    @Test func firstCustomerOffersDistinctPremiumJobsWithCanonicalCompletionRewards() throws {
        var account = TycoonAccount(seed: 41)
        let premiums = account.contractOffers.filter { $0.kind == .premium }
        #expect(premiums.count == 2)
        #expect(premiums.allSatisfy { $0.customer == .cornerMarket })
        #expect(Set(premiums.map(\.title)).count == 2)
        #expect(Set(premiums.map(\.target)).count == 2)
        #expect(Set(premiums.map(\.reward)).count == 2)
        let gift = try #require(premiums.first { $0.title.hasPrefix("Gift collection") })
        #expect(gift.target == 4 && gift.reward == 1_440)
        #expect({ account.acceptContract(gift) }())
        #expect(account.isValid)
        account = try JSONDecoder().decode(TycoonAccount.self, from: JSONEncoder().encode(account))
        #expect(account.progression.activeContract == gift && account.isValid)
        for _ in 0..<gift.target { #expect({ account.ship(box(account, customer: .cornerMarket)) != nil }()) }
        #expect(account.progression.lastContract?.reward == gift.reward)
        #expect(account.progression.completedContracts == 1 && account.progression.blueprints == 1)
        #expect(account.isValid)
    }

    @Test func supplyContractsAcceptMatchingWorkersAndRewardExactlyOnceAcrossReload() throws {
        var account = funded()
        let supply = try #require(account.contractOffers.first)
        #expect({ account.acceptContract(supply) }())
        #expect({ account.hireWorker(for: supply.customer) }())
        let manualBefore = account.completedOrders
        let initialCash = account.cash
        var workerCash = 0
        for _ in 0..<supply.target {
            workerCash += account.workerPayout(for: supply.customer)
            _ = account.advanceStaff(by: account.workerInterval(for: supply.customer))
        }
        #expect(account.cash == initialCash + workerCash + supply.reward)
        #expect(account.completedOrders == manualBefore)
        #expect(account.progression.activeContract == nil)
        #expect(account.progression.lastContract?.isComplete == true)
        #expect(account.progression.completedContracts == 1)
        let saved = account
        account = try JSONDecoder().decode(TycoonAccount.self, from: JSONEncoder().encode(account))
        #expect(account == saved)
        #expect({ account.advanceStaff(by: 0).isEmpty }())
        #expect({ !account.acceptContract(supply) }())
        #expect(account.cash == saved.cash)
        #expect(account.isValid)
    }

    @Test func premiumRequiresManualPackingAndUnlocksPermanentBlueprintAndFiniteBoost() throws {
        var account = funded()
        let premium = try #require(account.contractOffers.first { $0.kind == .premium })
        #expect({ account.acceptContract(premium) }())
        #expect({ account.hireWorker(for: premium.customer) }())
        _ = account.advanceStaff(by: 600)
        #expect(account.progression.activeContract?.progress == 0)
        for _ in 0..<premium.target { #expect({ account.ship(box(account, customer: premium.customer)) != nil }()) }
        #expect(account.progression.blueprints == 1)
        #expect(account.progression.manualBoostOrders == premium.target * 2 + 12)
        #expect(account.progression.lifetimeContracts == 1)
        let boost = account.workerPayout(for: premium.customer)
        let orders = account.progression.manualBoostOrders
        var reference = account
        reference.progression.manualBoostOrders = 0
        #expect(boost == reference.workerPayout(for: premium.customer) * 120 / 100)
        _ = account.advanceStaff(by: account.workerInterval(for: premium.customer) * Double(orders))
        #expect(account.progression.manualBoostOrders == 0)
        #expect(account.isValid)
    }

    @Test func relationshipsHaveSixBoundedLevelsAndManualRatesUsePriorRank() {
        var account = funded()
        for (xp, level, target) in [(0, 0, 10), (10, 1, 30), (30, 2, 75), (75, 3, 150), (150, 4, 300), (300, 5, -1)] {
            account.progression.relationships[.cornerMarket] = xp
            #expect(account.relationshipLevel(for: .cornerMarket) == level)
            #expect(account.relationshipTarget(for: .cornerMarket) == (target == -1 ? nil : target))
            #expect(account.payout(for: box(account, customer: .cornerMarket)) == 90 * (100 + 3 * level) / 100 + 18)
        }
        account.progression.relationships[.cornerMarket] = 9
        let receipt = account.ship(box(account, customer: .cornerMarket))
        #expect(receipt?.payout == 108)
        #expect(account.relationshipXP(for: .cornerMarket) == 12)
        #expect(account.payout(for: box(account, customer: .cornerMarket)) == 110)
        account.progression.relationships[.cornerMarket] = 999_999
        _ = account.ship(box(account, customer: .cornerMarket))
        #expect(account.relationshipXP(for: .cornerMarket) == 1_000_000)
    }

    @Test func offlineAndForegroundCompletionOrderAgreeAcrossRanksAndBoostExhaustion() {
        var batch = funded()
        for customer in [.cornerMarket, .bookshop, .plantShop] as [TycoonCustomer] {
            batch.teams[customer] = TycoonTeam(workers: 4, hasManager: true, progressSeconds: 11)
        }
        batch.teams[.bookshop]?.specialty = .mentor
        batch.teams[.plantShop]?.specialty = .express
        batch.progression.relationships[.cornerMarket] = 8
        batch.progression.manualBoostOrders = 9
        batch.progression.franchises = 1
        #expect({ batch.openBranch(.harbor) }())
        let supply = batch.contractOffers[0]
        #expect({ batch.acceptContract(supply) }())
        var foreground = batch
        let report = batch.advanceStaff(by: 7_200)
        var live = StaffReport()
        for _ in 0..<7_200 {
            let tick = foreground.advanceStaff(by: 1)
            live.earned += tick.earned; live.packedOrders += tick.packedOrders
        }
        #expect(live == report)
        #expect(batch.cash == foreground.cash)
        #expect(batch.progression.relationships == foreground.progression.relationships)
        #expect(batch.progression.lastContract == foreground.progression.lastContract)
        #expect(batch.progression.manualBoostOrders == foreground.progression.manualBoostOrders)
        #expect(batch.progression.lifetimeEarned == foreground.progression.lifetimeEarned)
        #expect(abs((batch.progression.branches[.harbor]?.progressSeconds ?? 0) - (foreground.progression.branches[.harbor]?.progressSeconds ?? 0)) < 0.000_001)
        #expect(batch.automatedOrders == foreground.automatedOrders)
        for customer in [.cornerMarket, .bookshop, .plantShop] as [TycoonCustomer] {
            #expect(abs((batch.teams[customer]?.progressSeconds ?? 0) - (foreground.teams[customer]?.progressSeconds ?? 0)) < 0.000_001)
        }
        #expect(batch.isValid && foreground.isValid)
    }

    @Test func exactCycleBoundariesPayWorkersAndBranchesOnceAndKeepValidFractionalClocks() {
        var account = funded()
        account.progression.franchises = 1
        account.teams[.cornerMarket] = TycoonTeam(workers: 1)
        #expect({ account.openBranch(.harbor) }())
        let first = account.advanceStaff(by: 60)
        #expect(first.packedOrders == 1 && first.earned == 250)
        #expect(account.teams[.cornerMarket]?.progressSeconds == 60)
        #expect(account.progression.branches[.harbor]?.progressSeconds == 0)
        let second = account.advanceStaff(by: 60)
        #expect(second.packedOrders == 2 && second.earned == 295)
        #expect(account.teams[.cornerMarket]?.progressSeconds == 0)
        #expect(account.progression.branches[.harbor]?.progressSeconds == 0)
        #expect(account.isValid)
        #expect({ account.advanceStaff(by: 0).isEmpty }())
    }

    @Test func milestonesAndSpecialtiesChangeRealRatesAndRequireManagers() {
        var account = funded()
        account.teams[.cornerMarket] = TycoonTeam(workers: 1)
        #expect({ !account.setSpecialty(.express, for: .cornerMarket) }())
        #expect({ account.hireManager(for: .cornerMarket) }())
        let normalInterval = account.workerInterval(for: .cornerMarket)
        #expect({ account.setSpecialty(.express, for: .cornerMarket) }())
        #expect(account.workerInterval(for: .cornerMarket) == normalInterval / 1.15)
        #expect({ account.setSpecialty(.careful, for: .cornerMarket) }())
        #expect(account.workerPayout(for: .cornerMarket) == 56 * 115 / 100)
        #expect({ account.setSpecialty(.mentor, for: .cornerMarket) }())
        _ = account.advanceStaff(by: account.workerInterval(for: .cornerMarket))
        #expect(account.relationshipXP(for: .cornerMarket) == 2)
        for upgrade in DepotUpgrade.allCases {
            account.levels[upgrade] = 4
            #expect(account.nextEquipmentMilestone(upgrade) == 5)
            let title = account.equipmentMilestoneTitle(upgrade)
            let manual = account.payout(for: box(account, customer: .cornerMarket))
            let worker = account.workerPayout(for: .cornerMarket)
            let interval = account.workerInterval(for: .cornerMarket)
            account.levels[upgrade] = 5
            #expect(account.nextEquipmentMilestone(upgrade) == 10)
            #expect(account.equipmentMilestoneTitle(upgrade) != title)
            if upgrade == .conveyor { #expect(account.workerInterval(for: .cornerMarket) < interval) }
            else if upgrade == .dispatchDesk { #expect(account.workerPayout(for: .cornerMarket) > worker) }
            else { #expect(account.payout(for: box(account, customer: .cornerMarket)) > manual) }
        }
        account.levels[.conveyor] = 30
        #expect(account.nextEquipmentMilestone(.conveyor) == nil)
    }

    @Test func neighborhoodsHaveClientsAndBranchesEarnAlongsideMainDepotWithoutCustomerXP() throws {
        var account = funded()
        #expect(!account.canOpenBranch(.harbor))
        account.progression.franchises = 3
        account.teams[.cornerMarket] = TycoonTeam(workers: 1)
        let manual = box(account, customer: .gadgetShop)
        for district in [Neighborhood.harbor, .artsQuarter, .uptown] {
            #expect({ account.openBranch(district) }())
            #expect({ account.visit(district) }())
            #expect(account.contractOffers.allSatisfy { $0.customer.neighborhood == district })
            #expect(account.canUpgradeBranch(district))
            #expect({ account.upgradeBranch(district) }())
        }
        #expect(account.accepts(manual.order))
        let cash = account.cash
        let passive = [Neighborhood.harbor, .artsQuarter, .uptown].reduce(0) { $0 + account.branchPayout($1) }
        let report = account.advanceStaff(by: 120)
        #expect(report.earned == passive * 2 + 45)
        #expect(account.cash == cash + report.earned)
        #expect(account.completedOrders == 1_000)
        #expect(account.relationshipXP(for: .uptownBoutique) == 0)
        #expect(account.relationshipXP(for: .cornerMarket) == 1)
        #expect({ account.hireWorker(for: .uptownBoutique) }())
        #expect({ account.hireManager(for: .uptownBoutique) }())
        #expect({ account.setSpecialty(.careful, for: .uptownBoutique) }())
        let restored = try JSONDecoder().decode(TycoonAccount.self, from: JSONEncoder().encode(account))
        #expect(restored == account && restored.isValid)
        #expect({ account.visit(.oldTown) }())
        #expect(account.progression.branches.count == 3)
    }

    @Test func franchiseIsVoluntaryLockedUntilLandmarkAndPreservesPermanentProgress() throws {
        var account = funded()
        #expect(!account.canFranchise)
        let locked = account
        #expect({ !account.franchise() }())
        #expect(account == locked)
        let landmark = try #require(account.contractOffers.first { $0.kind == .landmark })
        finish(&account, contract: landmark)
        account.progression.blueprints = 3
        account.progression.lifetimeManualOrders = 1_008
        account.progression.lifetimeEarned = account.totalEarned
        let reward = account.franchiseReward
        let target = account.nextFranchiseStarTarget
        #expect({ account.buy(.workbench) }())
        #expect(account.franchiseReward == reward)
        #expect(account.nextFranchiseStarTarget == target)
        let xp = account.progression.relationships
        let lifetime = account.progression.lifetimeEarned
        let seed = account.seed
        #expect({ account.franchise() }())
        #expect(account.seed != seed)
        #expect(account.stage == .spareRoom && account.cash == 0 && account.totalEarned == 0)
        #expect(account.completedOrders == 0 && account.automatedOrders == 0 && account.lastDelivery == nil)
        #expect(account.teams.isEmpty && account.progression.branches.isEmpty)
        #expect(account.progression.activeContract == nil && account.progression.lastContract == nil)
        #expect(account.progression.majorContracts == 0 && account.progression.completedContracts == 0)
        #expect(account.progression.manualBoostOrders == 0 && account.progression.blueprints == 3)
        #expect(account.progression.relationships == xp && account.progression.lifetimeEarned == lifetime)
        #expect(account.progression.lifetimeContracts == 1 && account.progression.franchises == 1)
        #expect(account.progression.stars == reward && account.progression.earnedStars == reward)
        #expect(account.isValid)
        #expect(!account.canFranchise)
    }

    @Test func headOfficeUsesBoundedStarsAndStarterPackageAllowsPurchasesBeforeFirstDelivery() throws {
        var account = funded()
        finish(&account, contract: try #require(account.contractOffers.first { $0.kind == .landmark }))
        #expect({ account.franchise() }())
        #expect({ account.buyFranchiseUpgrade(.establishedBusiness) }())
        #expect(account.cash == 0 && account.totalEarned == 0)
        #expect(account.isValid)
        account.progression.stars = 100; account.progression.earnedStars = 100
        for _ in 1..<5 { #expect({ account.buyFranchiseUpgrade(.establishedBusiness) }()) }
        #expect(account.franchiseUpgradeCost(.establishedBusiness) == nil)
        #expect({ !account.buyFranchiseUpgrade(.establishedBusiness) }())
        account.cash = 1_000_000; account.totalEarned = 1_000_000; account.completedOrders = 1_000; account.stage = .hub
        let prior = TycoonOrder.generate(accountSeed: account.seed, sequence: 1_000, choice: 0, customer: .makerCollective)
        account.lastDelivery = ShipmentReceipt(order: prior, payout: 900, cleanBonus: 150)
        finish(&account, contract: try #require(account.contractOffers.first { $0.kind == .landmark }))
        #expect({ account.franchise() }())
        #expect(account.cash == 1_250 && account.totalEarned == 1_250)
        #expect(account.teams[.cornerMarket]?.workers == 1)
        #expect({ account.buy(.workbench) }())
        #expect({ account.hireWorker(for: .cornerMarket) }())
        #expect(account.completedOrders == 0 && account.isValid)
        let level = account.franchiseUpgradeLevel(.training)
        let interval = account.workerInterval(for: .cornerMarket)
        #expect({ account.buyFranchiseUpgrade(.training) }())
        #expect(account.franchiseUpgradeLevel(.training) == level + 1)
        #expect(account.workerInterval(for: .cornerMarket) < interval)
        #expect({ account.buyFranchiseUpgrade(.buyingPower) }())
        #expect(account.upgradeCost(.labels) == 133)
        for _ in 0..<5 { #expect({ account.buyFranchiseUpgrade(.logistics) }()) }
        #expect(account.offlineHours == 18)
        let capped = account.advanceStaff(by: 1_000_000)
        #expect(capped.packedOrders > 240)
        #expect(account.isValid)
    }

    @Test func contractRewardHeadroomAndCorruptProgressionCannotOverflow() throws {
        var account = funded()
        let offer = try #require(account.contractOffers.first)
        account.cash = 1_000_000_000 - offer.reward + 1; account.totalEarned = account.cash
        #expect(!account.canAcceptContract(offer))
        account.cash = 1_000_000_000 - offer.reward - 50; account.totalEarned = account.cash
        #expect({ account.acceptContract(offer) }())
        account.teams[offer.customer] = TycoonTeam(workers: 1)
        #expect(account.isValid)
        let report = account.advanceStaff(by: 28_800)
        #expect(report.packedOrders == 1 && report.earned == 45)
        #expect(account.progression.activeContract?.progress == 1)
        #expect(account.isValid)
        let stable = account
        account.progression.completedContracts = Int.max
        #expect(!account.isValid)
        #expect({ account.advanceStaff(by: 1_000).isEmpty }())
        #expect({ !account.franchise() }())
        account = stable
        account.progression.manualBoostOrders = -1
        #expect(!account.isValid)
        account = stable
        account.progression.headOffice[.training] = Int.max
        #expect(!account.isValid)
        #expect({ !account.buyFranchiseUpgrade(.training) }())
    }

    @Test func legacyAndMalformedOptionalProgressionKeepOriginalBusinessAndHistoricalRecords() throws {
        let account = funded()
        let original = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(account)) as? [String: Any])
        for damage in ["missing", "malformed", "negative"] {
            var json = original
            if damage == "missing" { json.removeValue(forKey: "progression") }
            else if damage == "malformed" { json["progression"] = "broken" }
            else { json["progression"] = ["stars": -1] }
            let restored = try JSONDecoder().decode(TycoonAccount.self, from: JSONSerialization.data(withJSONObject: json))
            #expect(restored.isValid)
            #expect(restored.cash == account.cash && restored.totalEarned == account.totalEarned)
            #expect(restored.lastDelivery == account.lastDelivery && restored.stage == account.stage)
            #expect(restored.progression.relationships.isEmpty)
            #expect(restored.progression.lifetimeManualOrders == account.completedOrders)
            #expect(restored.progression.lifetimeEarned == account.totalEarned)
            #expect(restored.progression.franchises == 0)
        }
        var illegal = account
        illegal.teams[.harborOutfitters] = TycoonTeam(workers: 1)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(illegal)) as? [String: Any])
        json["progression"] = "broken"
        let restored = try JSONDecoder().decode(TycoonAccount.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!restored.isValid)
    }
}
