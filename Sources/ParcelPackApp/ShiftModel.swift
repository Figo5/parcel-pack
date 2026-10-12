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
final class ShiftModel {
    private(set) var run: ShiftRun
    var selectedID: Int?
    private(set) var rotations: [Int: Int]
    private(set) var message: String
    private(set) var record: ShiftRecord
    var showHelp = false
    var showNewRunConfirm = false

    private let store: ShiftStore
    private let defaults: UserDefaults

    private static let startMessage: String = "Fill the box, then seal. Full boxes score double."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        store = ShiftStore(defaults: defaults)
        let restored = store.load()
        let initialRun: ShiftRun = restored?.run ?? ShiftRun(runSeed: Self.newSeed())
        run = initialRun
        rotations = restored?.rotations ?? [:]
        record = store.loadRecord()
        message = restored == nil ? Self.startMessage : Self.resumeMessage(for: initialRun)
        save()
    }

    // MARK: Selection

    var selectedParcel: ShiftParcel? {
        guard let id = selectedID, !run.isPacked(id) else { return nil }
        return run.parcel(id)
    }

    var selectedRotation: Int { selectedID.map { rotations[$0] ?? 0 } ?? 0 }

    var selectedIsShelved: Bool {
        guard let id = selectedID else { return false }
        return run.location(of: id) == ParcelLocation.shelf
    }

    var canShelveSelected: Bool {
        guard run.phase == .packing, selectedParcel != nil else { return false }
        return selectedIsShelved || run.shelfIDs.count < ShiftRun.shelfCapacity
    }

    func select(_ id: Int) {
        guard run.phase == .packing, !run.isPacked(id), let parcel = run.parcel(id) else { return }
        selectedID = id
        message = "Worth \(parcel.value). Tap where its top-left corner should go."
    }

    func rotateSelected() {
        guard let id = selectedID, selectedParcel != nil else {
            message = "Choose a parcel to rotate first."
            return
        }
        rotations[id] = (selectedRotation + 1) % 4
        message = "Turned a quarter turn. Find its new spot."
        feedback()
        save()
    }

    // MARK: Packing

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
        guard run.phase == .packing else { return false }
        let placement = Placement(parcelID: parcelID, origin: Cell(x: x, y: y),
                                  rotation: rotations[parcelID] ?? 0)
        guard run.place(placement) else {
            message = "That spot doesn't fit. Try another square or rotate the parcel."
            feedback(error: true)
            return false
        }
        selectedID = nil
        if run.isFull {
            message = "Full box! Seal it to score double."
            feedback(complete: true)
        } else {
            message = "Packed. \(run.occupiedCount) of \(run.width * run.height) squares filled."
            feedback()
        }
        save()
        return true
    }

    func remove(_ id: Int) {
        guard run.phase == .packing,
              let placement = run.placements.first(where: { $0.parcelID == id }),
              run.remove(parcelID: id) else { return }
        rotations[id] = ((placement.rotation % 4) + 4) % 4
        selectedID = id
        message = "Back in the tray. Tap a square to place it again."
        feedback()
        save()
    }

    func undo() {
        guard run.phase == .packing else { return }
        guard let last = run.placements.last else {
            message = "Nothing packed yet."
            return
        }
        remove(last.parcelID)
    }

    // MARK: Shelf

    func toggleShelfForSelected() {
        guard run.phase == .packing, let parcel = selectedParcel else { return }
        if selectedIsShelved {
            guard run.unshelve(parcel.id) else { return }
            message = "Back in the tray. Tray parcels are sent back when you seal."
        } else {
            guard run.shelve(parcel.id) else {
                message = "The shelf only holds \(ShiftRun.shelfCapacity) parcels."
                feedback(error: true)
                return
            }
            message = "On the shelf for a later box."
        }
        feedback()
        save()
    }

    // MARK: Box and shift flow

    func seal() {
        guard let result = run.seal() else { return }
        selectedID = nil
        updateRecord()
        switch run.phase {
        case .cleared:
            message = "Shift cleared!"
            feedback(complete: true)
        case .failed:
            message = "Run over. Shift target missed."
            feedback(error: true)
        case .packing, .sealed:
            message = "Shipped for \(result.score) points."
            feedback(complete: true)
        }
        save()
    }

    func nextBox() {
        guard run.nextBox() else { return }
        selectedID = nil
        let rushInPlay = run.parcels.contains { $0.isRush }
        let suffix = rushInPlay ? " Rush parcels are due soon." : ""
        message = "Box \(run.boxIndex + 1) of \(ShiftPlan.boxesPerShift)." + suffix
        save()
    }

    func nextShift() {
        guard run.nextShift() else { return }
        selectedID = nil
        rotations = [:]
        message = "Shift \(run.plan.number). Target \(run.plan.target)."
        save()
    }

    func newRun() {
        run = ShiftRun(runSeed: Self.newSeed())
        selectedID = nil
        rotations = [:]
        showNewRunConfirm = false
        message = Self.startMessage
        save()
    }

    func save() {
        // Keep rotations only for parcels still in play.
        let known = Set(run.parcels.map { $0.id })
        rotations = rotations.filter { known.contains($0.key) }
        store.save(SavedShift(run: run, rotations: rotations))
    }

    // MARK: Private

    private func updateRecord() {
        guard run.phase == .cleared || run.phase == .failed else { return }
        var updated = record
        updated.bestShiftsCleared = max(updated.bestShiftsCleared, run.shiftsCleared)
        updated.bestRunScore = max(updated.bestRunScore, run.runScore)
        if run.phase == .failed {
            if updated.runsFinished < Int.max { updated.runsFinished += 1 }
        }
        record = updated
        store.saveRecord(updated)
    }

    private static func resumeMessage(for run: ShiftRun) -> String {
        switch run.phase {
        case .packing:
            return run.placements.isEmpty ? Self.startMessage : "Your box is right where you left it."
        case .sealed:
            return "Box \(run.boxIndex + 1) shipped. Next box when you're ready."
        case .cleared:
            return "Shift cleared! Start shift \(run.plan.number + 1) when you're ready."
        case .failed:
            return "Run over. Shift target missed."
        }
    }

    private func feedback(complete: Bool = false, error: Bool = false) {
        #if os(iOS)
        let hapticsOn: Bool = defaults.object(forKey: "parcel-pack.haptics") as? Bool ?? true
        if hapticsOn {
            if complete || error {
                UINotificationFeedbackGenerator().notificationOccurred(error ? .warning : .success)
            } else {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
        if defaults.bool(forKey: "parcel-pack.sound") {
            AudioServicesPlaySystemSound(complete ? 1025 : 1104)
        }
        #endif
    }

    private static func newSeed() -> UInt64 {
        UInt64.random(in: .min ... .max)
    }
}
