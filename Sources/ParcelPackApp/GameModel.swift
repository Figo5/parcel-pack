import Foundation
import Observation
#if SWIFT_PACKAGE
import ParcelCore
#endif
#if os(iOS)
import UIKit
import AudioToolbox
#endif

@MainActor @Observable
final class GameModel {
    private(set) var state: PackingState
    var selectedID: Int?
    private(set) var rotations: [Int: Int]
    private(set) var message = "Drag a parcel in, or select one and tap a square."
    private(set) var shipped: Int
    private(set) var boxNumber: Int
    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "parcel-pack.sound") }
    }
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: "parcel-pack.haptics") }
    }
    var showHelp = false
    var showSettings = false
    var pendingSize: BoxSize?
    var showRestart = false

    private var completionCredited: Bool
    private let store: SessionStore
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        store = SessionStore(defaults: defaults)
        let restored = store.load()
        state = restored?.state ?? PackingState(puzzle: .generate(seed: Self.newSeed(), size: .small))
        rotations = restored?.rotations ?? [:]
        let lifetimeCount = defaults.object(forKey: "parcel-pack.shipped.v1") as? Int ?? 0
        shipped = max(restored?.shipped ?? 0, (0..<Int.max).contains(lifetimeCount) ? lifetimeCount : 0)
        boxNumber = restored?.boxNumber ?? 1
        completionCredited = restored?.completionCredited ?? false
        soundEnabled = defaults.bool(forKey: "parcel-pack.sound")
        hapticsEnabled = defaults.object(forKey: "parcel-pack.haptics") as? Bool ?? true
        if state.isComplete {
            message = "A perfect fit. Ready to ship!"
        } else if !state.placements.isEmpty {
            message = "Your box is right where you left it."
        }
        save()
    }

    var availableParcels: [Parcel] {
        state.puzzle.parcels.filter { parcel in
            !state.placements.contains { $0.parcelID == parcel.id }
        }
    }
    var selectedParcel: Parcel? {
        availableParcels.first { $0.id == selectedID }
    }
    var selectedRotation: Int { selectedID.map { rotations[$0] ?? 0 } ?? 0 }
    var filledFraction: Double {
        Double(state.occupiedCount) / Double(state.puzzle.width * state.puzzle.height)
    }

    func select(_ id: Int) {
        guard availableParcels.contains(where: { $0.id == id }) else { return }
        selectedID = id
        message = "Parcel \(id + 1) selected. Tap where its top-left corner should go."
    }

    func rotateSelected() {
        guard let id = selectedID, selectedParcel != nil else {
            message = "Choose a parcel to rotate first."
            return
        }
        rotations[id] = ((rotations[id] ?? 0) + 1) % 4
        message = "Turned a quarter turn. Find its new spot."
        feedback()
        save()
    }

    @discardableResult
    func placeSelected(x: Int, y: Int) -> Bool {
        guard let id = selectedID else {
            message = "Choose a parcel below the box first."
            return false
        }
        return place(parcelID: id, x: x, y: y)
    }

    @discardableResult
    func place(parcelID: Int, x: Int, y: Int) -> Bool {
        let placement = Placement(parcelID: parcelID, origin: Cell(x: x, y: y),
                                  rotation: rotations[parcelID] ?? 0)
        guard state.place(placement) else {
            message = "That spot doesn't fit. Try another square or rotate the parcel."
            feedback(error: true)
            return false
        }
        selectedID = nil
        if state.isComplete {
            creditCompletion()
            message = "A perfect fit. Ready to ship!"
            feedback(complete: true)
        } else {
            message = "Fits nicely. \(availableParcels.count) parcel\(availableParcels.count == 1 ? "" : "s") to go."
            feedback()
        }
        save()
        return true
    }

    func remove(_ id: Int) {
        guard state.placements.contains(where: { $0.parcelID == id }) else { return }
        if let placement = state.placements.first(where: { $0.parcelID == id }) {
            rotations[id] = ((placement.rotation % 4) + 4) % 4
        }
        state.remove(parcelID: id)
        selectedID = id
        message = "Parcel \(id + 1) is back on the table."
        feedback()
        save()
    }

    func undo() {
        guard let last = state.placements.last else {
            message = "No parcels to unpack yet."
            return
        }
        remove(last.parcelID)
    }

    func hint() {
        guard !state.isComplete else { return }
        var candidate = state
        var rewound = 0
        var suggested = candidate.hint()
        while suggested == nil && !candidate.placements.isEmpty {
            _ = candidate.undo()
            rewound += 1
            suggested = candidate.hint()
        }
        // The reference tiling guarantees a bounded fallback on an empty box.
        if suggested == nil && candidate.placements.isEmpty {
            suggested = candidate.puzzle.solution.first
        }
        guard let placement = suggested, candidate.place(placement) else {
            message = "Try unpacking the last parcel, then asking for a hint."
            return
        }
        state = candidate
        rotations[placement.parcelID] = ((placement.rotation % 4) + 4) % 4
        selectedID = nil
        if state.isComplete {
            creditCompletion()
            message = "All packed. A little help still counts!"
            feedback(complete: true)
        } else {
            message = rewound > 0
                ? "Unpacked \(rewound) parcel\(rewound == 1 ? "" : "s") and found a way forward."
                : "One parcel tucked in. You take it from here."
            feedback()
        }
        save()
    }

    func restart() {
        state.reset()
        selectedID = nil
        rotations = [:]
        showRestart = false
        message = "Same box, fresh start."
        save()
    }

    func nextBox() {
        startBox(size: state.puzzle.size)
    }

    func changeSize(_ size: BoxSize) {
        guard size != state.puzzle.size else { return }
        if !state.placements.isEmpty && !state.isComplete {
            pendingSize = size
        } else {
            startBox(size: size)
        }
    }

    func confirmSizeChange() {
        guard let size = pendingSize else { return }
        pendingSize = nil
        startBox(size: size)
    }

    func save() {
        defaults.set(shipped, forKey: "parcel-pack.shipped.v1")
        store.save(SavedSession(state: state, rotations: rotations, shipped: shipped,
                                boxNumber: boxNumber, completionCredited: completionCredited))
    }

    private func startBox(size: BoxSize) {
        state = PackingState(puzzle: .generate(seed: Self.newSeed(), size: size))
        selectedID = nil
        rotations = [:]
        completionCredited = false
        if boxNumber < Int.max - 1 { boxNumber += 1 }
        showSettings = false
        message = "A new box. There's a place for every parcel."
        save()
    }

    private func creditCompletion() {
        guard !completionCredited else { return }
        if shipped < Int.max - 1 { shipped += 1 }
        completionCredited = true
    }

    private func feedback(complete: Bool = false, error: Bool = false) {
        #if os(iOS)
        if hapticsEnabled {
            if complete || error {
                UINotificationFeedbackGenerator().notificationOccurred(error ? .warning : .success)
            } else {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
        if soundEnabled { AudioServicesPlaySystemSound(complete ? 1025 : 1104) }
        #endif
    }

    private static func newSeed() -> UInt64 {
        UInt64.random(in: .min ... .max)
    }
}
