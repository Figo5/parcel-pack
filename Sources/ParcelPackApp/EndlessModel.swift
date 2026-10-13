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
final class EndlessModel {
    private(set) var state: EndlessState
    private(set) var best: Int
    private(set) var message: String
    private(set) var suggestedMove: EndlessHint?
    var selectedSlot: Int?
    var showNewGame = false
    var showHelp = false

    private let store: EndlessStore
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, seed: UInt64? = nil) {
        self.defaults = defaults
        store = EndlessStore(defaults: defaults)
        let saved = store.load()
        let initial = saved?.state ?? EndlessState(seed: seed ?? UInt64.random(in: .min ... .max))
        state = initial
        best = max(saved?.best ?? 0, initial.score)
        message = initial.isGameOver ? "No parcels fit. Your final score is \(initial.score.formatted())."
            : (initial.placements == 0 ? "Fill a row or column to clear space." : "Your board is right where you left it.")
        save()
    }

    var isGameOver: Bool { state.isGameOver }
    var selectedPiece: EndlessPiece? {
        guard let selectedSlot, state.tray.indices.contains(selectedSlot) else { return nil }
        return state.tray[selectedSlot]
    }

    func select(_ slot: Int) {
        guard !isGameOver, state.remainingSlots.contains(slot), let piece = state.tray[slot] else { return }
        selectedSlot = slot
        suggestedMove = nil
        message = "Parcel \(slot + 1): \(piece.shape.description). Tap its top-left square."
    }

    @discardableResult func placeSelected(x: Int, y: Int) -> Bool {
        guard let selectedSlot else {
            message = "Choose a parcel below the board first."
            return false
        }
        return place(slot: selectedSlot, x: x, y: y)
    }

    @discardableResult func place(slot: Int, x: Int, y: Int) -> Bool {
        var candidate = state
        guard let result = candidate.place(slot: slot, origin: Cell(x: x, y: y)) else {
            message = isGameOver ? "No parcels fit. Start a new game when you're ready."
                : "That parcel doesn't fit there. Try another square."
            feedback(error: true)
            return false
        }
        let record = max(best, candidate.score)
        guard store.save(SavedEndless(best: record, state: candidate)) else {
            message = "Couldn't save that move. Your board is unchanged."
            return false
        }
        state = candidate
        best = record
        selectedSlot = nil
        suggestedMove = nil
        if candidate.isGameOver {
            message = "+\(result.points) points. No parcels fit. Final score: \(candidate.score.formatted())."
        } else if result.lineCount > 0 {
            message = "\(result.lineCount) \(result.lineCount == 1 ? "line" : "lines") cleared. +\(result.points) points!"
        } else {
            message = "+\(result.points) points. Keep room for the next parcels."
        }
        feedback(complete: result.lineCount > 0)
        return true
    }

    func hint() {
        guard !isGameOver, let hint = state.hint(preferredSlot: selectedSlot) else {
            message = "No parcels fit. Start a new game when you're ready."
            return
        }
        suggestedMove = hint
        selectedSlot = hint.slot
        message = "Parcel \(hint.slot + 1) fits at row \(hint.origin.y + 1), column \(hint.origin.x + 1)."
    }

    func requestNewGame() {
        if state.placements > 0 && !isGameOver { showNewGame = true }
        else { startNewGame() }
    }

    func confirmNewGame() { startNewGame() }

    func cancelNewGame() { showNewGame = false }

    func save() {
        if !store.save(SavedEndless(best: best, state: state)) {
            message = "Couldn't save your game. Try again before closing."
        }
    }

    private func startNewGame() {
        let candidate = EndlessState(seed: UInt64.random(in: .min ... .max))
        guard store.save(SavedEndless(best: best, state: candidate)) else {
            message = "Couldn't save a new game. Your board is unchanged."
            return
        }
        state = candidate
        selectedSlot = nil
        suggestedMove = nil
        showNewGame = false
        message = "Fresh board. Fill a row or column to clear space."
    }

    private func feedback(error: Bool = false, complete: Bool = false) {
        #if os(iOS)
        let haptics = defaults.object(forKey: "parcel-pack.haptics") as? Bool ?? true
        if haptics {
            if error || complete { UINotificationFeedbackGenerator().notificationOccurred(error ? .warning : .success) }
            else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
        if defaults.bool(forKey: "parcel-pack.sound") {
            AudioServicesPlaySystemSound(complete ? 1025 : 1104)
        }
        #endif
    }
}
