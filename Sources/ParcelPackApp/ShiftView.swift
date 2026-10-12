import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

// MARK: - Shift

struct ShiftView: View {
    @Bindable var model: ShiftModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct DragState { var parcelID: Int; var location: CGPoint; var moved: Bool }
    private struct DropTarget { var origin: Cell; var inBounds: Bool; var valid: Bool }

    @State private var drag: DragState?
    @State private var boardRect: CGRect = .zero
    @GestureState private var gestureActive = false

    private var run: ShiftRun { model.run }
    private var pitch: CGFloat { boardRect.width / CGFloat(max(run.width, 1)) }
    private var motion: Animation? { reduceMotion ? nil : .snappy(duration: 0.25) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    header
                    scoreBar
                    board.frame(maxWidth: boardWidth(for: proxy.size))
                    status
                    if run.phase == .packing {
                        shelfRow
                        tray
                    } else {
                        resultCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(drag != nil)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if run.phase == .packing {
                controls
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .background(Palette.background)
            }
        }
        .overlay(alignment: .topLeading) { floatingPiece }
        .coordinateSpace(.named(packingSpace))
        .onPreferenceChange(BoardRectKey.self) { [$boardRect] in $boardRect.wrappedValue = $0 }
        .background(Palette.background.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
        .fontDesign(.rounded)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(motion, value: run.placements)
        .animation(motion, value: run.phase)
        .onChange(of: run.phase) { _, _ in drag = nil }
        .onChange(of: run.boxIndex) { _, _ in drag = nil }
        .onChange(of: gestureActive) { _, active in if !active { drag = nil } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { drag = nil } }
        .onChange(of: model.message) { _, text in AccessibilityNotification.Announcement(text).post() }
        .confirmationDialog("Start a new run?", isPresented: $model.showNewRunConfirm, titleVisibility: .visible) {
            Button("New run", role: .destructive) { model.newRun() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("This run's progress will be lost.")
        }
        .sheet(isPresented: $model.showHelp) { ShiftHelpSheet() }
    }

    private func boardWidth(for size: CGSize) -> CGFloat {
        min(size.width - 32, max(236, size.height * 0.36), 400)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Shift \(run.plan.number)").font(.title3.bold())
                    Text("Box \(run.boxIndex + 1) of \(ShiftPlan.boxesPerShift)")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            bestLabel
            iconButton("questionmark.circle", label: "How to play") { model.showHelp = true }
            iconButton("arrow.counterclockwise", label: "New run") { model.showNewRunConfirm = true }
        }
    }

    private var bestLabel: some View {
        Label("\(model.record.bestShiftsCleared)", systemImage: "trophy.fill")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(Palette.surface, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Best run: \(model.record.bestShiftsCleared) shifts cleared")
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Score

    private var scoreBar: some View {
        let score: Int = run.shiftScore
        let target: Int = run.plan.target
        return VStack(spacing: 6) {
            HStack {
                Text("Score \(score) / \(target)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Spacer(minLength: 4)
                if score >= target {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.accent)
                }
            }
            ProgressView(value: Double(min(score, target)), total: Double(max(target, 1)))
                .tint(Palette.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) of target \(target)")
    }

    // MARK: Board

    private var board: some View {
        let occupancy: [Cell: Int] = Dictionary(
            run.placements.flatMap { p in run.cells(for: p).map { ($0, p.parcelID) } },
            uniquingKeysWith: { first, _ in first })
        return GeometryReader { geo in
            let p = geo.size.width / CGFloat(max(run.width, 1))
            ZStack(alignment: .topLeading) {
                ForEach(0..<run.height, id: \.self) { y in
                    ForEach(0..<run.width, id: \.self) { x in
                        cellButton(x: x, y: y, occupant: occupancy[Cell(x: x, y: y)], pitch: p)
                            .offset(x: CGFloat(x) * p, y: CGFloat(y) * p)
                    }
                }
                ForEach(run.placements, id: \.parcelID) { placement in
                    pieceOnBoard(placement, pitch: p)
                }
                ghost(pitch: p)
                if run.phase != .packing {
                    stamp(pitch: p)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(reduceMotion ? .opacity : .scale(scale: 1.5).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(GeometryReader { g in
                Color.clear.preference(key: BoardRectKey.self, value: g.frame(in: .named(packingSpace)))
            })
        }
        .aspectRatio(CGFloat(run.width) / CGFloat(max(run.height, 1)), contentMode: .fit)
        .padding(8)
        .background(Palette.cardboard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.grid, lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Box, \(run.width) columns by \(run.height) rows")
    }

    @ViewBuilder private func pieceOnBoard(_ placement: Placement, pitch p: CGFloat) -> some View {
        if let parcel = run.parcel(placement.parcelID) {
            PieceView(cells: parcel.cells(rotation: placement.rotation),
                      color: Palette.parcel(parcel.colorIndex),
                      label: "\(parcel.value)",
                      pitch: p)
                .offset(x: CGFloat(placement.origin.x) * p, y: CGFloat(placement.origin.y) * p)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private func cellButton(x: Int, y: Int, occupant: Int?, pitch p: CGFloat) -> some View {
        Button {
            guard run.phase == .packing else { return }
            if let occupant {
                model.remove(occupant)
            } else {
                model.placeSelected(x: x, y: y)
            }
        } label: {
            RoundedRectangle(cornerRadius: p * 0.18, style: .continuous)
                .fill(Palette.grid.opacity(0.5))
                .padding(p * 0.05)
                .frame(width: p, height: p)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(run.phase != .packing)
        .accessibilityLabel("Row \(y + 1), column \(x + 1)")
        .accessibilityValue(occupantLabel(occupant))
        .accessibilityHint(cellHint(occupant: occupant))
    }

    private func occupantLabel(_ id: Int?) -> String {
        guard let id = id, let parcel = run.parcel(id) else { return "Empty" }
        return "Parcel worth \(parcel.value)"
    }

    private func cellHint(occupant: Int?) -> String {
        guard run.phase == .packing else { return "" }
        if occupant != nil { return "Double tap to take the parcel back out." }
        if model.selectedParcel != nil { return "Double tap to place the selected parcel with its top-left corner here." }
        return "Select a parcel first."
    }

    @ViewBuilder private func ghost(pitch p: CGFloat) -> some View {
        if let d = drag, d.moved, let target = dropTarget(d), target.inBounds, let cells = shape(for: d.parcelID) {
            let e = cells.extent
            ZStack {
                PieceShape(cells: cells, pitch: p).fill(target.valid ? Palette.accent.opacity(0.28) : .clear)
                PieceShape(cells: cells, pitch: p)
                    .stroke(target.valid ? Palette.accent : Palette.invalid,
                            style: StrokeStyle(lineWidth: 3, dash: target.valid ? [6, 4] : []))
                if !target.valid {
                    Image(systemName: "nosign").font(.title2.bold()).foregroundStyle(Palette.invalid)
                }
            }
            .frame(width: CGFloat(e.cols) * p, height: CGFloat(e.rows) * p)
            .offset(x: CGFloat(target.origin.x) * p, y: CGFloat(target.origin.y) * p)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func stamp(pitch p: CGFloat) -> some View {
        let score: Int = run.lastResult?.score ?? 0
        let scoreText: String = score >= 0 ? "+\(score)" : "\u{2212}\(-score)"
        return VStack(spacing: 0) {
            Text("SHIPPED")
                .font(.system(size: max(22, p * 0.62), weight: .black, design: .rounded))
                .tracking(3)
            Text(scoreText)
                .font(.system(size: max(12, p * 0.22), weight: .bold, design: .rounded))
        }
        .foregroundStyle(Palette.stamp)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Palette.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.stamp, lineWidth: 4))
        .rotationEffect(.degrees(-9))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Box \(run.boxIndex + 1) shipped, \(scoreText) points")
    }

    // MARK: Status

    private var status: some View {
        Text(model.message)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 36)
            .accessibilityElement(children: .combine)
    }

    // MARK: Shelf and tray

    private var shelfRow: some View {
        let parcels: [ShiftParcel] = run.shelfParcels
        let empties: Int = max(0, ShiftRun.shelfCapacity - parcels.count)
        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Shelf")
            HStack(spacing: 8) {
                ForEach(parcels) { slotView($0) }
                ForEach(0..<empties, id: \.self) { _ in emptyShelfSlot }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyShelfSlot: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Palette.grid, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .overlay {
                Image(systemName: "tray.and.arrow.down")
                    .font(.title3)
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Empty shelf slot")
    }

    private var tray: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Tray")
            LazyVGrid(columns: trayColumns, spacing: 8) {
                ForEach(run.trayParcels) { slotView($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trayColumns: [GridItem] {
        let count: Int = dynamicTypeSize.isAccessibilitySize ? 3 : 5
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.muted)
    }

    /// Shared slot for tray and shelf parcels.
    private func slotView(_ parcel: ShiftParcel) -> some View {
        let packed = run.isPacked(parcel.id)
        let selected = !packed && model.selectedID == parcel.id
        let shelved = run.location(of: parcel.id) == ParcelLocation.shelf
        let quarters = rotation(for: parcel.id)
        let cells = parcel.cells(rotation: quarters)
        let e = cells.extent
        let slotPitch: CGFloat = min(14, 44 / CGFloat(max(e.cols, e.rows)))
        let traits: AccessibilityTraits = packed ? [] : (selected ? [.isButton, .isSelected] : .isButton)
        return ZStack {
            slotContent(parcel, packed: packed, cells: cells, pitch: slotPitch)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(selected ? Palette.accent : Palette.grid.opacity(0.7), lineWidth: selected ? 3 : 1))
        .overlay(alignment: .topLeading) {
            if !packed { valueBadge(parcel.value) }
        }
        .overlay(alignment: .bottom) {
            if !packed, parcel.isRush { rushTag(parcel) }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .gesture(dragGesture(parcel.id), including: packed ? .subviews : .all)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(slotLabel(parcel, cols: e.cols, rows: e.rows))
        .accessibilityValue(slotValue(packed: packed, selected: selected, shelved: shelved, quarters: quarters))
        .accessibilityAddTraits(traits)
        .accessibilityHint(packed ? "Tap it in the box to take it out." : "Double tap to select, then choose a square in the box.")
        .accessibilityAction { if !packed { model.select(parcel.id) } }
    }

    @ViewBuilder private func slotContent(_ parcel: ShiftParcel, packed: Bool, cells: [Cell], pitch p: CGFloat) -> some View {
        if packed {
            VStack(spacing: 2) {
                Image(systemName: "shippingbox.fill")
                    .font(.title3)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Palette.accent)
                            .offset(x: 6, y: 4)
                    }
                Text("Packed").font(.caption2)
            }
            .foregroundStyle(Palette.muted)
        } else {
            PieceView(cells: cells, color: Palette.parcel(parcel.colorIndex), label: "", pitch: p)
                .opacity(drag?.parcelID == parcel.id && drag?.moved == true ? 0.3 : 1)
        }
    }

    private func valueBadge(_ value: Int) -> some View {
        Text("\(value)")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Palette.onAccent)
            .frame(width: 20, height: 20)
            .background(Palette.ink, in: Circle())
            .padding(4)
            .accessibilityHidden(true)
    }

    private func rushTag(_ parcel: ShiftParcel) -> some View {
        let dueNow: Bool = run.boxesUntilDue(parcel.id) == 0
        return Text(dueNow ? "DUE NOW" : "RUSH")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(dueNow ? Palette.invalid : Palette.stamp, in: Capsule())
            .padding(4)
            .accessibilityHidden(true)
    }

    private func slotLabel(_ parcel: ShiftParcel, cols: Int, rows: Int) -> String {
        var label = "Parcel worth \(parcel.value), \(parcel.cells.count) squares, \(cols) wide by \(rows) tall"
        if parcel.isRush, let due = run.boxesUntilDue(parcel.id) {
            if due <= 0 {
                label += ", rush, due this box"
            } else if due == 1 {
                label += ", rush, due next box"
            } else {
                label += ", rush, due in \(due) boxes"
            }
        }
        return label
    }

    private func slotValue(packed: Bool, selected: Bool, shelved: Bool, quarters: Int) -> String {
        if packed { return "Packed" }
        var parts: [String] = []
        if shelved { parts.append("On shelf") }
        if selected { parts.append("Selected") }
        parts.append("rotated \(quarters * 90) degrees")
        return parts.joined(separator: ", ")
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(run.placements.isEmpty)
                Button { model.rotateSelected() } label: { Label("Rotate", systemImage: "rotate.right") }
                    .disabled(model.selectedParcel == nil)
                Button { model.toggleShelfForSelected() } label: { shelfButtonLabel }
                    .disabled(!model.canShelveSelected)
            }
            .buttonStyle(PillButtonStyle())
            Button { model.seal() } label: { Label("Seal & ship", systemImage: "checkmark.seal.fill") }
                .buttonStyle(PillButtonStyle(filled: true))
        }
    }

    @ViewBuilder private var shelfButtonLabel: some View {
        if model.selectedIsShelved {
            Label("Unshelve", systemImage: "tray.and.arrow.up")
        } else {
            Label("Shelve", systemImage: "tray.and.arrow.down")
        }
    }

    // MARK: Result card

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(resultTitle)
                .font(.headline)
            if let result = run.lastResult {
                resultRows(result)
                if let note = bestNote(for: result) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            shiftSummary
            resultButton
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.grid, lineWidth: 1))
    }

    private var resultTitle: String {
        switch run.phase {
        case .packing: return ""
        case .sealed: return "Box \(run.boxIndex + 1) shipped"
        case .cleared: return "Shift \(run.plan.number) cleared!"
        case .failed: return "Run over"
        }
    }

    @ViewBuilder private func resultRows(_ result: BoxResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            resultRow("Packed value", "\(result.packedValue)")
            resultRow("Full box", result.full ? "\u{00D7}2" : "Not full", muted: !result.full)
            if result.lateFees > 0 {
                resultRow("Late fees", "\u{2212}\(result.lateFees)")
            }
            if result.returnedCount > 0 {
                resultRow("Sent back", "\(result.returnedCount) parcel\(result.returnedCount == 1 ? "" : "s")")
            }
            Divider()
            resultRow("Box score", "\(result.score)", emphasis: true)
        }
    }

    private func resultRow(_ label: String, _ value: String, muted: Bool = false, emphasis: Bool = false) -> some View {
        let color: Color = muted ? Palette.muted : Palette.ink
        let labelFont: Font = emphasis ? Font.headline : Font.subheadline
        let valueFont: Font = emphasis ? Font.headline : Font.subheadline.weight(.semibold)
        return HStack {
            Text(label)
                .font(labelFont)
                .foregroundStyle(color)
            Spacer(minLength: 8)
            Text(value)
                .font(valueFont)
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }

    private func bestNote(for result: BoxResult) -> String? {
        guard let best = result.bestFull else { return nil }
        if result.full && result.packedValue * 2 >= best {
            return "Best full box: \(best) \u{2014} matched before late fees."
        }
        return "Best full box: \(best) before late fees."
    }

    @ViewBuilder private var shiftSummary: some View {
        if run.phase == .cleared || run.phase == .failed {
            VStack(alignment: .leading, spacing: 6) {
                resultRow("Shift score", "\(run.shiftScore) / \(run.plan.target)")
                resultRow("Run score", "\(run.runScore)")
                resultRow("Shifts cleared", "\(run.shiftsCleared)")
                if run.phase == .failed {
                    Text("Best: \(model.record.bestShiftsCleared) shifts, \(model.record.bestRunScore) points")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
        }
    }

    @ViewBuilder private var resultButton: some View {
        switch run.phase {
        case .packing:
            EmptyView()
        case .sealed:
            Button { model.nextBox() } label: { Label("Next box", systemImage: "shippingbox") }
                .buttonStyle(PillButtonStyle(filled: true))
        case .cleared:
            Button { model.nextShift() } label: {
                Label("Start shift \(run.plan.number + 1)", systemImage: "arrow.right.circle")
            }
            .buttonStyle(PillButtonStyle(filled: true))
        case .failed:
            Button { model.newRun() } label: { Label("New run", systemImage: "arrow.counterclockwise") }
                .buttonStyle(PillButtonStyle(filled: true))
        }
    }

    // MARK: Dragging

    private func dragGesture(_ id: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(packingSpace))
            .updating($gestureActive) { _, active, _ in active = true }
            .onChanged { value in
                let moved = hypot(value.translation.width, value.translation.height) > 8
                if drag == nil {
                    // Only start at touch-down, so a drag cancelled mid-flight stays cancelled.
                    guard !moved else { return }
                    drag = DragState(parcelID: id, location: value.location, moved: false)
                }
                drag?.location = value.location
                if moved { drag?.moved = true }
            }
            .onEnded { value in
                defer { drag = nil }
                guard var d = drag, d.parcelID == id else { return }
                d.location = value.location
                guard d.moved else {
                    model.select(id)
                    return
                }
                if let target = dropTarget(d), target.valid {
                    model.place(parcelID: id, x: target.origin.x, y: target.origin.y)
                }
            }
    }

    /// Floating piece rect in the packing space: board cell scale, centred on the finger
    /// horizontally and lifted above it. Ghost and drop both derive from this rect.
    private func floatingFrame(_ d: DragState, cells: [Cell]) -> CGRect {
        let e = cells.extent
        let size = CGSize(width: CGFloat(e.cols) * pitch, height: CGFloat(e.rows) * pitch)
        let centerY = d.location.y - max(70, size.height / 2 + 16)
        return CGRect(x: d.location.x - size.width / 2, y: centerY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func dropTarget(_ d: DragState) -> DropTarget? {
        guard pitch > 0, let cells = shape(for: d.parcelID) else { return nil }
        let frame = floatingFrame(d, cells: cells)
        guard frame.intersects(boardRect) else { return nil }
        let origin = Cell(x: Int(((frame.minX - boardRect.minX) / pitch).rounded()),
                          y: Int(((frame.minY - boardRect.minY) / pitch).rounded()))
        let e = cells.extent
        let inBounds = origin.x >= 0 && origin.y >= 0
            && origin.x + e.cols <= run.width && origin.y + e.rows <= run.height
        let placement = Placement(parcelID: d.parcelID, origin: origin, rotation: rotation(for: d.parcelID))
        let valid = inBounds && run.canPlace(placement)
        return DropTarget(origin: origin, inBounds: inBounds, valid: valid)
    }

    @ViewBuilder private var floatingPiece: some View {
        if let d = drag, d.moved, pitch > 0, let parcel = run.parcel(d.parcelID), let cells = shape(for: d.parcelID) {
            let frame = floatingFrame(d, cells: cells)
            let target = dropTarget(d)
            let outside = target.map { !$0.inBounds } ?? false
            PieceView(cells: cells, color: Palette.parcel(parcel.colorIndex), label: "\(parcel.value)", pitch: pitch)
                .overlay {
                    if outside {
                        PieceShape(cells: cells, pitch: pitch).stroke(Palette.invalid, lineWidth: 3)
                        Image(systemName: "nosign").font(.title2.bold()).foregroundStyle(Palette.invalid)
                    }
                }
                .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
                .offset(x: frame.minX, y: frame.minY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Helpers

    private func rotation(for id: Int) -> Int { model.rotations[id] ?? 0 }
    private func shape(for id: Int) -> [Cell]? { run.parcel(id)?.cells(rotation: rotation(for: id)) }
}

// MARK: - Help

private struct ShiftHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Shift rules") {
                    Label("Each box comes with more parcels than fit. There is always a way to fill it exactly.", systemImage: "shippingbox")
                    Label("Seal to ship. Score the packed values \u{2014} a completely full box scores double.", systemImage: "checkmark.seal")
                    Label("The shelf keeps up to 3 parcels for later boxes in this shift. Tray parcels are sent back when you seal.", systemImage: "tray.and.arrow.down")
                    Label("Returning a rush parcel, or keeping it on the shelf through its due box, costs 5 points.", systemImage: "clock.badge.exclamationmark")
                    Label("Reach the target in 5 boxes to clear the shift. Miss it and the run ends.", systemImage: "flag.checkered")
                }
                Section("Take your time") {
                    Text("No timer. Undo and take parcels out freely until you seal.")
                }
            }
            .navigationTitle("How to play")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .fontDesign(.rounded)
        .tint(Palette.accent)
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 440)
        #endif
    }
}
