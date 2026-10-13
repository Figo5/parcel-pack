import Foundation

public enum EndlessShape: Int, CaseIterable, Codable, Sendable {
    case single, horizontalTwo, verticalTwo, horizontalThree, verticalThree
    case smallL, smallJ, smallCorner, smallHook, square
    case horizontalFour, verticalFour, tee, upsideDownTee, leftTee, rightTee
    case tallL, tallJ, horizontalFive, verticalFive, cross

    public var cells: [Cell] {
        let points: [(Int, Int)]
        switch self {
        case .single: points = [(0, 0)]
        case .horizontalTwo: points = [(0, 0), (1, 0)]
        case .verticalTwo: points = [(0, 0), (0, 1)]
        case .horizontalThree: points = [(0, 0), (1, 0), (2, 0)]
        case .verticalThree: points = [(0, 0), (0, 1), (0, 2)]
        case .smallL: points = [(0, 0), (0, 1), (1, 1)]
        case .smallJ: points = [(1, 0), (0, 1), (1, 1)]
        case .smallCorner: points = [(0, 0), (1, 0), (0, 1)]
        case .smallHook: points = [(0, 0), (1, 0), (1, 1)]
        case .square: points = [(0, 0), (1, 0), (0, 1), (1, 1)]
        case .horizontalFour: points = [(0, 0), (1, 0), (2, 0), (3, 0)]
        case .verticalFour: points = [(0, 0), (0, 1), (0, 2), (0, 3)]
        case .tee: points = [(0, 0), (1, 0), (2, 0), (1, 1)]
        case .upsideDownTee: points = [(1, 0), (0, 1), (1, 1), (2, 1)]
        case .leftTee: points = [(1, 0), (0, 1), (1, 1), (1, 2)]
        case .rightTee: points = [(0, 0), (0, 1), (1, 1), (0, 2)]
        case .tallL: points = [(0, 0), (0, 1), (0, 2), (1, 2)]
        case .tallJ: points = [(1, 0), (1, 1), (0, 2), (1, 2)]
        case .horizontalFive: points = [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)]
        case .verticalFive: points = [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)]
        case .cross: points = [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)]
        }
        return points.map { Cell(x: $0.0, y: $0.1) }
    }

    public var description: String {
        switch self {
        case .single: "one square"
        case .horizontalTwo: "two squares across"
        case .verticalTwo: "two squares down"
        case .horizontalThree: "three squares across"
        case .verticalThree: "three squares down"
        case .smallL: "small L, corner at bottom left"
        case .smallJ: "small L, corner at bottom right"
        case .smallCorner: "small L, corner at top left"
        case .smallHook: "small L, corner at top right"
        case .square: "two by two square"
        case .horizontalFour: "four squares across"
        case .verticalFour: "four squares down"
        case .tee: "T, stem down"
        case .upsideDownTee: "T, stem up"
        case .leftTee: "T, stem left"
        case .rightTee: "T, stem right"
        case .tallL: "tall L, corner at bottom left"
        case .tallJ: "tall L, corner at bottom right"
        case .horizontalFive: "five squares across"
        case .verticalFive: "five squares down"
        case .cross: "five-square cross"
        }
    }
}

public struct EndlessPiece: Codable, Equatable, Sendable {
    public let shape: EndlessShape
    public let colorIndex: Int
    public init(shape: EndlessShape, colorIndex: Int) {
        self.shape = shape
        self.colorIndex = colorIndex
    }
    public var cells: [Cell] { shape.cells }
    public var isValid: Bool { (0..<6).contains(colorIndex) }
}

public struct EndlessMove: Equatable, Sendable {
    public let points: Int
    public let rows: [Int]
    public let columns: [Int]
    public let clearedCells: [Cell]
    public var lineCount: Int { rows.count + columns.count }
}

public struct EndlessHint: Equatable, Sendable {
    public let slot: Int
    public let origin: Cell
}

public struct EndlessState: Codable, Equatable, Sendable {
    public static let side = 8
    public static let scoreLimit = 1_000_000_000_000
    public static let countLimit = 1_000_000_000
    public private(set) var board: [Int]
    public private(set) var tray: [EndlessPiece?]
    public private(set) var score: Int
    public private(set) var linesCleared: Int
    public private(set) var placements: Int
    public private(set) var rngState: UInt64

    public init(seed: UInt64) {
        board = Array(repeating: 0, count: Self.side * Self.side)
        tray = []
        score = 0
        linesCleared = 0
        placements = 0
        rngState = seed
        refill()
    }

    public init(board: [Int], tray: [EndlessPiece?], score: Int = 0,
                linesCleared: Int = 0, placements: Int = 0, rngState: UInt64 = 0) {
        self.board = board
        self.tray = tray
        self.score = score
        self.linesCleared = linesCleared
        self.placements = placements
        self.rngState = rngState
    }

    public var isValid: Bool {
        guard board.count == 64, board.allSatisfy({ (0...6).contains($0) }),
              tray.count == 3, tray.contains(where: { $0 != nil }),
              tray.compactMap({ $0 }).allSatisfy(\.isValid),
              (0...Self.scoreLimit).contains(score), score.isMultiple(of: 10),
              (0...Self.countLimit).contains(placements),
              (0...Self.countLimit).contains(linesCleared),
              score - linesCleared * 100 >= placements * 10,
              score - linesCleared * 100 <= placements * 50,
              occupiedCount <= (score - linesCleared * 100) / 10,
              (score - linesCleared * 100) / 10 - occupiedCount >= linesCleared * 4,
              (score - linesCleared * 100) / 10 - occupiedCount <= linesCleared * 8,
              tray.compactMap({ $0 }).count == 3 - placements % 3,
              linesCleared <= placements * 6 else { return false }
        // Every completed line is cleared as part of the same placement.
        return fullRows(in: board).isEmpty && fullColumns(in: board).isEmpty
    }

    public var occupiedCount: Int { board.filter { $0 != 0 }.count }
    public var remainingSlots: [Int] { tray.indices.filter { tray[$0] != nil } }
    public var isGameOver: Bool {
        guard isValid, placements < Self.countLimit, score <= Self.scoreLimit - 1_650,
              linesCleared <= Self.countLimit - 16 else { return true }
        return hint() == nil
    }

    public func canPlace(slot: Int, origin: Cell) -> Bool {
        guard board.count == 64, tray.count == 3, (0..<3).contains(slot),
              let piece = tray[slot], piece.isValid,
              (0..<Self.side).contains(origin.x), (0..<Self.side).contains(origin.y) else { return false }
        return piece.cells.allSatisfy { cell in
            let x = origin.x + cell.x
            let y = origin.y + cell.y
            return x < Self.side && y < Self.side && board[y * Self.side + x] == 0
        }
    }

    public func hint(preferredSlot: Int? = nil) -> EndlessHint? {
        guard board.count == 64, tray.count == 3 else { return nil }
        let slots: [Int]
        if let preferredSlot, remainingSlots.contains(preferredSlot) {
            slots = [preferredSlot] + remainingSlots.filter { $0 != preferredSlot }
        } else { slots = remainingSlots }
        for slot in slots {
            for y in 0..<Self.side {
                for x in 0..<Self.side {
                    let origin = Cell(x: x, y: y)
                    if canPlace(slot: slot, origin: origin) { return EndlessHint(slot: slot, origin: origin) }
                }
            }
        }
        return nil
    }

    @discardableResult public mutating func place(slot: Int, origin: Cell) -> EndlessMove? {
        guard isValid, !isGameOver, canPlace(slot: slot, origin: origin), let piece = tray[slot] else { return nil }
        var candidate = self
        for cell in piece.cells {
            candidate.board[(origin.y + cell.y) * Self.side + origin.x + cell.x] = piece.colorIndex + 1
        }
        let rows = fullRows(in: candidate.board)
        let columns = fullColumns(in: candidate.board)
        var cleared: [Cell] = []
        for y in 0..<Self.side {
            for x in 0..<Self.side where rows.contains(y) || columns.contains(x) {
                candidate.board[y * Self.side + x] = 0
                cleared.append(Cell(x: x, y: y))
            }
        }
        let points = piece.cells.count * 10 + (rows.count + columns.count) * 100
        candidate.score += points
        candidate.linesCleared += rows.count + columns.count
        candidate.placements += 1
        candidate.tray[slot] = nil
        if candidate.tray.allSatisfy({ $0 == nil }) { candidate.refill() }
        guard candidate.isValid else { return nil }
        self = candidate
        return EndlessMove(points: points, rows: rows, columns: columns, clearedCells: cleared)
    }

    private mutating func refill() {
        var random = SeededRandom(state: rngState)
        tray = (0..<3).map { _ in
            EndlessPiece(shape: EndlessShape.allCases[random.index(EndlessShape.allCases.count)],
                         colorIndex: random.index(6))
        }
        rngState = random.state
    }

    private func fullRows(in cells: [Int]) -> [Int] {
        (0..<Self.side).filter { y in (0..<Self.side).allSatisfy { x in cells[y * Self.side + x] != 0 } }
    }

    private func fullColumns(in cells: [Int]) -> [Int] {
        (0..<Self.side).filter { x in (0..<Self.side).allSatisfy { y in cells[y * Self.side + x] != 0 } }
    }
}
