import Testing
@testable import ParcelCore

@Suite struct EndlessTests {
    private func piece(_ shape: EndlessShape = .single, color: Int = 0) -> EndlessPiece {
        EndlessPiece(shape: shape, colorIndex: color)
    }

    @Test func catalogContainsOnlyFixedConnectedShapesOfOneToFiveSquares() {
        for shape in EndlessShape.allCases {
            let cells = shape.cells
            #expect((1...5).contains(cells.count))
            #expect(Set(cells).count == cells.count)
            #expect(cells.map(\.x).min() == 0)
            #expect(cells.map(\.y).min() == 0)
            var reached: Set<Cell> = [cells[0]]
            var frontier = [cells[0]]
            while let cell = frontier.popLast() {
                for next in cells where abs(next.x - cell.x) + abs(next.y - cell.y) == 1 {
                    if reached.insert(next).inserted { frontier.append(next) }
                }
            }
            #expect(reached.count == cells.count)
        }
        #expect(EndlessShape.square.cells.count == 4)
        #expect(EndlessShape.cross.cells.count == 5)
        #expect(EndlessShape.horizontalFive.cells.allSatisfy { $0.y == 0 })
    }

    @Test func generationAndFutureRefillsAreDeterministic() {
        var first = EndlessState(seed: 0xABCDEF)
        var second = EndlessState(seed: 0xABCDEF)
        var seen = Set<EndlessShape>()
        for _ in 0..<600 {
            #expect(first == second)
            #expect(first.isValid)
            seen.formUnion(first.tray.compactMap { $0?.shape })
            guard let hint = first.hint() else { break }
            let a = first.place(slot: hint.slot, origin: hint.origin)
            let b = second.place(slot: hint.slot, origin: hint.origin)
            #expect(a == b)
            #expect(a != nil)
        }
        for seed in UInt64(0)..<100 {
            seen.formUnion(EndlessState(seed: seed).tray.compactMap { $0?.shape })
        }
        #expect(seen.count == EndlessShape.allCases.count)
        #expect(first == second)
    }

    @Test func crossingRowAndColumnClearTogetherWithSharedCellCountedOnce() throws {
        var board = Array(repeating: 0, count: 64)
        for index in 1..<8 { board[index] = 1; board[index * 8] = 2 }
        var state = EndlessState(board: board, tray: [piece(), nil, nil], score: 140, placements: 14)
        #expect(state.isValid)
        let move = state.place(slot: 0, origin: Cell(x: 0, y: 0))
        let result = try #require(move)
        #expect(result.rows == [0])
        #expect(result.columns == [0])
        #expect(result.clearedCells.count == 15)
        #expect(Set(result.clearedCells).count == 15)
        #expect(result.points == 210)
        #expect(state.score == 350)
        #expect(state.linesCleared == 2)
        #expect(state.occupiedCount == 0)
        #expect(state.isValid)
    }

    @Test func multipleRowsClearInTheSamePlacement() throws {
        var board = Array(repeating: 0, count: 64)
        for y in 0..<2 { for x in 1..<8 { board[y * 8 + x] = 1 } }
        var state = EndlessState(board: board, tray: [piece(.verticalTwo), nil, nil], score: 140, placements: 14)
        let move = state.place(slot: 0, origin: Cell(x: 0, y: 0))
        let result = try #require(move)
        #expect(result.rows == [0, 1])
        #expect(result.columns.isEmpty)
        #expect(result.points == 220)
        #expect(result.clearedCells.count == 16)
        #expect(state.score == 360)
        #expect(state.occupiedCount == 0)
    }

    @Test func invalidPlacementIsAtomicAndCannotRotateAShapeToFit() {
        var state = EndlessState(board: Array(repeating: 0, count: 64), tray: [piece(.horizontalThree), piece(), piece()])
        let before = state
        for origin in [Cell(x: -1, y: 0), Cell(x: 6, y: 0), Cell(x: Int.max, y: Int.max)] {
            let result = state.place(slot: 0, origin: origin)
            #expect(result == nil)
            #expect(state == before)
        }
        let invalidSlot = state.place(slot: 3, origin: Cell(x: 0, y: 0))
        #expect(invalidSlot == nil)
        let placed = state.place(slot: 0, origin: Cell(x: 0, y: 0))
        #expect(placed?.points == 30)
        let occupied = state
        let overlap = state.place(slot: 1, origin: Cell(x: 1, y: 0))
        #expect(overlap == nil)
        #expect(state == occupied)
        let used = state.place(slot: 0, origin: Cell(x: 0, y: 2))
        #expect(used == nil)
        #expect(state == occupied)
    }

    @Test func trayRefillsOnlyAfterAllThreeParcelsAreUsed() {
        var state = EndlessState(board: Array(repeating: 0, count: 64), tray: [piece(), piece(), piece()], rngState: 17)
        let first = state.place(slot: 0, origin: Cell(x: 0, y: 0))
        #expect(first?.points == 10)
        #expect(state.remainingSlots == [1, 2])
        #expect(state.rngState == 17)
        let second = state.place(slot: 1, origin: Cell(x: 2, y: 0))
        #expect(second?.points == 10)
        #expect(state.remainingSlots == [2])
        #expect(state.rngState == 17)
        let third = state.place(slot: 2, origin: Cell(x: 4, y: 0))
        #expect(third?.points == 10)
        #expect(state.remainingSlots == [0, 1, 2])
        #expect(state.rngState != 17)
        #expect(state.score == 30)
        #expect(state.isValid)
    }

    @Test func gameEndsOnlyWhenEveryRemainingFixedShapeHasNoFit() throws {
        var board = (0..<64).map { index in ((index % 8 + index / 8) % 2 == 0) ? 1 : 0 }
        let ended = EndlessState(board: board, tray: [piece(.square), nil, nil], score: 320, placements: 32)
        #expect(ended.isValid)
        #expect(ended.isGameOver)
        #expect(ended.hint() == nil)
        board[0] = 0
        board[2] = 0
        let active = EndlessState(board: board, tray: [piece(.square), piece(), piece(.cross)], score: 300, placements: 30)
        #expect(active.isValid)
        #expect(!active.isGameOver)
        let hint = try #require(active.hint(preferredSlot: 0))
        #expect(hint.slot == 1)
        #expect(active.canPlace(slot: hint.slot, origin: hint.origin))
    }

    @Test func hintIsAnObservationWithoutScoreOrRNGMutation() throws {
        let state = EndlessState(seed: 81)
        let before = state
        let hint = try #require(state.hint(preferredSlot: 2))
        #expect(hint.slot == 2)
        #expect(state.canPlace(slot: hint.slot, origin: hint.origin))
        #expect(state == before)
    }

    @Test func validationRejectsUnsafeCountersColorsBoardsAndTrayHistory() {
        let empty = Array(repeating: 0, count: 64)
        let tray: [EndlessPiece?] = [piece(), piece(), piece()]
        #expect(!EndlessState(board: Array(repeating: 0, count: 63), tray: tray).isValid)
        #expect(!EndlessState(board: [99] + Array(repeating: 0, count: 63), tray: tray).isValid)
        #expect(!EndlessState(board: empty, tray: [piece(color: 6), piece(), piece()]).isValid)
        #expect(!EndlessState(board: empty, tray: [nil, nil, nil]).isValid)
        #expect(!EndlessState(board: empty, tray: tray, score: -10).isValid)
        #expect(!EndlessState(board: empty, tray: tray, score: Int.max).isValid)
        #expect(!EndlessState(board: empty, tray: tray, placements: Int.max).isValid)
        #expect(!EndlessState(board: empty, tray: tray, linesCleared: Int.max).isValid)
        #expect(!EndlessState(board: empty, tray: tray, score: 20, placements: 1).isValid)
        #expect(!EndlessState(board: empty, tray: tray, score: 100, linesCleared: 1).isValid)
    }

    @Test func alreadyCompletedLinesAreNotAcceptedAsAnActiveSave() {
        var board = Array(repeating: 0, count: 64)
        for index in 0..<8 { board[index] = 1 }
        let state = EndlessState(board: board, tray: [piece(), nil, nil], score: 80, placements: 8)
        #expect(!state.isValid)
        var invalid = state
        let result = invalid.place(slot: 0, origin: Cell(x: 0, y: 1))
        #expect(result == nil)
        #expect(invalid == state)
    }
}
