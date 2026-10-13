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
    private(set) var staffMessage = ""
    var selectedID: Int?
    var pendingOrder: TycoonOrder?
    var showHelp = false
    var showFranchiseConfirmation = false

    private let store: TycoonStore
    private let defaults: UserDefaults
    private let now: () -> Date
    @ObservationIgnored private var staffUpdatedAt: Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
        store = TycoonStore(defaults: defaults)
        let restored = store.load()
        var initial = restored?.account ?? TycoonAccount(seed: UInt64.random(in: .min ... .max))
        let waiting = initial.settlePendingStaff()
        let customer = initial.lastDelivery?.order.customer ?? .cornerMarket
        let initialSession = restored?.session ?? TycoonSession(order: .generate(accountSeed: initial.seed,
            sequence: initial.completedOrders + 1, choice: 0, customer: customer))
        staffUpdatedAt = restored?.staffUpdatedAt ?? now()
        account = initial
        session = initialSession
        if initialSession.order == initial.lastDelivery?.order {
            message = "Delivered. Your earnings are in the bank."
        } else if !initialSession.state.placements.isEmpty {
            message = "Your order is right where you left it."
        } else {
            message = "Pack your first order. Every delivery grows your depot."
        }
        if waiting.earned > 0 { staffMessage = "Waiting orders shipped · +$\(waiting.earned) earned." }
        refreshStaff()
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
        refreshStaff()
        var updated = account
        guard let receipt = updated.ship(session) else {
            message = "Fill the box before shipping."
            return
        }
        let oldContract = account.progression.completedContracts
        guard commit(account: updated, session: session) else { return }
        selectedID = nil
        message = "Delivered to \(order.customer.title) · +$\(receipt.payout) earned."
        if account.progression.completedContracts > oldContract, let contract = account.progression.lastContract {
            message += " \(contract.title) complete · +$\(contract.reward) banked."
        }
        feedback(complete: true)
    }

    func nextOrder() {
        guard isShipped else { return }
        requestCustomer(order.customer)
    }

    func requestCustomer(_ customer: TycoonCustomer) {
        guard account.isUnlocked(customer) else { return }
        if !isShipped && customer == order.customer { return }
        requestOrder(.generate(accountSeed: account.seed, sequence: account.completedOrders + 1,
                               choice: 0, customer: customer))
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
        refreshStaff()
        var updated = account
        guard let cost = updated.upgradeCost(upgrade), updated.buy(upgrade) else { return }
        guard commit(account: updated, session: session) else { return }
        message = "\(upgrade.title) upgraded. $\(cost) invested in your depot."
        feedback(complete: true)
    }

    func expand() {
        refreshStaff()
        var updated = account
        guard updated.expand(), commit(account: updated, session: session) else { return }
        message = "Welcome to your \(account.stage.title.lowercased()). New customers are ready."
        feedback(complete: true)
    }

    func hireWorker(for customer: TycoonCustomer) {
        refreshStaff()
        var updated = account
        guard let cost = updated.workerCost(for: customer), updated.hireWorker(for: customer),
              commit(account: updated, session: session) else { return }
        staffMessage = "Worker hired for \(customer.title) · $\(cost) invested."
        feedback(complete: true)
    }

    func hireManager(for customer: TycoonCustomer) {
        refreshStaff()
        var updated = account
        guard let cost = updated.managerCost(for: customer), updated.hireManager(for: customer),
              commit(account: updated, session: session) else { return }
        staffMessage = "\(customer.title) manager hired · packing speed and earnings boosted by 25%."
        message = "Manager hired · $\(cost) invested."
        feedback(complete: true)
    }

    func collectStaff(for customer: TycoonCustomer) {
        refreshStaff()
        var updated = account
        let collected = updated.collectStaff(for: customer)
        guard collected > 0, commit(account: updated, session: session) else { return }
        staffMessage = "\(customer.title) deliveries shipped · +$\(collected) collected."
        feedback(complete: true)
    }

    func acceptContract(_ contract: TycoonContract) {
        refreshStaff()
        var updated = account
        guard updated.acceptContract(contract), commit(account: updated, session: session) else { return }
        message = "\(contract.title) accepted. \(contract.kind == .supply ? "Your crew and manual shipments count." : "Pack this customer's boxes yourself to finish the job.")"
        feedback()
    }

    func setSpecialty(_ specialty: CrewSpecialty, for customer: TycoonCustomer) {
        refreshStaff()
        var updated = account
        guard updated.setSpecialty(specialty, for: customer), commit(account: updated, session: session) else { return }
        staffMessage = "\(customer.title) team now uses \(specialty.title.lowercased())."
        feedback()
    }

    func openBranch(_ neighborhood: Neighborhood) {
        refreshStaff()
        var updated = account
        guard updated.openBranch(neighborhood), commit(account: updated, session: session) else { return }
        message = "Your \(neighborhood.title) branch is open and earning alongside your depot."
        feedback(complete: true)
    }

    func upgradeBranch(_ neighborhood: Neighborhood) {
        refreshStaff()
        var updated = account
        guard updated.upgradeBranch(neighborhood), commit(account: updated, session: session) else { return }
        message = "\(neighborhood.title) branch upgraded. Its next shipments earn more."
        feedback(complete: true)
    }

    func visitNeighborhood(_ neighborhood: Neighborhood) {
        refreshStaff()
        var updated = account
        guard updated.visit(neighborhood), commit(account: updated, session: session) else { return }
        message = "Welcome to \(neighborhood.title). Your current box stays ready to pack."
    }

    func buyFranchiseUpgrade(_ upgrade: FranchiseUpgrade) {
        refreshStaff()
        var updated = account
        guard updated.buyFranchiseUpgrade(upgrade), commit(account: updated, session: session) else { return }
        message = "\(upgrade.title) improved at Head Office.\(upgrade == .establishedBusiness ? " Your starter package applies to your next franchise." : "")"
        feedback(complete: true)
    }

    func requestFranchise() {
        refreshStaff()
        guard account.canFranchise else { message = account.franchiseRequirement; return }
        showFranchiseConfirmation = true
    }

    func cancelFranchise() { showFranchiseConfirmation = false }

    func confirmFranchise() {
        guard showFranchiseConfirmation else { return }
        refreshStaff()
        var updated = account
        let reward = updated.franchiseReward
        guard updated.franchise() else { message = account.franchiseRequirement; return }
        let moment = now()
        guard SavedTycoon.validDate(moment) else { message = "Couldn't save the new depot. Try again."; return }
        let anchor = max(moment, staffUpdatedAt)
        let newOrder = TycoonOrder.generate(accountSeed: updated.seed, sequence: updated.completedOrders + 1,
                                           choice: 0, customer: .cornerMarket)
        guard commit(account: updated, session: TycoonSession(order: newOrder), timestamp: anchor) else { return }
        showFranchiseConfirmation = false
        pendingOrder = nil
        selectedID = nil
        staffMessage = ""
        message = "Franchise opened · \(reward) stars earned. A fresh depot is ready."
        feedback(complete: true)
    }

    func refreshStaff() {
        let moment = now()
        guard SavedTycoon.validDate(moment) else { return }
        let elapsed = moment.timeIntervalSince(staffUpdatedAt)
        guard elapsed > 0 else { return }
        if !account.teams.values.contains(where: { $0.workers > 0 }) && account.progression.branches.isEmpty {
            staffUpdatedAt = moment
            return
        }
        var updated = account
        let oldContract = account.progression.completedContracts
        let report = updated.advanceStaff(by: elapsed)
        // Timestamp and proceeds share one snapshot, so relaunch cannot replay elapsed work.
        guard commit(account: updated, session: session, timestamp: moment) else { return }
        if report.earned > 0 {
            staffMessage = "Your crew shipped orders · +$\(report.earned) earned."
        } else if report.packedOrders > 0 {
            staffMessage = "Your workers shipped \(report.packedOrders) orders."
        }
        if account.progression.completedContracts > oldContract, let contract = account.progression.lastContract {
            staffMessage += " \(contract.title) complete · +$\(contract.reward) banked."
        }
    }

    func save() {
        refreshStaff()
        _ = store.save(SavedTycoon(account: account, session: session, staffUpdatedAt: staffUpdatedAt))
    }

    private func begin(_ order: TycoonOrder) {
        guard account.accepts(order), commit(account: account, session: TycoonSession(order: order)) else { return }
        selectedID = nil
        message = "An order for \(order.customer.title). Pack it as shown."
    }

    private func commit(account: TycoonAccount, session: TycoonSession, timestamp: Date? = nil) -> Bool {
        let anchor = timestamp ?? staffUpdatedAt
        guard store.save(SavedTycoon(account: account, session: session, staffUpdatedAt: anchor)) else {
            message = "Couldn't save this change. Try again."
            return false
        }
        self.account = account
        self.session = session
        staffUpdatedAt = anchor
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
