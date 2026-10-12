import Foundation
import Testing
@testable import ParcelPackApp
import ParcelCore

@Suite @MainActor struct FixedOrientationMigrationTests {
    private func isolatedDefaults() -> (String, UserDefaults) {
        let name = "ParcelPackOrientationMigration.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    private func legacySessionData(_ session: SavedSession) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        var state = try #require(object["state"] as? [String: Any])
        var puzzle = try #require(state["puzzle"] as? [String: Any])
        puzzle.removeValue(forKey: "fixedOrientations")
        state["puzzle"] = puzzle
        object["state"] = state
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func legacyShiftData(_ saved: SavedShift) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        var run = try #require(object["run"] as? [String: Any])
        var plan = try #require(run["plan"] as? [String: Any])
        plan.removeValue(forKey: "fixedOrientations")
        run["plan"] = plan
        object["run"] = run
        return try JSONSerialization.data(withJSONObject: object)
    }

    // Recreate the old next-box transition without invoking the new automatic migration.
    private func nextLegacyBox(_ run: ShiftRun, lowerQuota: Bool = false) throws -> ShiftRun {
        #expect(run.phase == .sealed)
        let nextIndex = run.boxIndex + 1
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(run)) as? [String: Any])
        object["boxIndex"] = nextIndex
        object["parcels"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(run.shelfParcels + run.plan.boxes[nextIndex].parcels))
        object["placements"] = []
        object["phase"] = "packing"
        if lowerQuota {
            var plan = try #require(object["plan"] as? [String: Any])
            plan["target"] = max(1, run.plan.target - 7)
            object["plan"] = plan
        }
        let restored = try JSONDecoder().decode(ShiftRun.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(restored.isValid)
        #expect(!restored.plan.isFixedOrientation)
        return restored
    }

    private func mixedFreeBox() throws -> (PackingState, Placement, Placement) {
        for seed in 0..<80 {
            let puzzle = Puzzle.generate(seed: UInt64(seed), size: .medium, fixedOrientations: false)
            let fixed = PackingState(puzzle: puzzle).usingFixedOrientations().puzzle
            for compatible in puzzle.solution where compatible.rotation != 0 {
                var state = PackingState(puzzle: puzzle)
                let kept = state.place(compatible)
                guard kept else { continue }
                for parcel in puzzle.parcels where parcel.id != compatible.parcelID {
                    let updated = try #require(fixed.parcels.first(where: { $0.id == parcel.id }))
                    for rotation in 0..<4 where parcel.cells(rotation: rotation) != updated.cells {
                        for y in 0..<puzzle.height { for x in 0..<puzzle.width {
                            let incompatible = Placement(parcelID: parcel.id, origin: Cell(x: x, y: y), rotation: rotation)
                            if state.place(incompatible) { return (state, compatible, incompatible) }
                        } }
                    }
                }
            }
        }
        throw FixtureFailure.missingMixedPlacements
    }

    private func firstSealedLegacyBox(seed: UInt64) throws -> ShiftRun {
        var run = ShiftRun(runSeed: seed, fixedOrientations: false)
        let coreIDs = Set(run.box.coreSolution.map(\.parcelID))
        let carry = try #require(run.parcels.first(where: { !coreIDs.contains($0.id) && !$0.isRush }))
        let shelved = run.shelve(carry.id)
        #expect(shelved)
        for placement in run.box.coreSolution {
            let placed = run.place(placement)
            #expect(placed)
        }
        let result = run.seal()
        #expect(result != nil)
        #expect(run.phase == .sealed)
        return run
    }

    private func mixedShiftBox() throws -> (ShiftRun, Placement, Placement) {
        for seed in 0..<80 {
            let sealed = try firstSealedLegacyBox(seed: UInt64(seed))
            let original = try nextLegacyBox(sealed, lowerQuota: true)
            let fixed = ShiftPlan.generate(seed: original.plan.seed, number: original.plan.number)
            for compatible in original.box.coreSolution where compatible.rotation != 0 {
                var run = original
                guard run.place(compatible) else { continue }
                for parcel in run.box.parcels where parcel.id != compatible.parcelID {
                    let updated = try #require(fixed.boxes[run.boxIndex].parcels.first(where: { $0.id == parcel.id }))
                    for rotation in 0..<4 where parcel.cells(rotation: rotation) != updated.cells {
                        for y in 0..<run.height { for x in 0..<run.width {
                            let incompatible = Placement(parcelID: parcel.id, origin: Cell(x: x, y: y), rotation: rotation)
                            if run.place(incompatible) { return (run, compatible, incompatible) }
                        } }
                    }
                }
            }
        }
        throw FixtureFailure.missingMixedPlacements
    }

    @Test func oldFreePackingSaveRetainsCompatibleFootprintsAndLifetimeCount() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let (oldState, compatible, incompatible) = try mixedFreeBox()
        let oldCells = oldState.cells(for: compatible)
        defaults.set(try legacySessionData(SavedSession(state: oldState,
            rotations: [compatible.parcelID: compatible.rotation], shipped: 12, boxNumber: 20)), forKey: SessionStore.key)
        defaults.set(14, forKey: "parcel-pack.shipped.v1")

        let model = GameModel(defaults: defaults)
        #expect(model.state.puzzle.isFixedOrientation)
        #expect(model.state.isValid)
        #expect(model.shipped == 14)
        #expect(model.boxNumber == 20)
        #expect(model.state.placements.count == 1)
        let kept = try #require(model.state.placements.first)
        #expect(kept.parcelID == compatible.parcelID)
        #expect(kept.rotation == 0)
        #expect(model.state.cells(for: kept) == oldCells)
        #expect(model.availableParcels.contains(where: { $0.id == incompatible.parcelID }))
        #expect(SessionStore(defaults: defaults).load()?.rotations.isEmpty == true)

        let restored = GameModel(defaults: defaults)
        #expect(restored.state == model.state)
        #expect(restored.shipped == model.shipped)
        #expect(restored.boxNumber == model.boxNumber)
        let reference = try #require(restored.state.puzzle.solution.first(where: { $0.parcelID == incompatible.parcelID }))
        restored.select(reference.parcelID)
        let placed = restored.placeSelected(x: reference.origin.x, y: reference.origin.y)
        #expect(placed)
        #expect(restored.state.placements.last?.rotation == 0)
    }

    @Test func completedOldFreeBoxNeverReceivesShipmentCreditTwice() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let puzzle = Puzzle.generate(seed: 2026, size: .large, fixedOrientations: false)
        let state = PackingState(puzzle: puzzle, placements: puzzle.solution)
        #expect(state.isComplete)
        defaults.set(try legacySessionData(SavedSession(state: state, shipped: 12,
            boxNumber: 20, completionCredited: true)), forKey: SessionStore.key)

        let model = GameModel(defaults: defaults)
        #expect(model.state.isComplete)
        #expect(model.state.puzzle.isFixedOrientation)
        #expect(model.shipped == 12)
        #expect(SessionStore(defaults: defaults).load()?.completionCredited == true)
        model.restart()
        for _ in model.state.puzzle.parcels { model.hint() }
        #expect(model.state.isComplete)
        #expect(model.shipped == 12)
        #expect(model.boxNumber == 20)
        let restored = GameModel(defaults: defaults)
        #expect(restored.state == model.state)
        #expect(restored.shipped == 12)

        restored.nextBox()
        for _ in restored.state.puzzle.parcels { restored.hint() }
        #expect(restored.state.isComplete)
        #expect(restored.shipped == 13)
        #expect(restored.boxNumber == 21)
    }

    @Test func incompatibleCompletedFreeBoxKeepsItsEarnedCreditWhenUnpacked() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let vertical = (0..<4).map { Cell(x: 0, y: $0) }
        let parcels = (0..<4).map { Parcel(id: $0, cells: vertical, colorIndex: $0) }
        let reference = (0..<4).map { Placement(parcelID: $0, origin: Cell(x: 0, y: $0), rotation: 1) }
        let packed = (0..<4).map { Placement(parcelID: $0, origin: Cell(x: $0, y: 0), rotation: 0) }
        let puzzle = Puzzle(seed: 11, size: .small, parcels: parcels, solution: reference, fixedOrientations: false)
        let state = PackingState(puzzle: puzzle, placements: packed)
        #expect(state.isComplete)
        defaults.set(try legacySessionData(SavedSession(state: state, shipped: 12,
            boxNumber: 20, completionCredited: true)), forKey: SessionStore.key)

        let model = GameModel(defaults: defaults)
        #expect(model.state.puzzle.isFixedOrientation)
        #expect(model.state.placements.isEmpty)
        #expect(model.shipped == 12)
        #expect(model.boxNumber == 20)
        #expect(SessionStore(defaults: defaults).load()?.completionCredited == true)
        for _ in model.state.puzzle.parcels { model.hint() }
        #expect(model.state.isComplete)
        #expect(model.shipped == 12)
        #expect(GameModel(defaults: defaults).shipped == 12)
    }

    @Test func oldShiftPackingSavePreservesScoreQuotaShelfAndCompatibleFootprints() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let (oldRun, compatible, incompatible) = try mixedShiftBox()
        let oldCells = oldRun.cells(for: compatible)
        defaults.set(try legacyShiftData(SavedShift(run: oldRun,
            rotations: [compatible.parcelID: compatible.rotation])), forKey: ShiftStore.key)

        let model = ShiftModel(defaults: defaults)
        #expect(model.run.plan.isFixedOrientation)
        #expect(model.run.isValid)
        #expect(model.run.phase == .packing)
        #expect(model.run.boxIndex == oldRun.boxIndex)
        #expect(model.run.shiftScore == oldRun.shiftScore)
        #expect(model.run.runScore == oldRun.runScore)
        #expect(model.run.results == oldRun.results)
        #expect(model.run.plan.target == oldRun.plan.target)
        #expect(model.run.shelfIDs == oldRun.shelfIDs)
        #expect(model.run.placements.count == 1)
        let kept = try #require(model.run.placements.first)
        #expect(kept.parcelID == compatible.parcelID)
        #expect(kept.rotation == 0)
        #expect(model.run.cells(for: kept) == oldCells)
        #expect(!model.run.isPacked(incompatible.parcelID))
        let carry = try #require(model.run.shelfParcels.first)
        let fixedSource = try #require(model.run.plan.boxes[0].parcels.first(where: { $0.id == carry.id }))
        #expect(carry == fixedSource)
        #expect(ShiftStore(defaults: defaults).load()?.rotations.isEmpty == true)

        let restored = ShiftModel(defaults: defaults)
        #expect(restored.run == model.run)
        #expect(restored.record == model.record)
    }

    @Test func sealedLegacyBoxKeepsItsSnapshotUntilTheNextBoxStarts() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let oldRun = try firstSealedLegacyBox(seed: 73)
        defaults.set(try legacyShiftData(SavedShift(run: oldRun)), forKey: ShiftStore.key)
        let store = ShiftStore(defaults: defaults)
        let snapshot = try #require(store.load()?.run)

        let model = ShiftModel(defaults: defaults)
        #expect(model.run == snapshot)
        #expect(!model.run.plan.isFixedOrientation)
        #expect(model.run.isFull)
        #expect(model.run.phase == .sealed)
        #expect(model.record.runsFinished == 0)
        let restored = ShiftModel(defaults: defaults)
        #expect(restored.run == snapshot)

        restored.nextBox()
        #expect(restored.run.plan.isFixedOrientation)
        #expect(restored.run.phase == .packing)
        #expect(restored.run.boxIndex == 1)
        #expect(restored.run.placements.isEmpty)
        #expect(restored.run.shelfIDs == oldRun.shelfIDs)
        #expect(restored.run.shiftScore == oldRun.shiftScore)
        #expect(restored.run.results == oldRun.results)
        #expect(restored.run.isValid)
        let carry = try #require(restored.run.shelfParcels.first)
        #expect(restored.run.plan.boxes[0].parcels.contains(carry))
        #expect(ShiftModel(defaults: defaults).run == restored.run)
    }

    @Test func completedLegacyShiftOutcomesAndRecordsSurviveRelaunch() throws {
        for shouldClear in [true, false] {
            let (name, defaults) = isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }
            var oldRun = ShiftRun(runSeed: 17, fixedOrientations: false)
            for box in 0..<ShiftPlan.boxesPerShift {
                if shouldClear {
                    for placement in oldRun.box.coreSolution {
                        let placed = oldRun.place(placement)
                        #expect(placed)
                    }
                }
                let result = oldRun.seal()
                #expect(result != nil)
                if box < ShiftPlan.boxesPerShift - 1 { oldRun = try nextLegacyBox(oldRun) }
            }
            #expect(oldRun.phase == (shouldClear ? .cleared : .failed))
            let record = ShiftRecord(bestShiftsCleared: 4, bestRunScore: 400, runsFinished: 9)
            let store = ShiftStore(defaults: defaults)
            store.saveRecord(record)
            defaults.set(try legacyShiftData(SavedShift(run: oldRun)), forKey: ShiftStore.key)
            let snapshot = try #require(store.load()?.run)

            let model = ShiftModel(defaults: defaults)
            #expect(model.run == snapshot)
            #expect(model.record == record)
            model.seal()
            #expect(model.record == record)
            #expect(model.run == snapshot)
            let restored = ShiftModel(defaults: defaults)
            #expect(restored.run == snapshot)
            #expect(restored.record == record)
            if shouldClear {
                restored.nextShift()
                #expect(restored.run.plan.number == oldRun.plan.number + 1)
                #expect(restored.run.runScore == oldRun.runScore)
                #expect(restored.run.shiftsCleared == oldRun.shiftsCleared)
                #expect(restored.run.shiftScore == 0)
            } else {
                restored.newRun()
                #expect(restored.run.plan.number == 1)
                #expect(restored.run.runScore == 0)
            }
            #expect(restored.run.plan.isFixedOrientation)
            #expect(restored.run.phase == .packing)
            #expect(restored.record == record)
            #expect(store.loadRecord() == record)
        }
    }

    private enum FixtureFailure: Error { case missingMixedPlacements }
}
