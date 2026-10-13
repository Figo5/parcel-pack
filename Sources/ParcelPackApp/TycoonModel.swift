import Foundation
import Observation
#if SWIFT_PACKAGE
import ParcelCore
#endif
#if os(iOS)
import UIKit
import AudioToolbox
#endif

@MainActor @Observable final class TycoonModel {
    private(set) var account: TycoonAccount
    private(set) var session: TycoonSession
    private(set) var message: String
    var selectedID: Int?
    var pendingOrder: TycoonOrder?
    var showHelp = false

    private let store: TycoonStore
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        store = TycoonStore(defaults: defaults)
        let restored = store.load()
        let initial = restored?.account ?? TycoonAccount(seed: UInt64.random(in: .min ... .max))
        let initialSession = restored?.session ?? TycoonSession(order: initial.offers[0])
        account = initial
        session = initialSession
        if initialSession.order == initial.lastDelivery?.order {
            message = "Delivered. Your earnings are in the bank."
        } else if !initialSession.state.placements.isEmpty {
            message = "Your order is right where you left it."
        } else {
            message = "Pack your first order. Every delivery grows your depot."
        }
        save()
    }

    var state: PackingState { session.state }
    var order: TycoonOrder { session.order }
    var isShipped: Bool { order == account.lastDelivery?.order }
    var receipt: ShipmentReceipt? { isShipped ? account.lastDelivery : nil }
    var offeredOrders: [TycoonOrder] { account.offers }
    var projectedPayout: Int { receipt?.payout ?? account.payout(for: session) }
    var cleanBonusAvailable: Bool { session.hintsUsed == 0 }
    var availableParcels: [Parcel] {
        state.puzzle.parcels.filter { parcel in !state.placements.contains { $0.parcelID == parcel.id } }
    }
    var selectedParcel: Parcel? { availableParcels.first { $0.id == selectedID } }

    func select(_ id: Int) {
        guard !isShipped, availableParcels.contains(where: { $0.id == id }) else { return }
        selectedID = id
        message = "Place it as shown. Tap where its top-left corner should go."
    }

    @discardableResult func placeSelected(x: Int, y: Int) -> Bool {
        guard let id = selectedID else { message = "Choose a parcel from the tray first."; return false }
        return place(parcelID: id, x: x, y: y)
    }

    @discardableResult func place(parcelID: Int, x: Int, y: Int) -> Bool {
        guard !isShipped else { return false }
        var updated = session
        guard updated.state.place(Placement(parcelID: parcelID, origin: Cell(x: x, y: y), rotation: 0)) else {
            message = "That spot doesn't fit. Try another square."
            feedback(error: true)
            return false
        }
        guard commit(account: account, session: updated) else { return false }
        selectedID = nil
        message = state.isComplete ? "All packed. Ship it to collect $\(projectedPayout)." : "Fits nicely. \(availableParcels.count) \(availableParcels.count == 1 ? "parcel" : "parcels") to go."
        feedback(complete: state.isComplete)
        return true
    }

    func remove(_ id: Int) {
        guard !isShipped, state.placements.contains(where: { $0.parcelID == id }) else { return }
        var updated = session
        updated.state.remove(parcelID: id)
        guard commit(account: account, session: updated) else { return }
        selectedID = id
        message = "Back in the tray. Find its new spot."
        feedback()
    }

    func undo() {
        guard let last = state.placements.last, !isShipped else { return }
        remove(last.parcelID)
    }

    func hint() {
        guard !isShipped, !state.isComplete else { return }
        var updated = session
        var rewound = 0
        var placement = updated.state.hint()
        while placement == nil && !updated.state.placements.isEmpty {
            _ = updated.state.undo()
            rewound += 1
            placement = updated.state.hint()
        }
        if placement == nil && updated.state.placements.isEmpty { placement = updated.state.puzzle.solution.first }
        guard let placement, updated.state.place(placement) else { message = "Try unpacking a parcel, then asking again."; return }
        updated.hintsUsed = min(100, updated.hintsUsed + 1)
        guard commit(account: account, session: updated) else { return }
        selectedID = nil
        message = rewound > 0 ? "Unpacked \(rewound) and found a way forward." : "One parcel tucked in. Hints are always free."
        feedback(complete: state.isComplete)
    }

    func ship() {
        guard !isShipped else { return }
        var updated = account
        guard let receipt = updated.ship(session) else {
            message = "Fill the box before shipping."
            return
        }
        guard commit(account: updated, session: session) else { return }
        selectedID = nil
        message = "Delivered to \(order.customer.title) · +$\(receipt.payout) earned."
        feedback(complete: true)
    }

    func nextOrder() {
        guard isShipped else { return }
        requestOrder(offeredOrders[0])
    }

    func requestOrder(_ order: TycoonOrder) {
        guard account.accepts(order), order != self.order else { return }
        if !isShipped && !state.placements.isEmpty {
            pendingOrder = order
        } else {
            begin(order)
        }
    }

    func confirmOrderChange() {
        guard let order = pendingOrder else { return }
        pendingOrder = nil
        begin(order)
    }

    func cancelOrderChange() { pendingOrder = nil }

    func buy(_ upgrade: DepotUpgrade) {
        var updated = account
        guard let cost = updated.upgradeCost(upgrade), updated.buy(upgrade) else { return }
        guard commit(account: updated, session: session) else { return }
        message = "\(upgrade.title) upgraded. $\(cost) invested in your depot."
        feedback(complete: true)
    }

    func expand() {
        var updated = account
        guard updated.expand(), commit(account: updated, session: session) else { return }
        message = "Welcome to your \(account.stage.title.lowercased()). New customers are ready."
        feedback(complete: true)
    }

    func save() { _ = store.save(SavedTycoon(account: account, session: session)) }

    private func begin(_ order: TycoonOrder) {
        guard account.accepts(order), commit(account: account, session: TycoonSession(order: order)) else { return }
        selectedID = nil
        message = "An order for \(order.customer.title). Pack it as shown."
    }

    private func commit(account: TycoonAccount, session: TycoonSession) -> Bool {
        guard store.save(SavedTycoon(account: account, session: session)) else {
            message = "Couldn't save this change. Try again."
            return false
        }
        self.account = account
        self.session = session
        return true
    }

    private func feedback(complete: Bool = false, error: Bool = false) {
        #if os(iOS)
        if defaults.object(forKey: "parcel-pack.haptics") as? Bool ?? true {
            if complete || error { UINotificationFeedbackGenerator().notificationOccurred(error ? .warning : .success) }
            else { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        }
        if defaults.bool(forKey: "parcel-pack.sound") { AudioServicesPlaySystemSound(complete ? 1025 : 1104) }
        #endif
    }
}
