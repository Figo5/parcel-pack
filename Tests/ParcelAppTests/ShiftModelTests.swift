import Foundation
import Testing
@testable import ParcelPackApp
import ParcelCore

@Suite @MainActor struct ShiftModelTests {
    private func isolatedDefaults() -> (String, UserDefaults) {
        let name = "ParcelPackShiftTests.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    /// Places each parcel in the orientation shown in its tray.
    @discardableResult
    private func pack(_ model: ShiftModel, _ placement: Placement) -> Bool {
        model.select(placement.parcelID)
        return model.placeSelected(x: placement.origin.x, y: placement.origin.y)
    }

    @Test func newModelStartsShiftOneBoxZeroPacking() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ShiftModel(defaults: defaults)
        #expect(model.run.plan.number == 1)
        #expect(model.run.boxIndex == 0)
        #expect(model.run.phase == .packing)
        #expect(model.run.shiftScore == 0)
    }

    @Test func packingTheCoreSolutionScoresADoubledFullBox() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ShiftModel(defaults: defaults)
        for placement in model.run.box.coreSolution {
            #expect(pack(model, placement))
        }
        #expect(model.run.isFull)
        model.seal()
        let result = try #require(model.run.lastResult)
        #expect(result.full)
        #expect(result.score == 2 * model.run.box.coreValue - result.lateFees)
        #expect(model.run.phase == .sealed)
        model.nextBox()
        #expect(model.run.boxIndex == 1)
        #expect(model.run.phase == .packing)
    }

    @Test func shelfSurvivesRelaunch() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ShiftModel(defaults: defaults)
        let parcel = try #require(model.run.trayParcels.first)
        model.select(parcel.id)
        model.toggleShelfForSelected()
        #expect(model.run.shelfIDs == [parcel.id])
        #expect(model.run.location(of: parcel.id) == ParcelLocation.shelf)
        let restored = ShiftModel(defaults: defaults)
        #expect(restored.run.shelfIDs == model.run.shelfIDs)
        #expect(restored.run.boxIndex == model.run.boxIndex)
    }

    @Test func sealingFiveEmptyBoxesEndsTheRun() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ShiftModel(defaults: defaults)
        for index in 0..<ShiftPlan.boxesPerShift {
            model.seal()
            if index < ShiftPlan.boxesPerShift - 1 {
                model.nextBox()
            }
        }
        #expect(model.run.phase == .failed)
        #expect(model.record.runsFinished == 1)
        model.newRun()
        #expect(model.run.plan.number == 1)
        #expect(model.run.boxIndex == 0)
        #expect(model.run.shiftScore == 0)
    }

    @Test func invalidPlacementKeepsStateAndSelection() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ShiftModel(defaults: defaults)
        let parcel = try #require(model.run.trayParcels.first)
        model.select(parcel.id)
        let before = model.run
        #expect(!model.placeSelected(x: -1, y: -1))
        #expect(model.run == before)
        #expect(model.selectedID == parcel.id)
    }
}

@Suite @MainActor struct ShiftRecordBoundaryTests {
    @Test func finishingAnotherRunCannotOverflowTheStoredCounter() throws {
        let name = "ParcelPackShiftRecordLimit.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        ShiftStore(defaults: defaults).saveRecord(ShiftRecord(runsFinished: Int.max))
        let model = ShiftModel(defaults: defaults)
        for box in 0..<5 { model.seal(); if box < 4 { model.nextBox() } }
        #expect(model.record.runsFinished == Int.max)
        #expect(model.run.phase == .failed)
    }
}
