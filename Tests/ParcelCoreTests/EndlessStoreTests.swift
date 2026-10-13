import Foundation
import Testing
@testable import ParcelCore

@Suite struct EndlessStoreTests {
    private func defaults() -> (String, UserDefaults) {
        let name = "ParcelEndlessStore.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    @Test func boardTrayRNGScoreAndBestRoundTripTogether() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let store = EndlessStore(defaults: prefs)
        var state = EndlessState(seed: 17)
        for _ in 0..<5 {
            let hint = try #require(state.hint())
            let result = state.place(slot: hint.slot, origin: hint.origin)
            #expect(result != nil)
        }
        let saved = SavedEndless(best: state.score, state: state)
        #expect(store.save(saved))
        #expect(store.load() == saved)
        #expect(prefs.object(forKey: SessionStore.key) == nil)
    }

    @Test func malformedAndSemanticallyBrokenCurrentRunsPreserveValidBest() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let store = EndlessStore(defaults: prefs)
        let data = try JSONEncoder().encode(SavedEndless(best: 770, state: EndlessState(seed: 8)))
        let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var malformed = original
        malformed["state"] = "broken board"
        prefs.set(try JSONSerialization.data(withJSONObject: malformed), forKey: EndlessStore.key)
        #expect(store.load()?.best == 770)
        #expect(store.load()?.state == nil)
        var broken = original
        var state = try #require(broken["state"] as? [String: Any])
        state["board"] = [99] + Array(repeating: 0, count: 63)
        broken["state"] = state
        prefs.set(try JSONSerialization.data(withJSONObject: broken), forKey: EndlessStore.key)
        #expect(store.load()?.best == 770)
        #expect(store.load()?.state == nil)
    }

    @Test func invalidBestAndVersionAreRejectedAndInvalidSaveCannotReplaceAGoodOne() {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let store = EndlessStore(defaults: prefs)
        let valid = SavedEndless(best: 100, state: EndlessState(seed: 9))
        #expect(store.save(valid))
        #expect(!store.save(SavedEndless(best: -10, state: nil)))
        #expect(!store.save(SavedEndless(best: 11, state: nil)))
        #expect(!store.save(SavedEndless(best: Int.max, state: nil)))
        var future = valid
        future.version = 2
        #expect(!store.save(future))
        #expect(store.load() == valid)
    }

    @Test func validActiveScoreRecoversAnOutdatedBestInItsEnvelope() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let store = EndlessStore(defaults: prefs)
        var state = EndlessState(seed: 9)
        let hint = try #require(state.hint())
        let move = state.place(slot: hint.slot, origin: hint.origin)
        #expect(move != nil)
        let outdated = SavedEndless(best: 0, state: state)
        prefs.set(try JSONEncoder().encode(outdated), forKey: EndlessStore.key)
        #expect(store.load()?.best == state.score)
        #expect(store.load()?.state == state)
    }
}
