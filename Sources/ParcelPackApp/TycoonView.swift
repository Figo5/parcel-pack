import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

struct TycoonView: View {
    @Bindable var model: TycoonModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Tab: String, CaseIterable {
        case pack = "Pack", orders = "Orders", crew = "Crew", depot = "Depot"
        var symbol: String {
            switch self {
            case .pack: "shippingbox"
            case .orders: "list.clipboard"
            case .crew: "person.2"
            case .depot: "building.2"
            }
        }
    }
    private struct DragState { var parcelID: Int; var location: CGPoint; var moved: Bool }
    private struct DropTarget { var origin: Cell; var inBounds: Bool; var valid: Bool }

    @State private var tab = Tab.pack
    @State private var drag: DragState?
    @State private var boardRect = CGRect.zero
    @State private var staffFeedback = ""
    @State private var staffFeedbackCustomer: TycoonCustomer?
    @GestureState private var gestureActive = false

    private var puzzle: Puzzle { model.state.puzzle }
    private var pitch: CGFloat { boardRect.width / CGFloat(max(puzzle.width, 1)) }
    private var motion: Animation? { reduceMotion ? nil : .snappy(duration: 0.25) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    switch tab {
                    case .pack: packingContent(in: proxy.size)
                    case .orders: ordersContent
                    case .crew: crewContent
                    case .depot: depotContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(drag != nil)
            .id(tab)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 8) {
                header
                if tab == .pack || tab == .orders {
                    HStack(spacing: 8) {
                        Text("Packing for \(model.order.customer.title)")
                            .font(.footnote.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        if tab == .orders {
                            Button { tab = .pack } label: {
                                Image(systemName: "arrow.right").frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Return to your \(model.order.customer.title) order")
                        }
                    }
                    .foregroundStyle(Palette.accent)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: 520).frame(maxWidth: .infinity)
            .background(Palette.background)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if tab == .pack { packingActions }
                tabBar
            }
            .background(Palette.background)
        }
        .overlay(alignment: .topLeading) { floatingPiece }
        .coordinateSpace(.named(packingSpace))
        .onPreferenceChange(BoardRectKey.self) { [$boardRect] in $boardRect.wrappedValue = $0 }
        .background(Palette.background.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
        .fontDesign(.rounded)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(motion, value: model.state.placements)
        .animation(motion, value: model.isShipped)
        .onChange(of: puzzle) { drag = nil }
        .onChange(of: tab) { drag = nil; boardRect = .zero }
        .onChange(of: model.isShipped) { drag = nil }
        .onChange(of: gestureActive) { _, active in if !active { drag = nil } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { drag = nil; model.save() }
        }
        .onChange(of: model.message) { _, text in AccessibilityNotification.Announcement(text).post() }
        .confirmationDialog("Switch customer orders?", isPresented: Binding(
            get: { model.pendingOrder != nil },
            set: { if !$0 { model.cancelOrderChange() } }
        ), titleVisibility: .visible) {
            Button("Pack \(model.pendingOrder?.customer.title ?? "new order")") {
                model.confirmOrderChange()
                tab = .pack
            }
            Button("Keep packing", role: .cancel) { model.cancelOrderChange() }
        } message: {
            Text("The parcels in this box will be set aside. Your cash and depot upgrades are safe.")
        }
        .sheet(isPresented: $model.showHelp) { TycoonHelpSheet() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Parcel Pack").font(.title3.bold())
                Text(model.account.stage.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text(money(model.account.cash))
                    .font(.title3.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
                Text("Cash").font(.caption2).foregroundStyle(Palette.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cash, \(money(model.account.cash))")
            Button { model.showHelp = true } label: {
                Image(systemName: "questionmark.circle").font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("How to grow your depot")
        }
    }

    // MARK: Packing

    @ViewBuilder private func packingContent(in size: CGSize) -> some View {
        orderTicket
        board
            .frame(maxWidth: min(size.width - 32, max(236, size.height * 0.44), 340))
        if model.isShipped {
            shipmentReceipt
        } else {
            VStack(spacing: 4) {
                Text(model.message).font(.subheadline.weight(.medium))
                if model.state.placements.isEmpty {
                    Text("Drag a parcel in, or tap it and then its top-left square.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 36)
            .accessibilityElement(children: .combine)
            parcelTray
        }
    }

    private var orderTicket: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol(for: model.order.customer))
                .font(.title2)
                .frame(width: 44, height: 44)
                .foregroundStyle(Palette.accent)
                .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.order.customer.title).font(.headline)
                Text("Order \(model.order.sequence) · \(puzzle.width) × \(puzzle.height) box")
                    .font(.caption).foregroundStyle(Palette.muted)
                Text(model.isShipped
                     ? (model.cleanBonusAvailable ? "Clean-pack bonus earned" : "Delivered with free hints")
                     : (model.cleanBonusAvailable ? "Clean-pack bonus available" : "Hint used · base pay still yours"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(model.cleanBonusAvailable ? Palette.accent : Palette.muted)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(money(model.isShipped ? (model.receipt?.payout ?? 0) : model.projectedPayout))
                    .font(.title3.weight(.heavy)).monospacedDigit()
                Text(model.isShipped ? "Paid" : "On delivery")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.grid, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var board: some View {
        let occupancy = Dictionary(model.state.placements.flatMap { placement in
            model.state.cells(for: placement).map { ($0, placement.parcelID) }
        }, uniquingKeysWith: { first, _ in first })
        return GeometryReader { geo in
            let p = geo.size.width / CGFloat(puzzle.width)
            ZStack(alignment: .topLeading) {
                ForEach(0..<puzzle.height, id: \.self) { y in
                    ForEach(0..<puzzle.width, id: \.self) { x in
                        boardCell(x: x, y: y, occupant: occupancy[Cell(x: x, y: y)], pitch: p)
                            .offset(x: CGFloat(x) * p, y: CGFloat(y) * p)
                    }
                }
                ForEach(model.state.placements, id: \.parcelID) { placement in
                    if let parcel = parcel(placement.parcelID) {
                        PieceView(cells: parcel.cells, color: Palette.parcel(parcel.colorIndex),
                                  label: "\(parcel.id + 1)", pitch: p)
                            .offset(x: CGFloat(placement.origin.x) * p, y: CGFloat(placement.origin.y) * p)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                ghost(pitch: p)
                if model.isShipped {
                    paidStamp(pitch: p)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(reduceMotion ? .opacity : .scale(scale: 1.2).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: BoardRectKey.self, value: geometry.frame(in: .named(packingSpace)))
            })
        }
        .aspectRatio(CGFloat(puzzle.width) / CGFloat(puzzle.height), contentMode: .fit)
        .padding(8)
        .background(Palette.cardboard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.grid, lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Customer box, \(puzzle.width) columns by \(puzzle.height) rows")
    }

    private func boardCell(x: Int, y: Int, occupant: Int?, pitch p: CGFloat) -> some View {
        let canPlaceSelected = model.selectedID.map {
            model.state.canPlace(Placement(parcelID: $0, origin: Cell(x: x, y: y), rotation: 0))
        } ?? false
        return Button {
            guard !model.isShipped else { return }
            if canPlaceSelected { _ = model.placeSelected(x: x, y: y) }
            else if let occupant { model.remove(occupant) }
            else { _ = model.placeSelected(x: x, y: y) }
        } label: {
            RoundedRectangle(cornerRadius: p * 0.18)
                .fill(Palette.grid.opacity(0.5))
                .padding(p * 0.05)
                .frame(width: p, height: p)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isShipped)
        .accessibilityLabel("Row \(y + 1), column \(x + 1)")
        .accessibilityValue(occupant.map { "Parcel \($0 + 1)" } ?? "Empty")
        .accessibilityHint(model.isShipped ? "This order has been shipped." :
            (canPlaceSelected ? "Place the selected parcel's top-left corner here." :
                occupant != nil ? "Take this parcel back out." : "Select a parcel, then place its top-left corner here."))
    }

    private func paidStamp(pitch p: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("DELIVERED").font(.system(size: max(20, p * 0.48), weight: .black, design: .rounded)).tracking(2)
            Text("+\(money(model.receipt?.payout ?? 0))")
                .font(.system(size: max(17, p * 0.36), weight: .heavy, design: .rounded))
        }
        .foregroundStyle(Palette.stamp)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Palette.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.stamp, lineWidth: 3))
        .rotationEffect(.degrees(-7))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Delivered. \(money(model.receipt?.payout ?? 0)) paid into your depot cash.")
    }

    private var shipmentReceipt: some View {
        VStack(spacing: 8) {
            Text(model.message).font(.headline)
            if let receipt = model.receipt, receipt.cleanBonus > 0 {
                Label("Includes \(money(receipt.cleanBonus)) clean-pack bonus", systemImage: "checkmark.seal")
                    .font(.footnote.weight(.medium)).foregroundStyle(Palette.accent)
            }
            Text("\(model.account.deliveryCount) \(model.account.deliveryCount == 1 ? "order" : "orders") delivered · Put your earnings to work in Depot.")
                .font(.footnote).foregroundStyle(Palette.muted)
            Button { tab = .depot } label: { Label("Visit your depot", systemImage: "building.2") }
                .buttonStyle(PillButtonStyle())
                .frame(maxWidth: 240)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var parcelTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Parcels").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(model.availableParcels.count) left · no turning")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                    count: dynamicTypeSize.isAccessibilitySize ? 3 : puzzle.parcels.count), spacing: 8) {
                ForEach(puzzle.parcels) { traySlot($0) }
            }
        }
    }

    private func traySlot(_ parcel: Parcel) -> some View {
        let packed = model.state.placements.contains { $0.parcelID == parcel.id }
        let selected = !packed && model.selectedID == parcel.id
        let extent = parcel.cells.extent
        return ZStack {
            if packed {
                VStack(spacing: 3) {
                    Image(systemName: "checkmark").font(.title3.weight(.semibold))
                    Text("Packed").font(.caption2)
                }
                .foregroundStyle(Palette.muted)
            } else {
                PieceView(cells: parcel.cells, color: Palette.parcel(parcel.colorIndex), label: "",
                          pitch: min(16, 52 / CGFloat(max(extent.cols, extent.rows))))
                    .opacity(drag?.parcelID == parcel.id && drag?.moved == true ? 0.3 : 1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(selected ? Palette.accent : Palette.grid.opacity(0.7), lineWidth: selected ? 3 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .gesture(dragGesture(parcel.id), including: packed ? .subviews : .all)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Parcel \(parcel.id + 1), \(parcel.cells.count) squares, \(extent.cols) wide by \(extent.rows) tall")
        .accessibilityValue(packed ? "Packed" : selected ? "Selected" : "Unpacked")
        .accessibilityAddTraits(packed ? [] : selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(packed ? "Tap it in the box to take it out." : "Select, then choose its top-left square in the box.")
        .accessibilityAction { if !packed { model.select(parcel.id) } }
        .overlay(alignment: .bottomTrailing) {
            if !packed {
                Text("\(parcel.id + 1)").font(.caption.bold()).padding(6).accessibilityHidden(true)
            }
        }
    }

    private var packingActions: some View {
        HStack(spacing: 8) {
            if model.isShipped {
                Button { model.nextOrder() } label: {
                    Label("Next \(model.order.customer.title) order", systemImage: "shippingbox")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Palette.onAccent)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Your customer choice stays selected until you change it in Orders.")
            } else {
                Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(PillButtonStyle())
                    .disabled(model.state.placements.isEmpty)
                Button { model.hint() } label: { Label("Hint", systemImage: "lightbulb") }
                    .buttonStyle(PillButtonStyle())
                    .disabled(model.state.isComplete)
                    .accessibilityHint("Places one parcel. Hints are free; using one removes this order's clean-pack bonus.")
                Button { model.ship() } label: { Label("Ship", systemImage: "paperplane.fill") }
                    .buttonStyle(PillButtonStyle(filled: true))
                    .disabled(!model.state.isComplete)
                    .accessibilityHint("Fill the box to receive \(money(model.projectedPayout)).")
            }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
        .frame(maxWidth: 520).frame(maxWidth: .infinity)
    }

    // MARK: Orders

    private var ordersContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose your next delivery").font(.title2.bold())
                Text("Pick a customer. Your next orders stay with them until you choose another.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Your customers").font(.headline)
                Text("Grow your depot and make deliveries to reach the next client.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            .padding(.top, 8)
            VStack(spacing: 0) {
                ForEach(TycoonCustomer.allCases, id: \.self) { customer in
                    customerRow(customer)
                    if customer != TycoonCustomer.allCases.last { Divider().overlay(Palette.grid.opacity(0.5)) }
                }
            }
            DisclosureGroup("Choose a different box") {
                VStack(spacing: 12) {
                    ForEach(model.offeredOrders, id: \.choice) { offered in offeredOrder(offered) }
                }
                .padding(.top, 12)
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private func offeredOrder(_ offered: TycoonOrder) -> some View {
        let current = offered == model.order
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol(for: offered.customer))
                    .font(.title2).foregroundStyle(Palette.accent)
                    .frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(offered.customer.title).font(.headline)
                    Text(offered.customer.detail).font(.footnote).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Text(money(offered.customer.basePay))
                    .font(.headline).monospacedDigit()
                    .accessibilityLabel("\(money(offered.customer.basePay)) base pay")
            }
            HStack(spacing: 8) {
                Label("\(offered.customer.size.width) × \(offered.customer.size.height)", systemImage: "square.grid.3x3")
                    .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
                Text("+ upgrades & clean bonus").font(.caption2).foregroundStyle(Palette.muted)
            }
            Button {
                if current {
                    tab = .pack
                } else {
                    model.requestOrder(offered)
                    if model.pendingOrder == nil { tab = .pack }
                }
            } label: {
                Label(current ? (model.isShipped ? "View delivery" : "Keep packing") : "Pack this order",
                      systemImage: current ? "arrow.right" : "shippingbox")
            }
            .buttonStyle(PillButtonStyle(filled: current))
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(current ? Palette.accent : Palette.grid, lineWidth: current ? 2 : 1))
    }

    private func customerRow(_ customer: TycoonCustomer) -> some View {
        let unlocked = model.account.isUnlocked(customer)
        let current = model.order.customer == customer
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: unlocked ? symbol(for: customer) : "lock")
                    .font(.title3).foregroundStyle(unlocked ? Palette.accent : Palette.muted)
                    .frame(width: 36).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(customer.title).font(.subheadline.weight(.semibold))
                    Text(unlocked ? customer.detail : "\(customer.minStage.title) · \(customer.minDeliveries) deliveries")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 4)
                if unlocked {
                    Text(money(customer.basePay)).font(.subheadline.weight(.semibold)).monospacedDigit()
                } else {
                    Text("\(min(model.account.deliveryCount, customer.minDeliveries))/\(customer.minDeliveries)")
                        .font(.caption).monospacedDigit().foregroundStyle(Palette.muted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(customer.title). \(unlocked ? "Available. Base pay \(money(customer.basePay))" : "Locked. Requires \(customer.minStage.title) and \(customer.minDeliveries) deliveries. \(model.account.deliveryCount) delivered")")
            if unlocked {
                HStack(spacing: 12) {
                    Text(current ? "Your selected customer" : "\(customer.size.width) × \(customer.size.height) box")
                        .font(.caption.weight(.medium)).foregroundStyle(current ? Palette.accent : Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        if current && !model.isShipped {
                            tab = .pack
                        } else {
                            model.requestCustomer(customer)
                            if model.pendingOrder == nil { tab = .pack }
                        }
                    } label: {
                        Label(current && !model.isShipped ? "Continue" : "Pack", systemImage: "arrow.right")
                    }
                    .buttonStyle(PillButtonStyle(filled: current))
                    .frame(maxWidth: 140)
                    .accessibilityLabel(current && !model.isShipped ? "Continue your \(customer.title) order" : "Pack orders for \(customer.title)")
                    .accessibilityHint("Future orders stay with this customer until you choose another.")
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: Crew

    private var crewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("A little help with the boxes").font(.title2.bold())
                Text("Hire a team for each customer. Workers pack up to three orders, then wait for you to collect. A manager keeps shipments moving automatically.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                Label("Works while you're away · up to 8 hours", systemImage: "moon.zzz")
                    .font(.caption.weight(.medium)).foregroundStyle(Palette.accent)
            }
            HStack {
                Text("Customer teams").font(.headline)
                Spacer(minLength: 8)
                Text("\(model.account.automatedOrders) staff deliveries")
                    .font(.caption).foregroundStyle(Palette.muted).monospacedDigit()
            }
            VStack(spacing: 0) {
                ForEach(TycoonAccount.automatableCustomers, id: \.self) { customer in
                    crewRow(customer)
                    if customer != TycoonAccount.automatableCustomers.last {
                        Divider().overlay(Palette.grid.opacity(0.5))
                    }
                }
            }
            if !model.staffMessage.isEmpty {
                Text(model.staffMessage).font(.footnote).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func crewRow(_ customer: TycoonCustomer) -> some View {
        let unlocked = model.account.isUnlocked(customer)
        let team = model.account.teams[customer]
        let workers = team?.workers ?? 0
        let managed = team?.hasManager ?? false
        let pending = team?.pendingOrders ?? 0
        let pendingCash = team?.pendingCash ?? 0
        let interval = model.account.workerInterval(for: customer)
        let progress = min(interval, max(0, team?.progressSeconds ?? 0))
        let waiting = !managed && pending >= 3
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: unlocked ? symbol(for: customer) : "lock")
                    .font(.title3).foregroundStyle(unlocked ? Palette.accent : Palette.muted)
                    .frame(width: 32, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(customer.title).font(.headline)
                    Text(unlocked ? "\(workers) \(workers == 1 ? "worker" : "workers")\(managed ? " · managed" : "")"
                         : "\(customer.minStage.title) · \(customer.minDeliveries) deliveries")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 4)
                if managed {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.accent)
                        .accessibilityLabel("Manager hired")
                }
            }
            if unlocked {
                HStack(spacing: 8) {
                    Text("\(money(model.account.workerPayout(for: customer))) per order")
                    Spacer(minLength: 4)
                    Text(workers > 0 ? "\(Int(interval.rounded(.up)))s / order" : "Hire to start")
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
                if workers > 0 {
                    ProgressView(value: waiting ? 1 : progress / max(interval, 1), total: 1)
                        .tint(waiting ? Palette.stamp : Palette.accent)
                        .accessibilityLabel("\(customer.title) packing progress")
                        .accessibilityValue(waiting ? "Storage full. Collect three orders to continue." : "\(Int(progress / max(interval, 1) * 100)) percent")
                    HStack {
                        Text(managed ? "Auto-shipping to your cash" : waiting ? "Storage full · collect to keep packing" : "\(pending)/3 orders waiting")
                            .font(.caption).foregroundStyle(waiting ? Palette.stamp : Palette.muted)
                        Spacer(minLength: 4)
                        if !managed {
                            Button {
                                performStaffAction(for: customer) { model.collectStaff(for: customer) }
                            } label: {
                                Text("Collect \(money(pendingCash))")
                            }
                            .buttonStyle(PillButtonStyle(filled: pendingCash > 0))
                            .frame(maxWidth: 160)
                            .disabled(pendingCash <= 0)
                            .accessibilityLabel("Collect \(pending) \(customer.title) orders for \(money(pendingCash))")
                        }
                    }
                }
                HStack(spacing: 8) {
                    if let cost = model.account.workerCost(for: customer) {
                        Button {
                            performStaffAction(for: customer) { model.hireWorker(for: customer) }
                        } label: {
                            Text("\(workers == 0 ? "Hire" : "Add worker") · \(money(cost))")
                        }
                        .buttonStyle(PillButtonStyle())
                        .disabled(!model.account.canHireWorker(for: customer))
                        .accessibilityLabel("Hire worker \(workers + 1) for \(customer.title), \(money(cost))")
                    } else {
                        Label("20 workers", systemImage: "checkmark")
                            .font(.caption.weight(.medium)).foregroundStyle(Palette.accent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    if managed {
                        Label("Managed", systemImage: "checkmark.seal")
                            .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else if let cost = model.account.managerCost(for: customer) {
                        Button {
                            performStaffAction(for: customer, announce: false) { model.hireManager(for: customer) }
                        } label: { Text("Manager · \(money(cost))") }
                            .buttonStyle(PillButtonStyle())
                            .disabled(!model.account.canHireManager(for: customer))
                            .accessibilityLabel("Hire manager for \(customer.title), \(money(cost))")
                            .accessibilityHint("Automatically ships this team's orders. Hire a worker first.")
                    }
                }
                if workers == 0 {
                    Text(hireRequirement(for: customer))
                        .font(.caption).foregroundStyle(Palette.muted)
                } else if !managed {
                    Text(managerRequirement(for: customer))
                        .font(.caption).foregroundStyle(Palette.muted)
                } else if let cost = model.account.workerCost(for: customer), cost > model.account.cash {
                    Text("Save \(money(cost - model.account.cash)) more for another worker.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                if staffFeedbackCustomer == customer && !staffFeedback.isEmpty {
                    Text(staffFeedback).font(.caption.weight(.medium)).foregroundStyle(Palette.accent)
                }
            } else {
                Text(customerUnlockRequirement(customer))
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .padding(.vertical, 16)
    }

    private func performStaffAction(for customer: TycoonCustomer, announce: Bool = true, action: () -> Void) {
        action()
        staffFeedbackCustomer = customer
        staffFeedback = model.staffMessage
        if announce && !staffFeedback.isEmpty { AccessibilityNotification.Announcement(staffFeedback).post() }
    }

    private func hireRequirement(for customer: TycoonCustomer) -> String {
        guard let cost = model.account.workerCost(for: customer) else { return "Your team is fully staffed." }
        if cost > model.account.cash { return "Save \(money(cost - model.account.cash)) more to hire. A manager needs a worker first." }
        return "Your first worker starts packing straight away."
    }

    private func managerRequirement(for customer: TycoonCustomer) -> String {
        guard let cost = model.account.managerCost(for: customer) else { return "Orders ship automatically." }
        if cost > model.account.cash { return "Save \(money(cost - model.account.cash)) more for automatic shipping." }
        return "Hire a manager to remove the three-order storage limit."
    }

    private func customerUnlockRequirement(_ customer: TycoonCustomer) -> String {
        let remaining = max(0, customer.minDeliveries - model.account.deliveryCount)
        let needsBuilding = model.account.stage.rawValue < customer.minStage.rawValue
        if needsBuilding && remaining > 0 { return "Move to your \(customer.minStage.title.lowercased()) and deliver \(remaining) more orders." }
        if needsBuilding { return "Move to your \(customer.minStage.title.lowercased()) in Depot." }
        return "Deliver \(remaining) more orders to unlock this team."
    }

    // MARK: Depot

    private var depotContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your little shipping empire").font(.title2.bold())
                Text(model.account.stage.detail).font(.subheadline).foregroundStyle(Palette.muted)
            }
            DepotScene(account: model.account)
                .padding(.horizontal, -8)
            Button { tab = .crew } label: {
                HStack {
                    Label("\(model.account.teams.values.reduce(0) { $0 + $1.workers }) workers", systemImage: "person.2")
                    Spacer(minLength: 8)
                    Text("Visit Crew")
                    Image(systemName: "arrow.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Visit Crew. \(model.account.teams.values.reduce(0) { $0 + $1.workers }) workers in your depot.")
            stageTrail
            expansion
            HStack {
                Text("Make it your own").font(.headline)
                Spacer()
                Text("\(model.account.deliveryCount) delivered")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            ForEach(DepotUpgrade.allCases, id: \.self) { upgrade in equipmentRow(upgrade) }
            if !model.message.isEmpty {
                Text(model.message).font(.footnote.weight(.medium)).foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    .padding(.vertical, 4)
            }
        }
    }

    private var stageTrail: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                let reached = index <= model.account.stage.rawValue
                VStack(spacing: 5) {
                    Image(systemName: index == model.account.stage.rawValue ? "shippingbox.fill" : reached ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(reached ? Palette.accent : Palette.grid)
                        .frame(height: 24)
                    Text(stageName(index)).font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(reached ? Palette.ink : Palette.muted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Depot growth, stage \(model.account.stage.rawValue + 1) of 5. Current building, \(model.account.stage.title).")
    }

    @ViewBuilder private var expansion: some View {
        if let cost = model.account.nextExpansionCost, let required = model.account.nextExpansionDeliveries {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next stop: \(nextStageTitle)").font(.headline)
                        Text("More room. Bigger customers.")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "building.2.crop.circle").font(.title2).foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                }
                HStack {
                    Label("\(min(model.account.deliveryCount, required))/\(required) deliveries", systemImage: "checkmark.seal")
                    Spacer()
                    Text("\(money(min(model.account.cash, cost)))/\(money(cost))")
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.muted)
                ProgressView(value: Double(min(model.account.deliveryCount, required)), total: Double(max(required, 1)))
                    .tint(Palette.accent)
                    .accessibilityLabel("Delivery requirement for expansion")
                Button { model.expand() } label: {
                    Text("Move to \(nextStageTitle) · \(money(cost))")
                }
                .buttonStyle(PillButtonStyle(filled: true))
                .disabled(!model.account.canExpand)
                if !model.account.canExpand {
                    Text(expansionRequirement(cost: cost, deliveries: required))
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                if model.message.hasPrefix("Welcome to your") {
                    Text(model.message).font(.caption.weight(.medium)).foregroundStyle(Palette.accent)
                }
            }
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.grid, lineWidth: 1))
        } else {
            Label("Regional hub established. Keep growing your equipment and serving every customer.", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.medium)).foregroundStyle(Palette.accent)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func equipmentRow(_ upgrade: DepotUpgrade) -> some View {
        let level = model.account.level(upgrade)
        let cost = model.account.upgradeCost(upgrade)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: equipmentSymbol(upgrade))
                    .font(.title2).foregroundStyle(Palette.accent)
                    .frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(upgrade.title).font(.headline)
                        Spacer(minLength: 4)
                        Text("Lv. \(level)/\(DepotUpgrade.maxLevel)").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                    }
                    Text(upgrade.detail).font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            if let cost {
                HStack(spacing: 12) {
                    Text(equipmentBenefit(upgrade)).font(.caption.weight(.medium)).foregroundStyle(Palette.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { model.buy(upgrade) } label: {
                        Text("Upgrade · \(money(cost))")
                    }
                    .buttonStyle(PillButtonStyle())
                    .frame(maxWidth: 180)
                    .disabled(!model.account.canBuy(upgrade))
                    .accessibilityLabel("Upgrade \(upgrade.title) to level \(level + 1), \(money(cost))")
                }
                if !model.account.canBuy(upgrade) {
                    Text("Earn \(money(max(0, cost - model.account.cash))) more to upgrade.")
                        .font(.caption2).foregroundStyle(Palette.muted)
                }
            } else {
                Label("Fully upgraded", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
            }
            if model.message.hasPrefix("\(upgrade.title) upgraded") {
                Text(model.message).font(.caption.weight(.medium)).foregroundStyle(Palette.accent)
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.grid, lineWidth: 1))
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab == item ? item.symbol + ".fill" : item.symbol)
                            .font(.system(size: 20, weight: .semibold))
                        Text(item.rawValue).font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(tab == item ? Palette.accent : Palette.muted)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(tab == item ? Palette.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.rawValue)
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(maxWidth: 520).frame(maxWidth: .infinity)
        .overlay(alignment: .top) { Rectangle().fill(Palette.grid.opacity(0.65)).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tycoon tabs")
    }

    // MARK: Dragging

    private func dragGesture(_ id: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(packingSpace))
            .updating($gestureActive) { _, active, _ in active = true }
            .onChanged { value in
                let moved = hypot(value.translation.width, value.translation.height) > 8
                if drag == nil {
                    guard !moved else { return }
                    drag = DragState(parcelID: id, location: value.location, moved: false)
                }
                drag?.location = value.location
                if moved { drag?.moved = true }
            }
            .onEnded { value in
                defer { drag = nil }
                guard var current = drag, current.parcelID == id else { return }
                current.location = value.location
                guard current.moved else { model.select(id); return }
                if let target = dropTarget(current), target.valid {
                    _ = model.place(parcelID: id, x: target.origin.x, y: target.origin.y)
                }
            }
    }

    private func floatingFrame(_ current: DragState, cells: [Cell]) -> CGRect {
        let extent = cells.extent
        let size = CGSize(width: CGFloat(extent.cols) * pitch, height: CGFloat(extent.rows) * pitch)
        let centerY = current.location.y - max(70, size.height / 2 + 16)
        return CGRect(x: current.location.x - size.width / 2, y: centerY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func dropTarget(_ current: DragState) -> DropTarget? {
        guard pitch > 0, let parcel = parcel(current.parcelID) else { return nil }
        let frame = floatingFrame(current, cells: parcel.cells)
        guard frame.intersects(boardRect) else { return nil }
        let origin = Cell(x: Int(((frame.minX - boardRect.minX) / pitch).rounded()),
                          y: Int(((frame.minY - boardRect.minY) / pitch).rounded()))
        let extent = parcel.cells.extent
        let inBounds = origin.x >= 0 && origin.y >= 0
            && origin.x + extent.cols <= puzzle.width && origin.y + extent.rows <= puzzle.height
        return DropTarget(origin: origin, inBounds: inBounds,
                          valid: inBounds && model.state.canPlace(Placement(parcelID: current.parcelID, origin: origin, rotation: 0)))
    }

    @ViewBuilder private func ghost(pitch p: CGFloat) -> some View {
        if let current = drag, current.moved, let target = dropTarget(current), target.inBounds,
           let parcel = parcel(current.parcelID) {
            let extent = parcel.cells.extent
            ZStack {
                PieceShape(cells: parcel.cells, pitch: p).fill(target.valid ? Palette.accent.opacity(0.28) : .clear)
                PieceShape(cells: parcel.cells, pitch: p)
                    .stroke(target.valid ? Palette.accent : Palette.invalid,
                            style: StrokeStyle(lineWidth: 3, dash: target.valid ? [6, 4] : []))
                if !target.valid {
                    Image(systemName: "nosign").font(.title2.bold()).foregroundStyle(Palette.invalid)
                }
            }
            .frame(width: CGFloat(extent.cols) * p, height: CGFloat(extent.rows) * p)
            .offset(x: CGFloat(target.origin.x) * p, y: CGFloat(target.origin.y) * p)
            .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    @ViewBuilder private var floatingPiece: some View {
        if let current = drag, current.moved, pitch > 0, let parcel = parcel(current.parcelID) {
            let frame = floatingFrame(current, cells: parcel.cells)
            PieceView(cells: parcel.cells, color: Palette.parcel(parcel.colorIndex), label: "\(parcel.id + 1)", pitch: pitch)
                .overlay {
                    if dropTarget(current).map({ !$0.inBounds }) ?? false {
                        PieceShape(cells: parcel.cells, pitch: pitch).stroke(Palette.invalid, lineWidth: 3)
                    }
                }
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .offset(x: frame.minX, y: frame.minY)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    // MARK: Copy

    private func parcel(_ id: Int) -> Parcel? { puzzle.parcels.first { $0.id == id } }
    private func money(_ value: Int) -> String { "$\(value.formatted())" }
    private var nextStageTitle: String {
        DepotStage(rawValue: model.account.stage.rawValue + 1)?.title ?? "Regional hub"
    }
    private func stageName(_ index: Int) -> String {
        ["Room", "Shop", "Depot", "Warehouse", "Hub"][index]
    }
    private func symbol(for customer: TycoonCustomer) -> String {
        switch customer {
        case .cornerMarket: "basket"
        case .bookshop: "books.vertical"
        case .plantShop: "leaf"
        case .gadgetShop: "headphones"
        case .homeGoods: "lamp.table"
        case .artStudio: "paintbrush.pointed"
        case .arcadeWorkshop: "gamecontroller"
        case .makerCollective: "hammer"
        }
    }
    private func equipmentSymbol(_ upgrade: DepotUpgrade) -> String {
        switch upgrade {
        case .workbench: "wrench.and.screwdriver"
        case .shelves: "cabinet"
        case .van: "truck.box"
        case .labels: "printer"
        case .conveyor: "arrow.right.square"
        case .dispatchDesk: "desktopcomputer"
        }
    }
    private func equipmentBenefit(_ upgrade: DepotUpgrade) -> String {
        switch upgrade {
        case .workbench: "+$8 per delivery"
        case .shelves: "+$4 per delivery"
        case .van: "+10% shipment pay per level"
        case .labels: "+$6 per delivery"
        case .conveyor: "+5% worker speed per level"
        case .dispatchDesk: "+5% worker pay per level"
        }
    }
    private func expansionRequirement(cost: Int, deliveries: Int) -> String {
        let remaining = max(0, deliveries - model.account.deliveryCount)
        let cash = max(0, cost - model.account.cash)
        if remaining > 0 && cash > 0 { return "Deliver \(remaining) more orders and save \(money(cash)) more." }
        if remaining > 0 { return "Deliver \(remaining) more orders to make the move." }
        return "Save \(money(cash)) more to make the move."
    }
}

private struct TycoonHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Pack, ship, grow") {
                    Label("Fill the customer box with every parcel, then tap Ship to get paid.", systemImage: "shippingbox")
                    Label("Every block stays exactly as shown. Drag it in, or select it and tap its top-left square.", systemImage: "hand.tap")
                    Label("Tap a packed parcel to remove it. Undo is always free.", systemImage: "arrow.uturn.backward")
                    Label("Hints are free and place one parcel. An order packed without hints earns a 20% base-pay bonus.", systemImage: "lightbulb")
                }
                Section("Build your business") {
                    Label("Use Orders to pack for any unlocked customer. That customer stays selected for each next order until you choose another.", systemImage: "list.clipboard")
                    Label("Workbench, shelves, vans and label printers improve shipment pay. Each has 30 upgrade levels.", systemImage: "building.2")
                    Label("Conveyors help staff pack faster. Dispatch desks improve staff shipment pay.", systemImage: "arrow.right.square")
                    Label("Your own deliveries and shipped staff orders both unlock customers and count toward bigger buildings.", systemImage: "building.2.crop.circle")
                }
                Section("Build a crew") {
                    Label("The first six customers can each have up to 20 workers. More workers make that team pack faster.", systemImage: "person.2")
                    Label("A team stores three orders, then pauses. Collect them in Crew to ship the boxes and bank the cash.", systemImage: "tray.and.arrow.down")
                    Label("Hire a manager after your first worker to ship that customer's orders automatically and remove the storage limit.", systemImage: "person.crop.circle.badge.checkmark")
                    Label("Staff keep working while the app is closed, for up to eight hours between visits. Your own packing order stays saved.", systemImage: "moon.zzz")
                }
                Section("Take your time") {
                    Text("No timer or lives. Your order, cash and depot save as you play. Buying upgrades never resets the box you're packing.")
                }
            }
            .navigationTitle("Your shipping depot")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .fontDesign(.rounded).tint(Palette.accent)
    }
}
