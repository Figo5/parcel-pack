import Foundation

public struct Cell: Hashable, Codable, Sendable {
    public var x: Int
    public var y: Int
    public init(x: Int, y: Int) { self.x = x; self.y = y }
}

func normalized(_ cells: [Cell]) -> [Cell] {
    guard !cells.isEmpty, cells.count <= 25,
          cells.allSatisfy({ (-64...64).contains($0.x) && (-64...64).contains($0.y) }),
          let minX = cells.map(\.x).min(), let minY = cells.map(\.y).min() else { return [] }
    return cells.map { Cell(x: $0.x - minX, y: $0.y - minY) }
        .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
}

func turn(_ cells: [Cell], rotation: Int) -> [Cell] {
    var result = normalized(cells)
    let turns = ((rotation % 4) + 4) % 4
    for _ in 0..<turns { result = normalized(result.map { Cell(x: -$0.y, y: $0.x) }) }
    return result
}

public struct Parcel: Identifiable, Equatable, Codable, Sendable {
    public let id: Int
    public let cells: [Cell]
    public let colorIndex: Int
    public init(id: Int, cells: [Cell], colorIndex: Int) {
        self.id = id; self.cells = cells; self.colorIndex = colorIndex
    }
    public func cells(rotation: Int) -> [Cell] { turn(cells, rotation: rotation) }
}

public enum BoxSize: String, CaseIterable, Codable, Sendable {
    case small, medium, large
    public var width: Int { self == .small ? 4 : 5 }
    public var height: Int { self == .large ? 5 : 4 }
    public var title: String {
        switch self { case .small: "Small"; case .medium: "Medium"; case .large: "Large" }
    }
}

public struct Placement: Equatable, Codable, Sendable {
    public let parcelID: Int
    public let origin: Cell
    public let rotation: Int
    public init(parcelID: Int, origin: Cell, rotation: Int) {
        self.parcelID = parcelID; self.origin = origin; self.rotation = rotation
    }
}

struct SeededRandom {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func index(_ count: Int) -> Int { Int(next() % UInt64(count)) }
}

public struct Puzzle: Equatable, Codable, Sendable {
    public let seed: UInt64
    public let size: BoxSize
    public let parcels: [Parcel]
    public let solution: [Placement]
    public let fixedOrientations: Bool? // Missing in legacy saves that allowed turning.
    public var isFixedOrientation: Bool { fixedOrientations == true }
    public var width: Int { size.width }
    public var height: Int { size.height }

    public init(seed: UInt64, size: BoxSize, parcels: [Parcel], solution: [Placement], fixedOrientations: Bool = true) {
        self.seed = seed; self.size = size; self.parcels = parcels; self.solution = solution
        self.fixedOrientations = fixedOrientations
    }

    public static func generate(seed: UInt64, size: BoxSize, fixedOrientations: Bool = true) -> Puzzle {
        var random = SeededRandom(state: seed)
        var path: [Cell] = []
        for y in 0..<size.height {
            let xs = y.isMultiple(of: 2) ? Array(0..<size.width) : Array((0..<size.width).reversed())
            path += xs.map { Cell(x: $0, y: y) }
        }
        // Backbite moves preserve a path visiting every board square exactly once.
        for _ in 0..<600 {
            let fromStart = random.index(2) == 0
            let endpoint = fromStart ? path[0] : path[path.count - 1]
            let neighbors = path.indices.filter { i in
                abs(path[i].x - endpoint.x) + abs(path[i].y - endpoint.y) == 1
                    && (fromStart ? i > 1 : i < path.count - 2)
            }
            guard !neighbors.isEmpty else { continue }
            let i = neighbors[random.index(neighbors.count)]
            if fromStart {
                path = Array(path[..<i].reversed()) + Array(path[i...])
            } else {
                path = Array(path[...i]) + Array(path[(i + 1)...].reversed())
            }
        }
        let pieceArea = size == .large ? 5 : 4
        var parcels: [Parcel] = []
        var solution: [Placement] = []
        for start in stride(from: 0, to: path.count, by: pieceArea) {
            let region = Array(path[start..<(start + pieceArea)])
            let origin = Cell(x: region.map(\.x).min()!, y: region.map(\.y).min()!)
            let rotation = random.index(4) // Keep the legacy RNG order for saved-box migration.
            let id = parcels.count
            parcels.append(Parcel(id: id, cells: turn(region, rotation: fixedOrientations ? 0 : rotation), colorIndex: id))
            solution.append(Placement(parcelID: id, origin: origin, rotation: fixedOrientations ? 0 : (4 - rotation) % 4))
        }
        for i in stride(from: parcels.count - 1, through: 1, by: -1) {
            let j = random.index(i + 1)
            parcels.swapAt(i, j)
        }
        return Puzzle(seed: seed, size: size, parcels: parcels, solution: solution, fixedOrientations: fixedOrientations)
    }

    fileprivate var validDefinition: Bool {
        let area = width * height
        guard (1...area).contains(parcels.count), solution.count == parcels.count,
              Set(parcels.map(\.id)).count == parcels.count else { return false }
        var count = 0
        for parcel in parcels {
            guard (0..<64).contains(parcel.id), (0..<6).contains(parcel.colorIndex),
                  (1...5).contains(parcel.cells.count),
                  parcel.cells.allSatisfy({ (0..<width).contains($0.x) && (0..<height).contains($0.y) }),
                  Set(parcel.cells).count == parcel.cells.count,
                  normalized(parcel.cells) == parcel.cells.sorted(by: { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }) else { return false }
            // A parcel must be a single connected piece, not scattered squares.
            let set = Set(parcel.cells)
            var reached: Set<Cell> = [parcel.cells[0]]
            var frontier = [parcel.cells[0]]
            while let cell = frontier.popLast() {
                for next in [Cell(x: cell.x - 1, y: cell.y), Cell(x: cell.x + 1, y: cell.y),
                             Cell(x: cell.x, y: cell.y - 1), Cell(x: cell.x, y: cell.y + 1)] {
                    if set.contains(next) && reached.insert(next).inserted { frontier.append(next) }
                }
            }
            guard reached.count == set.count else { return false }
            count += parcel.cells.count
        }
        guard count == area else { return false }
        return occupancy(solution) != nil && solution.count == parcels.count
    }

    fileprivate func footprint(_ placement: Placement) -> [Cell]? {
        guard !isFixedOrientation || placement.rotation == 0,
              (0..<width).contains(placement.origin.x), (0..<height).contains(placement.origin.y),
              let parcel = parcels.first(where: { $0.id == placement.parcelID }),
              (1...5).contains(parcel.cells.count) else { return nil }
        let cells = parcel.cells(rotation: placement.rotation)
        guard cells.count == parcel.cells.count, Set(cells).count == cells.count,
              cells.allSatisfy({ $0.x >= 0 && $0.x < width - placement.origin.x
                  && $0.y >= 0 && $0.y < height - placement.origin.y }) else { return nil }
        return cells.map { Cell(x: placement.origin.x + $0.x, y: placement.origin.y + $0.y) }
    }

    fileprivate func occupancy(_ placements: [Placement]) -> UInt64? {
        guard placements.count <= parcels.count else { return nil }
        var mask: UInt64 = 0
        var ids = Set<Int>()
        for placement in placements {
            guard ids.insert(placement.parcelID).inserted, let cells = footprint(placement) else { return nil }
            for cell in cells {
                let bit = UInt64(1) << (cell.y * width + cell.x)
                guard mask & bit == 0 else { return nil }
                mask |= bit
            }
        }
        return mask
    }
}

public struct PackingState: Equatable, Codable, Sendable {
    public let puzzle: Puzzle
    public private(set) var placements: [Placement]

    public init(puzzle: Puzzle, placements: [Placement] = []) {
        self.puzzle = puzzle
        self.placements = []
        guard puzzle.validDefinition else { return }
        for placement in placements.prefix(puzzle.parcels.count) { _ = place(placement) }
    }

    public var isValid: Bool { puzzle.validDefinition && puzzle.occupancy(placements) != nil }
    public var occupiedCount: Int { puzzle.occupancy(placements)?.nonzeroBitCount ?? 0 }
    public var isComplete: Bool {
        isValid && placements.count == puzzle.parcels.count && occupiedCount == puzzle.width * puzzle.height
    }

    public func cells(for placement: Placement) -> [Cell] { puzzle.footprint(placement) ?? [] }

    public func canPlace(_ placement: Placement) -> Bool {
        guard puzzle.validDefinition, !placements.contains(where: { $0.parcelID == placement.parcelID }),
              let used = puzzle.occupancy(placements), let cells = puzzle.footprint(placement) else { return false }
        return cells.allSatisfy { used & (UInt64(1) << ($0.y * puzzle.width + $0.x)) == 0 }
    }

    @discardableResult public mutating func place(_ placement: Placement) -> Bool {
        guard canPlace(placement) else { return false }
        placements.append(placement)
        return true
    }

    public mutating func remove(parcelID: Int) { placements.removeAll { $0.parcelID == parcelID } }
    @discardableResult public mutating func undo() -> Bool { placements.popLast() != nil }
    public mutating func reset() { placements = [] }

    /// Convert a legacy box to its reference orientations, retaining compatible packed footprints.
    public func usingFixedOrientations() -> PackingState {
        guard isValid, !puzzle.isFixedOrientation else { return self }
        let reference = Dictionary(uniqueKeysWithValues: puzzle.solution.map { ($0.parcelID, $0.rotation) })
        let parcels = puzzle.parcels.map {
            Parcel(id: $0.id, cells: $0.cells(rotation: reference[$0.id] ?? 0), colorIndex: $0.colorIndex)
        }
        let solution = puzzle.solution.map { Placement(parcelID: $0.parcelID, origin: $0.origin, rotation: 0) }
        let updated = Puzzle(seed: puzzle.seed, size: puzzle.size, parcels: parcels, solution: solution)
        let retained = placements.compactMap { placement -> Placement? in
            guard let before = puzzle.parcels.first(where: { $0.id == placement.parcelID }),
                  let after = parcels.first(where: { $0.id == placement.parcelID }),
                  before.cells(rotation: placement.rotation) == after.cells else { return nil }
            return Placement(parcelID: placement.parcelID, origin: placement.origin, rotation: 0)
        }
        return PackingState(puzzle: updated, placements: retained)
    }

    public func hint() -> Placement? {
        guard isValid, !isComplete, let occupied = puzzle.occupancy(placements) else { return nil }
        let usedIDs = Set(placements.map(\.parcelID))
        let remaining = puzzle.parcels.filter { !usedIDs.contains($0.id) }
        let full = (UInt64(1) << (puzzle.width * puzzle.height)) - 1
        struct Option { let mask: UInt64; let placement: Placement; let parcelIndex: Int }
        var optionsByCell = Array(repeating: [Option](), count: puzzle.width * puzzle.height)
        for (index, parcel) in remaining.enumerated() {
            var seenShapes = Set<[Cell]>()
            for rotation in 0..<(puzzle.isFixedOrientation ? 1 : 4) {
                let cells = parcel.cells(rotation: rotation)
                guard seenShapes.insert(cells).inserted else { continue }
                let maxX = cells.map(\.x).max()!, maxY = cells.map(\.y).max()!
                for y in 0..<(puzzle.height - maxY) {
                    for x in 0..<(puzzle.width - maxX) {
                        var mask: UInt64 = 0
                        for cell in cells { mask |= UInt64(1) << ((cell.y + y) * puzzle.width + cell.x + x) }
                        guard mask & occupied == 0 else { continue }
                        let option = Option(mask: mask, placement: Placement(parcelID: parcel.id,
                            origin: Cell(x: x, y: y), rotation: rotation), parcelIndex: index)
                        for cell in cells { optionsByCell[(cell.y + y) * puzzle.width + cell.x + x].append(option) }
                    }
                }
            }
        }
        var nodes = 0
        var answer: [Placement] = []
        var failed = Set<UInt64>()
        func solve(_ mask: UInt64, _ used: UInt64) -> Bool {
            nodes += 1
            guard nodes <= 60_000 else { return false }
            if mask == full { return true }
            // Board uses <=25 bits, remaining parcel set uses <=25 bits.
            let key = mask | (used << 25)
            guard !failed.contains(key) else { return false }
            var choices: [Option]?
            for cell in optionsByCell.indices where mask & (UInt64(1) << cell) == 0 {
                let candidates = optionsByCell[cell].filter {
                    $0.mask & mask == 0 && used & (UInt64(1) << $0.parcelIndex) == 0
                }
                if candidates.isEmpty { failed.insert(key); return false }
                if choices == nil || candidates.count < choices!.count { choices = candidates }
                if candidates.count == 1 { break }
            }
            for option in choices ?? [] {
                answer.append(option.placement)
                if solve(mask | option.mask, used | (UInt64(1) << option.parcelIndex)) { return true }
                answer.removeLast()
            }
            failed.insert(key)
            return false
        }
        return solve(occupied, 0) ? answer.first : nil
    }
}
