import Foundation
import Testing
@testable import ParcelCore

@Suite struct TycoonStoreTests {
    @Test func damagedOptionalBoostPreservesBranchBusinessAndPartialCustomerBox() throws {
        let name = "ParcelTycoonProgressionRepair.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var account = TycoonAccount(seed: 837)
        account.cash = 1_000_000; account.totalEarned = 1_000_000; account.completedOrders = 1_000; account.stage = .hub
        account.progression.franchises = 1
        account.progression.branches[.harbor] = TycoonBranch(level: 2)
        account.progression.district = .harbor
        account.levels[.conveyor] = 8
        account.teams[.harborOutfitters] = TycoonTeam(workers: 3, hasManager: true, specialty: .careful)
        let paid = TycoonOrder.generate(accountSeed: account.seed, sequence: 1_000, choice: 0, customer: .harborOutfitters)
        account.lastDelivery = ShipmentReceipt(order: paid, payout: 1_080, cleanBonus: 180)
        let current = TycoonOrder.generate(accountSeed: account.seed, sequence: 1_001, choice: 1, customer: .harborOutfitters)
        var session = TycoonSession(order: current)
        let placement = try #require(current.puzzle.solution.first)
        #expect({ session.state.place(placement) }())
        let saved = SavedTycoon(account: account, session: session)
        let source = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        for damage in [-1 as Any, "broken" as Any] {
            var json = source
            var business = try #require(json["account"] as? [String: Any])
            var progression = try #require(business["progression"] as? [String: Any])
            progression["manualBoostOrders"] = damage; business["progression"] = progression; json["account"] = business
            defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: TycoonStore.key)
            let restored = try #require(TycoonStore(defaults: defaults).load())
            #expect(restored.account == account)
            #expect(restored.session == session)
            #expect(restored.account.progression.manualBoostOrders == 0)
        }
        let offer = try #require(account.contractOffers.first)
        #expect({ account.acceptContract(offer) }())
        let contracted = SavedTycoon(account: account, session: session)
        let activeSource = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(contracted)) as? [String: Any])
        account.progression.activeContract = nil
        for field in ["id", "reward"] {
            var json = activeSource
            var business = try #require(json["account"] as? [String: Any])
            var progression = try #require(business["progression"] as? [String: Any])
            var contract = try #require(progression["activeContract"] as? [String: Any])
            contract[field] = 300_000; progression["activeContract"] = contract
            business["progression"] = progression; json["account"] = business
            defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: TycoonStore.key)
            let restored = try #require(TycoonStore(defaults: defaults).load())
            #expect(restored.account == account)
            #expect(restored.session == session)
            #expect(restored.account.progression.activeContract == nil)
        }
    }
    @Test func malformedOrSemanticallyDamagedBoardsKeepTheBusiness() throws {
        let name = "ParcelTycoonStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = TycoonStore(defaults: defaults)
        var account = TycoonAccount(seed: 42)
        var session = TycoonSession(order: account.offers[0])
        for placement in session.state.puzzle.solution { _ = session.state.place(placement) }
        let receipt = account.ship(session)
        #expect(receipt != nil)
        let saved = SavedTycoon(account: account, session: session)
        let raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        for kind in ["malformed", "placements", "order"] {
            var json = raw
            if kind == "malformed" { json["session"] = ["state": "broken"] }
            else {
                var board = try #require(json["session"] as? [String: Any])
                if kind == "placements" {
                    var state = try #require(board["state"] as? [String: Any])
                    state["placements"] = [["parcelID": 999, "origin": ["x": 0, "y": 0], "rotation": 0]]
                    board["state"] = state
                } else {
                    var order = try #require(board["order"] as? [String: Any])
                    order["sequence"] = 99
                    board["order"] = order
                }
                json["session"] = board
            }
            defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: TycoonStore.key)
            let restored = try #require(store.load())
            #expect(restored.account == account)
            #expect(restored.session == nil)
        }
    }

    @Test func aPaidSessionAndPurchaseRoundTripTogether() throws {
        let name = "ParcelTycoonAtomic.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = TycoonStore(defaults: defaults)
        var account = TycoonAccount(seed: 91)
        var session = TycoonSession(order: account.offers[0])
        for _ in 0..<4 {
            session = TycoonSession(order: account.offers[0])
            for placement in session.state.puzzle.solution { _ = session.state.place(placement) }
            let receipt = account.ship(session)
            #expect(receipt != nil)
        }
        let paid = account.lastDelivery
        let bought = account.buy(.workbench)
        #expect(bought)
        let snapshot = SavedTycoon(account: account, session: session)
        #expect(store.save(snapshot))
        #expect(store.load() == snapshot)
        #expect(store.load()?.account.lastDelivery == paid)
        let duplicate = account.ship(session)
        #expect(duplicate == nil)
    }

    @Test func versionOneBusinessMigratesWithoutLosingMoneyOrCurrentCustomer() throws {
        let name = "ParcelTycoonMigration.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var account = TycoonAccount(seed: 118)
        for _ in 0..<4 {
            var box = TycoonSession(order: account.offers[0])
            for placement in box.state.puzzle.solution { _ = box.state.place(placement) }
            _ = account.ship(box)
        }
        let purchased = account.buy(.workbench)
        #expect(purchased)
        let order = TycoonOrder.generate(accountSeed: account.seed, sequence: 5, choice: 2, customer: .bookshop)
        let saved = SavedTycoon(account: account, session: TycoonSession(order: order))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        var business = try #require(json["account"] as? [String: Any])
        business.removeValue(forKey: "teams")
        business.removeValue(forKey: "automatedOrders")
        json["account"] = business
        json["version"] = 1
        json.removeValue(forKey: "staffUpdatedAt")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: TycoonStore.key)
        let restored = try #require(TycoonStore(defaults: defaults).load())
        #expect(restored.account == account)
        #expect(restored.session == saved.session)
        #expect(restored.account.level(.workbench) == 1)
        #expect(restored.staffUpdatedAt == nil)
    }
}
