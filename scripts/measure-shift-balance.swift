import Foundation

@main struct ShiftBalance {
    static func main() throws {
        let samples = CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 100
        for number in 1...10 {
            var coreScores: [Int] = [], expertScores: [Int] = [], references: [Int] = []
            var corePassed = 0, expertPassed = 0
            var worstMs = 0.0
            for seed in 1...max(1, samples) {
                var core = ShiftRun(runSeed: UInt64(seed), startingShift: number)
                var expert = core
                for box in 0..<5 {
                    for placement in core.box.coreSolution { precondition(core.place(placement)) }
                    precondition(core.seal() != nil)
                    let started = Date()
                    let due = Set(expert.parcels.filter { $0.dueBox == box }.map(\.id))
                    let ordinary = ShiftSolver.bestFullBox(width: expert.width, height: expert.height, parcels: expert.parcels)
                    let required = due.isEmpty ? ordinary : ShiftSolver.bestFullBox(width: expert.width, height: expert.height, parcels: expert.parcels, mustInclude: due)
                    var choices: [ShiftRun] = []
                    for solution in [ordinary, required].compactMap({ $0 }) {
                        precondition(solution.exhaustive)
                        var attempt = expert
                        for placement in solution.placements { precondition(attempt.place(placement)) }
                        let leftovers = attempt.parcels.filter { !attempt.isPacked($0.id) }.sorted {
                            let aRush = ($0.dueBox ?? -1) > box, bRush = ($1.dueBox ?? -1) > box
                            if aRush != bRush { return aRush }
                            if $0.value != $1.value { return $0.value > $1.value }
                            if $0.cells.count != $1.cells.count { return $0.cells.count < $1.cells.count }
                            return $0.id < $1.id
                        }
                        for parcel in leftovers.prefix(ShiftRun.shelfCapacity) { _ = attempt.shelve(parcel.id) }
                        precondition(attempt.seal() != nil)
                        choices.append(attempt)
                    }
                    expert = choices.max(by: { $0.shiftScore < $1.shiftScore }) ?? expert
                    if expert.phase == .packing { _ = expert.seal() }
                    worstMs = max(worstMs, Date().timeIntervalSince(started) * 1000)
                    if box < 4 { precondition(core.nextBox()); precondition(expert.nextBox()) }
                }
                coreScores.append(core.shiftScore); expertScores.append(expert.shiftScore); references.append(core.plan.reference)
                corePassed += core.phase == .cleared ? 1 : 0
                expertPassed += expert.phase == .cleared ? 1 : 0
            }
            let ratios = zip(expertScores, references).map { Double($0) / Double($1) }.sorted()
            let thresholds = [80, 100, 120, 135, 145, 150, 155, 160, 165, 170].map { pct in
                zip(expertScores, references).filter { $0 >= ($1 * pct + 99) / 100 }.count
            }
            let report: [String: Any] = ["shift": number, "samples": max(1, samples),
                "targetPercent": ShiftPlan.targetPercent(for: number), "corePassed": corePassed, "expertPassed": expertPassed,
                "expertReferenceRatio": ["min": ratios.first!, "median": ratios[ratios.count/2], "max": ratios.last!],
                "expertPassAtPercent": Dictionary(uniqueKeysWithValues: zip([80,100,120,135,145,150,155,160,165,170].map(String.init), thresholds)),
                "worstExpertBoxMs": worstMs]
            let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
            print(String(decoding: data, as: UTF8.self))
        }
    }
}
