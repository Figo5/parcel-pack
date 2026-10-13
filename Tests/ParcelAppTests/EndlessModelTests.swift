import Foundation
import Testing
import ParcelCore
@testable import ParcelPackApp

@Suite @MainActor struct EndlessModelTests {
    private func defaults() -> (String, UserDefaults) {
        let name = "ParcelEndlessModel.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    @Test func legalMovesSaveCurrentBoardTrayRNGAndBestAcrossRelaunch() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let model = EndlessModel(defaults: prefs, seed: 90)
        for _ in 0..<4 {
            let hint = try #require(model.state.hint())
            let placed = model.place(slot: hint.slot, x: hint.origin.x, y: hint.origin.y)
            #expect(placed)
        }
        #expect(model.best == model.state.score)
        let restored = EndlessModel(defaults: prefs)
        #expect(restored.state == model.state)
        #expect(restored.best == model.best)
    }

    @Test func hintsOnlyHighlightAndInvalidMovesKeepTheSelectionAndScore() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let model = EndlessModel(defaults: prefs, seed: 10)
        let before = model.state
        model.select(2)
        model.hint()
        let suggestion = try #require(model.suggestedMove)
        #expect(suggestion.slot == 2)
        #expect(model.state == before)
        #expect(model.best == 0)
        let invalid = model.placeSelected(x: -1, y: 0)
        #expect(!invalid)
        #expect(model.state == before)
        #expect(model.selectedSlot == 2)
        #expect(model.best == 0)
        let valid = model.placeSelected(x: suggestion.origin.x, y: suggestion.origin.y)
        #expect(valid)
        #expect(model.suggestedMove == nil)
        #expect(model.selectedSlot == nil)
        #expect(model.state.score > 0)
    }

    @Test func startingOverAnActiveGameRequiresConfirmationAndKeepsBest() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let model = EndlessModel(defaults: prefs, seed: 10)
        let hint = try #require(model.state.hint())
        let placed = model.place(slot: hint.slot, x: hint.origin.x, y: hint.origin.y)
        #expect(placed)
        let before = model.state
        let record = model.best
        model.requestNewGame()
        #expect(model.showNewGame)
        #expect(model.state == before)
        model.cancelNewGame()
        #expect(!model.showNewGame)
        #expect(model.state == before)
        model.requestNewGame()
        model.confirmNewGame()
        #expect(!model.showNewGame)
        #expect(model.state.score == 0)
        #expect(model.state.placements == 0)
        #expect(model.state.occupiedCount == 0)
        #expect(model.best == record)
        #expect(EndlessModel(defaults: prefs).best == record)
    }

    @Test func finishedGamesRemainSavedAndCanStartAgainWithoutAbandonmentPrompt() {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let board = (0..<64).map { index in ((index % 8 + index / 8) % 2 == 0) ? 1 : 0 }
        let ended = EndlessState(board: board, tray: [EndlessPiece(shape: .square, colorIndex: 0), nil, nil], score: 320, placements: 32)
        #expect(EndlessStore(defaults: prefs).save(SavedEndless(best: 400, state: ended)))
        let model = EndlessModel(defaults: prefs)
        #expect(model.isGameOver)
        #expect(model.state == ended)
        let placed = model.place(slot: 0, x: 0, y: 0)
        #expect(!placed)
        #expect(model.state == ended)
        model.requestNewGame()
        #expect(!model.showNewGame)
        #expect(!model.isGameOver)
        #expect(model.state.score == 0)
        #expect(model.best == 400)
    }

    @Test func brokenActiveBoardRecoversToANewGameWithoutErasingBestOrLegacySaves() throws {
        let (name, prefs) = defaults()
        defer { prefs.removePersistentDomain(forName: name) }
        let saved = SavedEndless(best: 870, state: EndlessState(seed: 3))
        var payload = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        payload["state"] = "broken"
        prefs.set(try JSONSerialization.data(withJSONObject: payload), forKey: EndlessStore.key)
        prefs.set("legacy", forKey: "parcel-pack.session.v1")
        let model = EndlessModel(defaults: prefs, seed: 8)
        #expect(model.best == 870)
        #expect(model.state == EndlessState(seed: 8))
        #expect(model.state.isValid)
        #expect(prefs.string(forKey: "parcel-pack.session.v1") == "legacy")
        #expect(EndlessStore(defaults: prefs).load()?.best == 870)
    }
}
