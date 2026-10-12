import Foundation

// MARK: - Parcels and boxes

public struct ShiftParcel: Identifiable, Equatable, Codable, Sendable {
    public let id: Int
    public let cells: [Cell]        // normalized, rotation 0 as presented
    public let colorIndex: Int      // 0..<6
    public let value: Int           // 1...4
    public let dueBox: Int?         // rush deadline: box index (0...4) whose seal it must ship by; nil = not rush

    public init(id: Int, cells: [Cell], colorIndex: Int, value: Int, dueBox: Int?) {
        self.id = id
        self.cells = cells
        self.colorIndex = colorIndex
        self.value = value
        self.dueBox = dueBox
    }

    public var isRush: Bool { dueBox != nil }

    public func cells(rotation: Int) -> [Cell] { turn(cells, rotation: rotation) }
}

public struct ShiftBox: Equatable, Codable, Sendable {
    public let size: BoxSize
    public let parcels: [ShiftParcel]     // arrivals, already shuffled
    public let coreSolution: [Placement]  // reference exact fill using the core parcels

    public init(size: BoxSize, parcels: [ShiftParcel], coreSolution: [Placement]) {
        self.size = size
        self.parcels = parcels
        self.coreSolution = coreSolution
    }

    public var width: Int { size.width }
    public var height: Int { size.height }

    public var coreValue: Int {
        var total = 0
        for placement in coreSolution {
            if let parcel = parcels.first(where: { $0.id == placement.parcelID }) {
                total += parcel.value
            }
        }
        return total
    }
}

// MARK: - Plan generation

public struct ShiftPlan: Equatable, Codable, Sendable {
    public static let boxesPerShift: Int = 5

    // Tuning tables. Index = shift number - 1 for targets, parcel size for values.
    private static let targetPercents: [Int] = [80, 95, 105, 115, 120]
    private static let coreBaseValues: [Int] = [0, 0, 1, 1, 2, 2]
    private static let extraBaseValues: [Int] = [0, 0, 0, 2, 3, 3]

    public let seed: UInt64
    public let number: Int                // 1-based shift number
    public let boxes: [ShiftBox]
    public let target: Int
    public let fixedOrientations: Bool? // Missing in legacy saves that allowed turning.
    public var isFixedOrientation: Bool { fixedOrientations == true }

    public var reference: Int {
        var total = 0
        for box in boxes { total += 2 * box.coreValue }
        return total
    }

    public static func targetPercent(for number: Int) -> Int {
        let shift = min(max(number, 1), 1_000)
        if shift <= targetPercents.count { return targetPercents[shift - 1] }
        return min(130, 120 + 5 * (shift - 5))
    }

    public static func generate(seed: UInt64, number: Int, fixedOrientations: Bool = true) -> ShiftPlan {
        let shift = max(number, 1)
        let sizes: [BoxSize] = shift == 1 ? [.small, .medium, .medium, .large, .large] : [.medium, .large, .medium, .large, .large]
        let extrasCount = shift == 1 ? 2 : 3
        let rushChance = min(40 + 10 * (min(shift, 10) - 2), 90)
        var rng = SeededRandom(state: seed)
        var boxes: [ShiftBox] = []
        var referenceTotal = 0
        for boxIndex in 0..<boxesPerShift {
            let box = makeBox(size: sizes[boxIndex], boxIndex: boxIndex, number: shift,
                              extrasCount: extrasCount, rushChance: rushChance, fixedOrientations: fixedOrientations, rng: &rng)
            referenceTotal += 2 * box.coreValue
            boxes.append(box)
        }
        let target = (referenceTotal * targetPercent(for: shift) + 99) / 100
        return ShiftPlan(seed: seed, number: shift, boxes: boxes, target: target, fixedOrientations: fixedOrientations)
    }

    // RNG order per box: partition, core values, core rotations, extras (size, shape, value, rotation),
    // rush, then Fisher-Yates shuffle of the assembled list.
    private static func makeBox(size: BoxSize, boxIndex: Int, number: Int, extrasCount: Int,
                                rushChance: Int, fixedOrientations: Bool, rng: inout SeededRandom) -> ShiftBox {
        let regions = partition(width: size.width, height: size.height, rng: &rng)
        let base = boxIndex * 32

        var shapes: [[Cell]] = []
        var values: [Int] = []
        var coreSolution: [Placement] = []

        for region in regions {
            let bonus = rng.index(100) < 25 ? 1 : 0
            values.append(coreBaseValues[min(region.count, 5)] + bonus)
        }
        for (position, region) in regions.enumerated() {
            let rotation = rng.index(4) // Keep the legacy RNG order so IDs, values, and rush deadlines match.
            shapes.append(turn(region, rotation: fixedOrientations ? 0 : rotation))
            let origin = Cell(x: region.map(\.x).min() ?? 0, y: region.map(\.y).min() ?? 0)
            coreSolution.append(Placement(parcelID: base + position, origin: origin, rotation: fixedOrientations ? 0 : (4 - rotation) % 4))
        }

        for _ in 0..<extrasCount {
            let extraSize = weighted([(3, 2), (4, 3), (5, 3)], &rng)
            let shape = grow(size: extraSize, rng: &rng)
            let bonus = rng.index(100) < 25 ? 1 : 0
            values.append(min(4, extraBaseValues[min(extraSize, 5)] + bonus))
            let rotation = rng.index(4)
            shapes.append(turn(shape, rotation: rotation))
        }

        var rushPosition: Int? = nil
        let hasRush = number == 1 ? (boxIndex == 2 || boxIndex == 4) : (rng.index(100) < rushChance)
        if hasRush {
            if extrasCount > 0 && rng.index(100) < 50 {
                rushPosition = regions.count + rng.index(extrasCount)
            } else {
                rushPosition = rng.index(regions.count)
            }
        }

        let dueBox = min(boxIndex + 1, boxesPerShift - 1)
        var parcels: [ShiftParcel] = []
        for position in shapes.indices {
            let due: Int? = position == rushPosition ? dueBox : nil
            parcels.append(ShiftParcel(id: base + position, cells: shapes[position], colorIndex: position % 6,
                                       value: values[position], dueBox: due))
        }

        for i in stride(from: parcels.count - 1, through: 1, by: -1) {
            let j = rng.index(i + 1)
            parcels.swapAt(i, j)
        }
        return ShiftBox(size: size, parcels: parcels, coreSolution: coreSolution)
    }

    // Splits the board into connected regions of 2...5 cells. Up to 100 seeded attempts, then rows.
    private static func partition(width: Int, height: Int, rng: inout SeededRandom) -> [[Cell]] {
        let total = width * height
        let sizeWeights: [(Int, Int)] = [(2, 1), (3, 3), (4, 4), (5, 3)]
        for _ in 0..<100 {
            var owner = Array(repeating: -1, count: total)
            var regions: [[Int]] = []
            var remaining = total
            var ok = true
            while remaining > 0 {
                var options: [(Int, Int)] = []
                for entry in sizeWeights where entry.0 <= remaining && (remaining - entry.0 == 0 || remaining - entry.0 >= 2) {
                    options.append(entry)
                }
                guard !options.isEmpty, let start = owner.firstIndex(of: -1) else { ok = false; break }
                let size = weighted(options, &rng)
                let regionID = regions.count
                var region: [Int] = [start]
                owner[start] = regionID
                while region.count < size {
                    var frontier: [Int] = []
                    for cell in region {
                        for neighbour in neighbours(of: cell, width: width, height: height) where owner[neighbour] == -1 {
                            if !frontier.contains(neighbour) { frontier.append(neighbour) }
                        }
                    }
                    if frontier.isEmpty { break }
                    frontier.sort()
                    let pick = frontier[rng.index(frontier.count)]
                    region.append(pick)
                    owner[pick] = regionID
                }
                if region.count < size { ok = false; break }
                // A free cell with no free neighbour is a component of size 1 and could never be covered.
                var stranded = false
                for cell in 0..<total where owner[cell] == -1 {
                    var hasFreeNeighbour = false
                    for neighbour in neighbours(of: cell, width: width, height: height) where owner[neighbour] == -1 {
                        hasFreeNeighbour = true
                    }
                    if !hasFreeNeighbour { stranded = true }
                }
                if stranded { ok = false; break }
                regions.append(region)
                remaining -= size
            }
            if ok {
                var result: [[Cell]] = []
                for region in regions {
                    result.append(region.map { Cell(x: $0 % width, y: $0 / width) })
                }
                return result
            }
        }
        var rows: [[Cell]] = []
        for y in 0..<height {
            var row: [Cell] = []
            for x in 0..<width { row.append(Cell(x: x, y: y)) }
            rows.append(row)
        }
        return rows
    }

    private static func neighbours(of index: Int, width: Int, height: Int) -> [Int] {
        let x = index % width
        let y = index / width
        var result: [Int] = []
        if x > 0 { result.append(index - 1) }
        if x < width - 1 { result.append(index + 1) }
        if y > 0 { result.append(index - width) }
        if y < height - 1 { result.append(index + width) }
        return result
    }

    // Random polyomino of the given size, normalized.
    private static func grow(size: Int, rng: inout SeededRandom) -> [Cell] {
        var cells: [Cell] = [Cell(x: 0, y: 0)]
        while cells.count < size {
            var frontier: [Cell] = []
            for cell in cells {
                let around: [Cell] = [Cell(x: cell.x - 1, y: cell.y), Cell(x: cell.x + 1, y: cell.y),
                                      Cell(x: cell.x, y: cell.y - 1), Cell(x: cell.x, y: cell.y + 1)]
                for candidate in around where !cells.contains(candidate) && !frontier.contains(candidate) {
                    frontier.append(candidate)
                }
            }
            if frontier.isEmpty { break }
            frontier.sort { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            cells.append(frontier[rng.index(frontier.count)])
        }
        return normalized(cells)
    }
}

// Weighted pick: one rng draw over the total weight, then walk the pairs in the given order.
func weighted(_ pairs: [(Int, Int)], _ rng: inout SeededRandom) -> Int {
    var total = 0
    for pair in pairs { total += pair.1 }
    guard total > 0 else { return pairs.last?.0 ?? 0 }
    var roll = rng.index(total)
    for pair in pairs {
        if roll < pair.1 { return pair.0 }
        roll -= pair.1
    }
    return pairs[pairs.count - 1].0
}

// MARK: - Full-box solver

public struct FullBoxSolution: Equatable, Sendable {
    public let value: Int                 // sum of parcel values (NOT doubled)
    public let placements: [Placement]
    public let exhaustive: Bool
}

public enum ShiftSolver: Sendable {
    /// Highest parcel value among exact fills; a capped search returns a valid lower bound.
    public static func bestFullBox(width: Int, height: Int, parcels: [ShiftParcel],
                                   mustInclude: Set<Int> = [], allowRotation: Bool = false) -> FullBoxSolution? {
        guard (1...25).contains(width), (1...25).contains(height), width * height <= 25,
              parcels.count <= 20, Set(parcels.map(\.id)).count == parcels.count,
              mustInclude.isSubset(of: Set(parcels.map(\.id))),
              parcels.allSatisfy({ (1...4).contains($0.value) && (1...5).contains($0.cells.count)
                  && Set($0.cells).count == $0.cells.count }) else { return nil }

        let cellCount = width * height
        let fullMask: UInt64 = (1 << cellCount) - 1
        var options: [SolverOption] = []
        var cellOptions = Array(repeating: [Int](), count: cellCount)
        var mustMask: UInt64 = 0
        for (index, parcel) in parcels.enumerated() {
            if mustInclude.contains(parcel.id) { mustMask |= 1 << index }
            var shapes = Set<[Cell]>()
            for rotation in 0..<(allowRotation ? 4 : 1) {
                let shape = turn(parcel.cells, rotation: rotation)
                guard !shape.isEmpty, shapes.insert(shape).inserted else { continue }
                let shapeWidth = (shape.map(\.x).max() ?? 0) + 1
                let shapeHeight = (shape.map(\.y).max() ?? 0) + 1
                guard shapeWidth <= width, shapeHeight <= height else { continue }
                for y in 0...(height - shapeHeight) {
                    for x in 0...(width - shapeWidth) {
                        var mask: UInt64 = 0
                        let indices = shape.map { (y + $0.y) * width + x + $0.x }
                        for cell in indices { mask |= 1 << cell }
                        let option = options.count
                        options.append(SolverOption(mask: mask, parcelIndex: index, value: parcel.value,
                            placement: Placement(parcelID: parcel.id, origin: Cell(x: x, y: y), rotation: rotation)))
                        for cell in indices { cellOptions[cell].append(option) }
                    }
                }
            }
        }
        for cell in cellOptions.indices {
            cellOptions[cell].sort {
                if options[$0].value != options[$1].value { return options[$0].value > options[$1].value }
                return $0 < $1
            }
        }
        var search = ShiftSearch(fullMask: fullMask, mustMask: mustMask, cellCount: cellCount,
            options: options, cellOptions: cellOptions,
            areas: parcels.map { $0.cells.count }, values: parcels.map(\.value))
        search.complete(mask: 0, used: 0, value: 0)
        guard search.bestValue >= 0 else { return nil }
        return FullBoxSolution(value: search.bestValue,
            placements: search.bestPath.map { options[$0].placement }, exhaustive: search.exhaustive)
    }
}

private struct SolverOption {
    let mask: UInt64
    let parcelIndex: Int
    let value: Int
    let placement: Placement
}

private struct ShiftSearch {
    static let nodeCap = 500_000
    let fullMask: UInt64
    let mustMask: UInt64
    let cellCount: Int
    let options: [SolverOption]
    let cellOptions: [[Int]]
    let areas: [Int]
    let values: [Int]
    var bounds: [UInt64: Int] = [:]
    var visited = Set<UInt64>()
    var path: [Int] = []
    var bestPath: [Int] = []
    var bestValue = -1
    var nodes = 0
    var exhaustive = true

    // Ignore shapes but require the remaining parcel areas to fill the remaining capacity exactly.
    // This can overestimate the achievable value, so pruning cannot discard a better real fill.
    mutating func upperBound(used: UInt64) -> Int {
        if let cached = bounds[used] { return cached }
        var capacity = cellCount
        var requiredValue = 0
        for i in areas.indices {
            let bit: UInt64 = 1 << i
            if used & bit != 0 { capacity -= areas[i] }
            else if mustMask & bit != 0 {
                capacity -= areas[i]
                requiredValue += values[i]
            }
        }
        guard capacity >= 0 else { bounds[used] = -1; return -1 }
        var dp = Array(repeating: -1, count: capacity + 1)
        dp[0] = 0
        for i in areas.indices where used & (1 << i) == 0 && mustMask & (1 << i) == 0 {
            let area = areas[i]
            guard area <= capacity else { continue }
            for space in stride(from: capacity, through: area, by: -1) where dp[space - area] >= 0 {
                dp[space] = max(dp[space], dp[space - area] + values[i])
            }
        }
        let bound = dp[capacity] < 0 ? -1 : requiredValue + dp[capacity]
        bounds[used] = bound
        return bound
    }

    mutating func complete(mask: UInt64, used: UInt64, value: Int) {
        if mask == fullMask {
            if used & mustMask == mustMask && value > bestValue {
                bestValue = value
                bestPath = path
            }
            return
        }
        let bound = upperBound(used: used)
        guard bound >= 0, value + bound > bestValue else { return }
        let key = mask | (used << 25)
        guard !visited.contains(key) else { return }
        guard nodes < Self.nodeCap else { exhaustive = false; return }
        nodes += 1
        visited.insert(key)

        var branch: [Int] = []
        var fewest = Int.max
        for cell in 0..<cellCount where mask & (1 << cell) == 0 {
            let candidates = cellOptions[cell].filter {
                let option = options[$0]
                return option.mask & mask == 0 && used & (1 << option.parcelIndex) == 0
            }
            guard !candidates.isEmpty else { return }
            if candidates.count < fewest {
                fewest = candidates.count
                branch = candidates
            }
        }
        for i in branch {
            let option = options[i]
            path.append(i)
            complete(mask: mask | option.mask, used: used | (1 << option.parcelIndex), value: value + option.value)
            path.removeLast()
            if !exhaustive { return }
        }
    }
}

// MARK: - Shift run

public struct BoxResult: Equatable, Codable, Sendable {
    public let boxIndex: Int
    public let packedValue: Int
    public let full: Bool
    public let lateFees: Int
    public let lateCount: Int
    public let returnedCount: Int
    public let bestFull: Int?             // best possible full-box score (value * 2); nil if impossible

    public init(boxIndex: Int, packedValue: Int, full: Bool, lateFees: Int, lateCount: Int,
                returnedCount: Int, bestFull: Int?) {
        self.boxIndex = boxIndex
        self.packedValue = packedValue
        self.full = full
        self.lateFees = lateFees
        self.lateCount = lateCount
        self.returnedCount = returnedCount
        self.bestFull = bestFull
    }

    public var score: Int { packedValue * (full ? 2 : 1) - lateFees }
}

public enum ShiftPhase: String, Equatable, Codable, Sendable { case packing, sealed, cleared, failed }
public enum ParcelLocation: Equatable, Sendable { case tray, shelf, box }

public struct ShiftRun: Equatable, Codable, Sendable {
    public static let shelfCapacity: Int = 3
    public static let lateFee: Int = 5

    public private(set) var runSeed: UInt64
    public private(set) var plan: ShiftPlan
    public private(set) var boxIndex: Int
    public private(set) var parcels: [ShiftParcel]   // in play: shelf carry-over first, then arrivals
    public private(set) var shelfIDs: [Int]
    public private(set) var placements: [Placement]
    public private(set) var phase: ShiftPhase
    public private(set) var shiftScore: Int
    public private(set) var runScore: Int
    public private(set) var shiftsCleared: Int
    public private(set) var results: [BoxResult]     // this shift's sealed boxes

    public init(runSeed: UInt64, startingShift: Int = 1, fixedOrientations: Bool = true) {
        let number = max(startingShift, 1)
        let firstPlan = ShiftPlan.generate(seed: ShiftRun.planSeed(runSeed: runSeed, number: number), number: number, fixedOrientations: fixedOrientations)
        self.runSeed = runSeed
        self.plan = firstPlan
        self.boxIndex = 0
        self.parcels = firstPlan.boxes[0].parcels
        self.shelfIDs = []
        self.placements = []
        self.phase = .packing
        self.shiftScore = 0
        self.runScore = 0
        self.shiftsCleared = 0
        self.results = []
    }

    public static func planSeed(runSeed: UInt64, number: Int) -> UInt64 {
        var rng = SeededRandom(state: runSeed ^ (UInt64(max(number, 1)) &* 0x9E3779B97F4A7C15))
        return rng.next()
    }

    public var box: ShiftBox {
        if plan.boxes.indices.contains(boxIndex) { return plan.boxes[boxIndex] }
        return ShiftBox(size: .small, parcels: [], coreSolution: [])
    }

    public var width: Int { box.width }
    public var height: Int { box.height }

    public var occupiedCount: Int { occupiedCells().count }

    public var isFull: Bool { occupiedCount == width * height }

    public var lastResult: BoxResult? { results.last }

    public var trayParcels: [ShiftParcel] {
        var result: [ShiftParcel] = []
        for item in parcels where !shelfIDs.contains(item.id) { result.append(item) }
        return result
    }

    public var shelfParcels: [ShiftParcel] {
        var result: [ShiftParcel] = []
        for id in shelfIDs {
            if let item = parcel(id) { result.append(item) }
        }
        return result
    }

    public func parcel(_ id: Int) -> ShiftParcel? {
        parcels.first(where: { $0.id == id })
    }

    public func location(of id: Int) -> ParcelLocation? {
        if isPacked(id) { return .box }
        if shelfIDs.contains(id) { return .shelf }
        if parcel(id) != nil { return .tray }
        return nil
    }

    public func isPacked(_ id: Int) -> Bool {
        placements.contains(where: { $0.parcelID == id })
    }

    public func boxesUntilDue(_ id: Int) -> Int? {
        guard let due = parcel(id)?.dueBox else { return nil }
        return due - boxIndex
    }

    // Board footprint of a placement, or [] if the rotation, parcel or position is invalid.
    public func cells(for placement: Placement) -> [Cell] {
        guard (!plan.isFixedOrientation || placement.rotation == 0),
              (0..<4).contains(placement.rotation), let found = parcel(placement.parcelID) else { return [] }
        let boardWidth = width
        let boardHeight = height
        guard (0..<boardWidth).contains(placement.origin.x), (0..<boardHeight).contains(placement.origin.y) else { return [] }
        let shape = found.cells(rotation: placement.rotation)
        guard !shape.isEmpty, shape.count == found.cells.count, Set(shape).count == shape.count else { return [] }
        var result: [Cell] = []
        for cell in shape {
            let x = placement.origin.x + cell.x
            let y = placement.origin.y + cell.y
            guard x >= 0, x < boardWidth, y >= 0, y < boardHeight else { return [] }
            result.append(Cell(x: x, y: y))
        }
        return result
    }

    public func canPlace(_ placement: Placement) -> Bool {
        guard phase == .packing, !isPacked(placement.parcelID) else { return false }
        let footprint = cells(for: placement)
        guard !footprint.isEmpty else { return false }
        let occupied = occupiedCells()
        for cell in footprint where occupied.contains(cell) { return false }
        return true
    }

    @discardableResult
    public mutating func place(_ placement: Placement) -> Bool {
        guard canPlace(placement) else { return false }
        placements.append(placement)
        shelfIDs.removeAll(where: { $0 == placement.parcelID })
        return true
    }

    @discardableResult
    public mutating func remove(parcelID: Int) -> Bool {
        guard phase == .packing else { return false }
        let before = placements.count
        placements.removeAll(where: { $0.parcelID == parcelID })
        return placements.count != before
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard phase == .packing else { return false }
        return placements.popLast() != nil
    }

    @discardableResult
    public mutating func shelve(_ id: Int) -> Bool {
        guard phase == .packing, shelfIDs.count < ShiftRun.shelfCapacity, !shelfIDs.contains(id),
              parcel(id) != nil, !isPacked(id) else { return false }
        shelfIDs.append(id)
        return true
    }

    // Unshelving is limited to packing: after a seal, the shelf is what carries over to the next box.
    @discardableResult
    public mutating func unshelve(_ id: Int) -> Bool {
        guard phase == .packing, shelfIDs.contains(id) else { return false }
        shelfIDs.removeAll(where: { $0 == id })
        return true
    }

    @discardableResult
    public mutating func seal() -> BoxResult? {
        guard phase == .packing else { return nil }
        let packedIDs = placements.map(\.parcelID)
        var packedValue = 0
        for item in parcels where packedIDs.contains(item.id) { packedValue += item.value }
        let full = occupiedCount == width * height

        var lateCount = 0
        var returnedCount = 0
        var lateShelfIDs: [Int] = []
        for item in parcels where !packedIDs.contains(item.id) {
            if shelfIDs.contains(item.id) {
                if let due = item.dueBox, due <= boxIndex {
                    lateCount += 1
                    lateShelfIDs.append(item.id)
                }
            } else if item.dueBox != nil {
                lateCount += 1
            } else {
                returnedCount += 1
            }
        }
        let lateFees = ShiftRun.lateFee * lateCount
        // Late shelf parcels were still packable this box, so they count toward the best fill.
        let solution = ShiftSolver.bestFullBox(width: width, height: height, parcels: parcels, mustInclude: [], allowRotation: !plan.isFixedOrientation)
        let bestFull: Int? = solution.flatMap { $0.exhaustive ? $0.value * 2 : nil }
        shelfIDs.removeAll(where: { lateShelfIDs.contains($0) })
        parcels.removeAll(where: { lateShelfIDs.contains($0.id) })

        let result = BoxResult(boxIndex: boxIndex, packedValue: packedValue, full: full, lateFees: lateFees,
                               lateCount: lateCount, returnedCount: returnedCount, bestFull: bestFull)
        shiftScore += result.score
        runScore += result.score
        results.append(result)
        if boxIndex < ShiftPlan.boxesPerShift - 1 {
            phase = .sealed
        } else if shiftScore >= plan.target {
            phase = .cleared
            shiftsCleared += 1
        } else {
            phase = .failed
        }
        return result
    }

    @discardableResult
    public mutating func nextBox() -> Bool {
        guard phase == .sealed, boxIndex + 1 < plan.boxes.count else { return false }
        let carried = shelfParcels
        boxIndex += 1
        parcels = carried + plan.boxes[boxIndex].parcels
        placements = []
        phase = .packing
        useFixedOrientations()
        return true
    }

    /// Upgrade a packing box while leaving shipped snapshots and earned scores untouched.
    @discardableResult public mutating func useFixedOrientations() -> Bool {
        guard phase == .packing, !plan.isFixedOrientation, isValid else { return false }
        let generated = ShiftPlan.generate(seed: plan.seed, number: plan.number)
        let updated = ShiftPlan(seed: plan.seed, number: plan.number, boxes: generated.boxes,
                                target: plan.target, fixedOrientations: true)
        let definitions = Dictionary(uniqueKeysWithValues: updated.boxes.flatMap(\.parcels).map { ($0.id, $0) })
        let retained = placements.compactMap { placement -> Placement? in
            guard let before = parcel(placement.parcelID), let after = definitions[placement.parcelID],
                  before.cells(rotation: placement.rotation) == after.cells else { return nil }
            return Placement(parcelID: placement.parcelID, origin: placement.origin, rotation: 0)
        }
        parcels = parcels.compactMap { definitions[$0.id] }
        plan = updated
        placements = retained
        return true
    }

    @discardableResult
    public mutating func nextShift() -> Bool {
        guard phase == .cleared, plan.number < Int.max else { return false }
        let number = plan.number + 1
        plan = ShiftPlan.generate(seed: ShiftRun.planSeed(runSeed: runSeed, number: number), number: number)
        boxIndex = 0
        parcels = plan.boxes[0].parcels
        shelfIDs = []
        placements = []
        shiftScore = 0
        results = []
        phase = .packing
        return true
    }

    // Persistence check. Scores may be negative (late fees), so only their bounds and consistency are checked.
    public var isValid: Bool {
        guard plan.number >= 1, plan.number < Int.max - 1,
              plan.seed == Self.planSeed(runSeed: runSeed, number: plan.number) else { return false }
        let regenerated = ShiftPlan.generate(seed: plan.seed, number: plan.number, fixedOrientations: plan.isFixedOrientation)
        guard regenerated.number == plan.number, regenerated.seed == plan.seed, regenerated.boxes == plan.boxes,
              plan.target > 0, plan.target <= regenerated.reference * 2,
              (0..<ShiftPlan.boxesPerShift).contains(boxIndex) else { return false }

        let lastBox = boxIndex == ShiftPlan.boxesPerShift - 1
        switch phase {
        case .packing: break
        case .sealed: if lastBox { return false }
        case .cleared, .failed: if !lastBox { return false }
        }

        let parcelIDs = Set(parcels.map(\.id))
        guard parcelIDs.count == parcels.count, parcels.count <= box.parcels.count + Self.shelfCapacity else { return false }
        if phase == .packing && !Set(box.parcels.map(\.id)).isSubset(of: parcelIDs) { return false }
        for item in parcels {
            var arrived = false
            for k in 0...boxIndex where plan.boxes[k].parcels.contains(item) { arrived = true }
            guard arrived else { return false }
        }

        guard shelfIDs.count <= ShiftRun.shelfCapacity, Set(shelfIDs).count == shelfIDs.count else { return false }
        for id in shelfIDs where !parcelIDs.contains(id) { return false }

        guard placements.count <= parcels.count else { return false }
        var placedIDs = Set<Int>()
        var occupied = Set<Cell>()
        for placement in placements {
            guard placedIDs.insert(placement.parcelID).inserted, parcelIDs.contains(placement.parcelID),
                  !shelfIDs.contains(placement.parcelID) else { return false }
            let footprint = cells(for: placement)
            guard !footprint.isEmpty else { return false }
            for cell in footprint {
                guard occupied.insert(cell).inserted else { return false }
            }
        }

        guard results.count == boxIndex + (phase == .packing ? 0 : 1) else { return false }
        var scoreSum = 0
        for (index, result) in results.enumerated() {
            guard result.boxIndex == index, (0...1_000).contains(result.packedValue),
                  (0...50).contains(result.lateCount), (0...50).contains(result.returnedCount),
                  result.lateFees == ShiftRun.lateFee * result.lateCount else { return false }
            if let best = result.bestFull, !(0...10_000).contains(best) { return false }
            scoreSum += result.score
        }
        guard scoreSum == shiftScore, shiftsCleared >= 0, shiftsCleared <= plan.number,
              phase != .cleared || shiftScore >= plan.target,
              phase != .failed || shiftScore < plan.target,
              (-1_000_000_000...1_000_000_000).contains(runScore) else { return false }
        return true
    }

    private func occupiedCells() -> Set<Cell> {
        var occupied = Set<Cell>()
        for placement in placements {
            for cell in cells(for: placement) { occupied.insert(cell) }
        }
        return occupied
    }
}
