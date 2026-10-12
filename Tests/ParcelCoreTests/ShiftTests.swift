import Foundation
import Testing
@testable import ParcelCore

@Suite struct ShiftTests {
    private func exactFill(_ placements: [Placement], parcels: [ShiftParcel], width: Int, height: Int) -> Bool {
        var occupied = Set<Cell>(), ids = Set<Int>()
        for placement in placements {
            guard ids.insert(placement.parcelID).inserted,
                  let parcel = parcels.first(where: { $0.id == placement.parcelID }) else { return false }
            for cell in parcel.cells(rotation: placement.rotation) {
                let point = Cell(x: cell.x + placement.origin.x, y: cell.y + placement.origin.y)
                guard (0..<width).contains(point.x), (0..<height).contains(point.y), occupied.insert(point).inserted else { return false }
            }
        }
        return occupied.count == width * height
    }

    // Independent, deliberately simple oracle for tiny boards: first free cell, all parcels and rotations.
    private func bruteBest(parcels: [ShiftParcel], required: Set<Int>) -> Int? {
        var best: Int?
        func visit(_ occupied: Set<Cell>, _ used: Set<Int>, _ value: Int) {
            let cells = (0..<6).map { Cell(x: $0 % 3, y: $0 / 3) }
            guard let first = cells.first(where: { !occupied.contains($0) }) else {
                if required.isSubset(of: used) { best = max(best ?? 0, value) }
                return
            }
            for parcel in parcels where !used.contains(parcel.id) {
                for rotation in 0..<4 {
                    let shape = parcel.cells(rotation: rotation)
                    for y in 0..<2 { for x in 0..<3 {
                        let footprint = Set(shape.map { Cell(x: x + $0.x, y: y + $0.y) })
                        guard footprint.contains(first), footprint.allSatisfy({ (0..<3).contains($0.x) && (0..<2).contains($0.y) }), footprint.isDisjoint(with: occupied) else { continue }
                        visit(occupied.union(footprint), used.union([parcel.id]), value + parcel.value)
                    } }
                }
            }
        }
        visit([], [], 0)
        return best
    }

    @Test func solverMatchesIndependentOracleIncludingRequiredParcels() {
        let shapes = [ [Cell(x: 0,y: 0),Cell(x: 1,y: 0)],
            [Cell(x: 0,y: 0),Cell(x: 1,y: 0),Cell(x: 0,y: 1)],
            [Cell(x: 0,y: 0),Cell(x: 1,y: 0),Cell(x: 2,y: 0)],
            [Cell(x: 0,y: 0),Cell(x: 1,y: 0),Cell(x: 2,y: 0),Cell(x: 1,y: 1)],
            [Cell(x: 0,y: 0)] ]
        for seed in 0..<24 {
            let parcels = shapes.enumerated().map { ShiftParcel(id: $0.offset, cells: $0.element, colorIndex: $0.offset, value: 1 + (seed + $0.offset * 3) % 4, dueBox: nil) }
            for required: Set<Int> in [[], [seed % 5]] {
                let result = ShiftSolver.bestFullBox(width: 3,height: 2,parcels: parcels,mustInclude: required)
                #expect((result?.value == bruteBest(parcels: parcels,required: required)))
                if let result {
                    #expect((result.exhaustive))
                    #expect((exactFill(result.placements,parcels: parcels,width: 3,height: 2)))
                    #expect((required.isSubset(of: Set(result.placements.map(\.parcelID)))))
                }
            }
        }
    }

    @Test func generatedBatchesHaveMixedSizesExtrasAndAReferenceFill() {
        var observedSizes = Set<Int>(), branching = false
        for number in 1...4 { for seed in 1...40 {
            let plan = ShiftPlan.generate(seed: UInt64(seed),number: number)
            #expect((plan == ShiftPlan.generate(seed: UInt64(seed),number: number)))
            #expect((plan.boxes.count == 5))
            #expect((Set(plan.boxes.flatMap { $0.parcels.map(\.id) }).count == plan.boxes.flatMap(\.parcels).count))
            for (index,box) in plan.boxes.enumerated() {
                #expect((exactFill(box.coreSolution,parcels: box.parcels,width: box.width,height: box.height)))
                #expect((box.parcels.count == box.coreSolution.count + (number == 1 ? 2 : 3)))
                #expect((box.parcels.reduce(0) { $0 + $1.cells.count } > box.width * box.height))
                for parcel in box.parcels {
                    #expect(((1...4).contains(parcel.value)))
                    #expect(((2...5).contains(parcel.cells.count)))
                    if let due = parcel.dueBox { #expect((due == min(index + 1,4))) }
                    observedSizes.insert(parcel.cells.count)
                    for cell in parcel.cells {
                        if parcel.cells.filter({ abs($0.x-cell.x)+abs($0.y-cell.y)==1 }).count >= 3 { branching = true }
                    }
                }
            }
        } }
        #expect((observedSizes == [2,3,4,5]))
        #expect((branching))
    }

    @Test func generatedBoxesSolveExhaustivelyAndNeverScoreBelowTheReference() throws {
        for number in 1...3 { for seed in 1...25 {
            for box in ShiftPlan.generate(seed: UInt64(seed),number: number).boxes {
                let best = try #require((ShiftSolver.bestFullBox(width: box.width,height: box.height,parcels: box.parcels)))
                #expect((best.exhaustive))
                #expect((best.value >= box.coreValue))
                #expect((exactFill(best.placements,parcels: box.parcels,width: box.width,height: box.height)))
                #expect((best.value == best.placements.reduce(0) { sum,p in sum + box.parcels.first(where: { $0.id == p.parcelID })!.value }))
            }
        } }
    }

    @Test func solverRejectsUnknownRequiredIDsDuplicateIDsAndInvalidValues() {
        let domino = ShiftParcel(id: 1,cells: [Cell(x: 0,y: 0),Cell(x: 1,y: 0)],colorIndex: 0,value: 2,dueBox: nil)
        #expect((ShiftSolver.bestFullBox(width: 2,height: 1,parcels: [domino],mustInclude: [99]) == nil))
        #expect((ShiftSolver.bestFullBox(width: 2,height: 1,parcels: [domino,domino]) == nil))
        #expect((ShiftSolver.bestFullBox(width: 26,height: 1,parcels: [domino]) == nil))
        let bad = ShiftParcel(id: 2,cells: domino.cells,colorIndex: 0,value: Int.max,dueBox: nil)
        #expect((ShiftSolver.bestFullBox(width: 2,height: 1,parcels: [bad]) == nil))
    }

    @Test func placementFailureIsAtomicAndShelfTransfersRespectCapacity() throws {
        var run = ShiftRun(runSeed: 42)
        let original = run
        #expect({ (!run.place(Placement(parcelID: 999,origin: Cell(x: 0,y: 0),rotation: 0))) }())
        #expect((run == original))
        let parcels = Array(run.parcels.prefix(4))
        for p in parcels.prefix(3) { #expect({ (run.shelve(p.id)) }()) }
        #expect({ (!run.shelve(parcels[3].id)) }())
        #expect({ (!run.shelve(parcels[0].id)) }())
        #expect({ (run.unshelve(parcels[0].id)) }())
        let placement = try #require((run.box.coreSolution.first))
        #expect({ (run.shelve(placement.parcelID) || run.shelfIDs.contains(placement.parcelID)) }())
        #expect({ (run.place(placement)) }())
        #expect((!run.shelfIDs.contains(placement.parcelID)))
        #expect({ (run.remove(parcelID: placement.parcelID)) }())
        #expect((run.location(of: placement.parcelID) == .tray))
    }

    @Test func fullBoxScoresOnceAndOrdinaryShelfParcelsCarryOver() throws {
        var run = ShiftRun(runSeed: 42)
        let coreIDs = Set(run.box.coreSolution.map(\.parcelID))
        let extra = try #require((run.parcels.first(where: { !coreIDs.contains($0.id) })))
        #expect({ (run.shelve(extra.id)) }())
        for p in run.box.coreSolution { #expect({ (run.place(p)) }()) }
        let expected = run.box.coreValue * 2
        let result = try #require({ (run.seal()) }())
        #expect((result.score == expected))
        #expect((result.full))
        #expect({ (run.seal() == nil) }())
        #expect({ (!run.unshelve(extra.id)) }())
        #expect((run.isValid))
        #expect({ (run.nextBox()) }())
        #expect((run.shelfIDs.contains(extra.id)))
        #expect((run.parcel(extra.id) == extra))
        #expect((run.isValid))
    }

    @Test func rushParcelsCostOneFeeWhenReturnedOrHeldPastTheirDeadline() throws {
        var run = ShiftRun(runSeed: 17)
        for _ in 0..<2 { _ = run.seal(); #expect({ (run.nextBox()) }()) }
        let rushCandidate = run.parcels.first(where: { $0.isRush })
        let rush = try #require(rushCandidate)
        var returned = run
        let early = try #require({ (returned.seal()) }())
        #expect((early.lateCount == 1))
        #expect((early.lateFees == 5))
        #expect({ (run.shelve(rush.id)) }())
        let held = try #require({ (run.seal()) }())
        #expect((held.lateCount == 0))
        #expect({ (run.nextBox()) }())
        let expectedBest = try #require((ShiftSolver.bestFullBox(width: run.width,height: run.height,parcels: run.parcels)))
        let overdue = try #require({ (run.seal()) }())
        #expect((overdue.lateCount == 1))
        #expect((overdue.bestFull == expectedBest.value * 2))
        #expect((run.parcel(rush.id) == nil))
        #expect((!run.shelfIDs.contains(rush.id)))
        #expect((run.isValid))
    }

    @Test func failedRunsCannotAdvanceAndSavingEachPhaseRoundTrips() throws {
        let name = "ParcelShiftRoundTrip.\(UUID().uuidString)"
        let defaults = try #require((UserDefaults(suiteName: name)))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ShiftStore(defaults: defaults)
        var run = ShiftRun(runSeed: 42)
        for box in 0..<5 {
            #expect((store.save(SavedShift(run: run))))
            #expect((store.load()?.run == run))
            #expect({ (run.seal() != nil) }())
            #expect((store.save(SavedShift(run: run))))
            #expect((store.load()?.run == run))
            if box < 4 { #expect({ (run.nextBox()) }()) }
        }
        #expect((run.phase == .failed))
        #expect({ (!run.nextShift()) }())
        #expect({ (!run.nextBox()) }())
        #expect({ (run.seal() == nil) }())
    }

    @Test func corruptShiftDataPreservesTheSeparateBestRecord() throws {
        let name = "ParcelShiftCorrupt.\(UUID().uuidString)"
        let defaults = try #require((UserDefaults(suiteName: name)))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ShiftStore(defaults: defaults)
        let record = ShiftRecord(bestShiftsCleared: 3,bestRunScore: 250,runsFinished: 7)
        store.saveRecord(record)
        defaults.set(Data("broken".utf8),forKey: ShiftStore.key)
        #expect((store.load() == nil))
        #expect((store.loadRecord() == record))
    }
}

@Suite struct ShiftSaveValidationTests {
    @Test func aClearedShiftStartsFreshWithoutLosingRunScore() {
        var run = ShiftRun(runSeed: 42)
        for box in 0..<5 {
            for placement in run.box.coreSolution { _ = run.place(placement) }
            _ = run.seal()
            if box < 4 { _ = run.nextBox() }
        }
        #expect(run.phase == .cleared)
        #expect(run.shiftsCleared == 1)
        let total = run.runScore
        let advanced = run.nextShift()
        #expect(advanced)
        #expect(run.plan.number == 2)
        #expect(run.runScore == total)
        #expect(run.shiftScore == 0)
        #expect(run.shelfIDs.isEmpty && run.placements.isEmpty && run.results.isEmpty)
        #expect(run.isValid)
    }

    @Test func tamperedQuotaSeedAndOutcomeCannotBecomePlayable() throws {
        let run = ShiftRun(runSeed: 42)
        let data = try JSONEncoder().encode(SavedShift(run: run))
        let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for field in ["quota", "seed", "phase", "arrivals", "parcelValue"] {
            var object = original
            var state = try #require(object["run"] as? [String: Any])
            var plan = try #require(state["plan"] as? [String: Any])
            if field == "quota" { plan["target"] = 0 }
            if field == "seed" { state["runSeed"] = 123 }
            if field == "phase" { state["phase"] = "cleared" }
            if field == "arrivals" { state["parcels"] = [] }
            if field == "parcelValue" {
                var boxes = try #require(plan["boxes"] as? [[String: Any]])
                var parcels = try #require(boxes[0]["parcels"] as? [[String: Any]])
                for index in parcels.indices { parcels[index]["value"] = Int.max }
                boxes[0]["parcels"] = parcels
                plan["boxes"] = boxes
            }
            state["plan"] = plan; object["run"] = state
            let modified = try JSONSerialization.data(withJSONObject: object)
            let saved = try JSONDecoder().decode(SavedShift.self,from: modified)
            #expect(!saved.isValid)
        }
    }

    @Test func aPreviouslySavedIntroductoryQuotaSurvivesBalanceTuning() throws {
        let run = ShiftRun(runSeed: 42)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(SavedShift(run: run))) as? [String: Any])
        var state = try #require(object["run"] as? [String: Any])
        var plan = try #require(state["plan"] as? [String: Any])
        let oldTarget = (run.plan.reference * 70 + 99) / 100
        plan["target"] = oldTarget; state["plan"] = plan; object["run"] = state
        let saved = try JSONDecoder().decode(SavedShift.self,from: JSONSerialization.data(withJSONObject: object))
        #expect(saved.isValid)
        #expect(saved.run.plan.target == oldTarget)
    }
}
