import Foundation
import Testing
@testable import ParcelCore

@Suite struct PackingTests {
    @Test func generatedBoxesAreDeterministicVariedAndFullyPackable() {
        for size in BoxSize.allCases {
            var signatures = Set<String>()
            var shapeTypes = Set<[Cell]>()
            for seed in 0..<60 {
                let puzzle = Puzzle.generate(seed: UInt64(seed), size: size)
                #expect(puzzle == .generate(seed: UInt64(seed), size: size))
                var state = PackingState(puzzle: puzzle)
                #expect(state.isValid)
                #expect(puzzle.parcels.count == (size == .small ? 4 : 5))
                for placement in puzzle.solution { #expect(state.place(placement) == true) }
                #expect(state.isComplete)
                #expect(state.occupiedCount == size.width * size.height)
                for parcel in puzzle.parcels { shapeTypes.insert(parcel.cells(rotation: 0)) }
                signatures.insert(puzzle.parcels.map { String(describing: $0.cells) }.joined())
            }
            #expect(signatures.count >= 35, "Insufficient variety for \(size)")
            #expect(shapeTypes.count >= 4)
        }
    }

    @Test func rotationIsClockwiseAndHandlesAllIntegerValues() {
        let parcel = Parcel(id: 0, cells: [Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)], colorIndex: 0)
        #expect(parcel.cells(rotation: 1) == [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 0, y: 1)])
        #expect(parcel.cells(rotation: 4) == parcel.cells(rotation: 0))
        #expect(parcel.cells(rotation: -1) == parcel.cells(rotation: 3))
        #expect(parcel.cells(rotation: Int.min) == parcel.cells(rotation: 0))
        #expect(parcel.cells(rotation: Int.max) == parcel.cells(rotation: 3))
    }

    @Test func invalidDropsAreAtomicAndUndoRestoresSpace() throws {
        let puzzle = Puzzle.generate(seed: 12, size: .small)
        var state = PackingState(puzzle: puzzle)
        let first = try #require(puzzle.solution.first)
        #expect(state.place(first) == true)
        let packed = state
        #expect(state.place(first) == false)
        for cell in [Cell(x: -1, y: 0), Cell(x: 0, y: -1), Cell(x: 4, y: 0), Cell(x: Int.max, y: Int.min)] {
            #expect(state.place(Placement(parcelID: puzzle.parcels.first { $0.id != first.parcelID }!.id, origin: cell, rotation: 0)) == false)
            #expect(state == packed)
        }
        #expect(state.place(Placement(parcelID: 999, origin: Cell(x: 0, y: 0), rotation: 0)) == false)
        #expect(state.undo() == true)
        #expect(state.occupiedCount == 0)
        #expect(state.undo() == false)
        #expect(state.place(first) == true)
        state.reset()
        #expect(state.placements.isEmpty)
    }

    @Test func hintsCompleteEverySizeFromEmptyAndPartialBoxes() throws {
        for size in BoxSize.allCases {
            for seed in 0..<30 {
                var state = PackingState(puzzle: .generate(seed: UInt64(seed), size: size))
                if seed.isMultiple(of: 2) { #expect(state.place(state.puzzle.solution.last!) == true) }
                while !state.isComplete {
                    let hint = try #require(state.hint(), "Missing hint for \(size) seed \(seed)")
                    #expect(state.place(hint) == true)
                }
                #expect(state.hint() == nil)
            }
        }
    }

    @Test func alternativeTilingsCountAsComplete() {
        let shape = [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)]
        let parcels = (0..<4).map { Parcel(id: $0, cells: shape, colorIndex: $0) }
        let solution = (0..<4).map { Placement(parcelID: $0, origin: Cell(x: ($0 % 2) * 2, y: ($0 / 2) * 2), rotation: 0) }
        let puzzle = Puzzle(seed: 0, size: .small, parcels: parcels, solution: solution)
        var state = PackingState(puzzle: puzzle)
        #expect(state.isValid)
        for p in solution.reversed() {
            #expect(state.place(Placement(parcelID: 3 - p.parcelID, origin: p.origin, rotation: 1)) == true)
        }
        #expect(state.isComplete)
        #expect(state.placements != puzzle.solution)
    }

    @Test func corruptDecodedStateCannotBecomePlayable() throws {
        let good = PackingState(puzzle: .generate(seed: 37, size: .large))
        let data = try JSONEncoder().encode(good)
        #expect(try JSONDecoder().decode(PackingState.self, from: data) == good)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var puzzle = try #require(json["puzzle"] as? [String: Any])
        var parcels = try #require(puzzle["parcels"] as? [[String: Any]])
        parcels[0]["cells"] = [["x": Int.max, "y": Int.min]]
        puzzle["parcels"] = parcels
        json["puzzle"] = puzzle
        let corrupt = try JSONDecoder().decode(PackingState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!corrupt.isValid)
        #expect(!corrupt.isComplete)
        #expect(corrupt.hint() == nil)
        #expect(!corrupt.canPlace(Placement(parcelID: 0, origin: Cell(x: 0, y: 0), rotation: Int.min)))
    }
}
