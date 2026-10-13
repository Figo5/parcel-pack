import Foundation
import Testing
@testable import ParcelCore

@Suite struct TycoonStoreTests {
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
