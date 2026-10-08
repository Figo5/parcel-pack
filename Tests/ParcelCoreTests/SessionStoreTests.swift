import Foundation
import Testing
@testable import ParcelCore

@Suite struct SessionStoreTests {
    @Test func partialBoxRoundTrips() throws {
        let name = "ParcelPackTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SessionStore(defaults: defaults)
        var state = PackingState(puzzle: .generate(seed: 2026, size: .small))
        #expect(state.place(try #require(state.puzzle.solution.first)) == true)
        let saved = SavedSession(state: state, rotations: [0: 2], shipped: 12, boxNumber: 20)
        #expect(store.save(saved))
        #expect(store.load() == saved)
    }

    @Test func damagedOrUnsupportedSaveIsIgnored() throws {
        let name = "ParcelPackTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SessionStore(defaults: defaults)
        defaults.set(Data("not json".utf8), forKey: SessionStore.key)
        #expect(store.load() == nil)
        var saved = SavedSession(state: PackingState(puzzle: .generate(seed: 0, size: .medium)))
        saved.version = 99
        defaults.set(try JSONEncoder().encode(saved), forKey: SessionStore.key)
        #expect(store.load() == nil)
        saved.version = 1
        saved.rotations = [Int.max: -1]
        #expect(!store.save(saved))
        defaults.set(Data(repeating: 32, count: 64_001), forKey: SessionStore.key)
        #expect(store.load() == nil)
    }
}
