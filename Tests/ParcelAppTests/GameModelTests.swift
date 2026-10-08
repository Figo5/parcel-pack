import Foundation
import Testing
@testable import ParcelPackApp
import ParcelCore

@Suite @MainActor struct GameModelTests {
    private func isolatedDefaults() -> (String, UserDefaults) {
        let name = "ParcelPackModelTests.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    @Test func completingAndRepackingCreditsOneShipment() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = GameModel(defaults: defaults)
        for _ in 0..<model.state.puzzle.parcels.count { model.hint() }
        #expect(model.state.isComplete)
        #expect(model.shipped == 1)
        model.undo()
        #expect(!model.state.isComplete)
        model.hint()
        #expect(model.state.isComplete)
        #expect(model.shipped == 1)
        model.restart()
        for _ in 0..<model.state.puzzle.parcels.count { model.hint() }
        #expect(model.shipped == 1)
        let restored = GameModel(defaults: defaults)
        #expect(restored.state.isComplete)
        #expect(restored.shipped == 1)
        restored.nextBox()
        #expect(!restored.state.isComplete)
        #expect(restored.boxNumber == 2)
        for _ in 0..<restored.state.puzzle.parcels.count { restored.hint() }
        #expect(restored.shipped == 2)
    }

    @Test func invalidPlacementPreservesBoxAndSelection() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = GameModel(defaults: defaults)
        let parcel = try #require(model.availableParcels.first)
        model.select(parcel.id)
        let before = model.state
        #expect(!model.placeSelected(x: -1, y: -1))
        #expect(model.state == before)
        #expect(model.selectedID == parcel.id)
        for _ in 0..<4 { model.rotateSelected() }
        #expect(model.selectedRotation == 0)
    }

    @Test func progressAndSettingsSurviveRelaunch() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = GameModel(defaults: defaults)
        model.soundEnabled = true
        model.hapticsEnabled = false
        model.hint()
        model.save()
        let restored = GameModel(defaults: defaults)
        #expect(restored.state == model.state)
        #expect(restored.soundEnabled)
        #expect(!restored.hapticsEnabled)
    }

    @Test func firstBoxIsSavedBeforeAnyMove() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = GameModel(defaults: defaults)
        #expect(SessionStore(defaults: defaults).load()?.state == model.state)
        let restored = GameModel(defaults: defaults)
        #expect(restored.state == model.state)
    }

    @Test func corruptedBoxDoesNotEraseLifetimeShipments() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = GameModel(defaults: defaults)
        for _ in 0..<4 { model.hint() }
        #expect(model.shipped == 1)
        defaults.set(Data("damaged saved box".utf8), forKey: SessionStore.key)
        let restored = GameModel(defaults: defaults)
        #expect(restored.state.isValid)
        #expect(restored.state.placements.isEmpty)
        #expect(restored.shipped == 1)
    }

    @Test func sizeSwitchAsksBeforeDiscardingPartialBox() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = GameModel(defaults: defaults)
        model.hint()
        model.changeSize(.large)
        #expect(model.pendingSize == .large)
        #expect(model.state.puzzle.size == .small)
        model.confirmSizeChange()
        #expect(model.pendingSize == nil)
        #expect(model.state.puzzle.size == .large)
        #expect(model.state.placements.isEmpty)
        #expect(model.state.isValid)
    }

    @Test func hintRecoversWhenALegalPlacementBlocksTheBox() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let square = [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)]
        let pieces = (0..<4).map { Parcel(id: $0, cells: square, colorIndex: $0) }
        let solution = (0..<4).map {
            Placement(parcelID: $0, origin: Cell(x: ($0 % 2) * 2, y: ($0 / 2) * 2), rotation: 0)
        }
        let puzzle = Puzzle(seed: 0, size: .small, parcels: pieces, solution: solution)
        let blocked = Placement(parcelID: 0, origin: Cell(x: 1, y: 1), rotation: 0)
        let state = PackingState(puzzle: puzzle, placements: [blocked])
        #expect(state.isValid)
        #expect(state.hint() == nil)
        #expect(!state.canPlace(Placement(parcelID: 1, origin: blocked.origin, rotation: 0)))
        #expect(SessionStore(defaults: defaults).save(SavedSession(state: state)))
        let model = GameModel(defaults: defaults)
        model.hint()
        #expect(model.message.hasPrefix("Unpacked 1 parcel"))
        #expect(model.state.placements.count == 1)
        #expect(model.state.placements.first != blocked)
        for _ in 0..<3 { model.hint() }
        #expect(model.state.isComplete)
        #expect(model.shipped == 1)
    }
}
