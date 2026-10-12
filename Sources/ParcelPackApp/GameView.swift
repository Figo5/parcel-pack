import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

// MARK: - Palette

enum Palette {
    static let background = Color(hex: 0xF8F4EC)
    static let surface = Color(hex: 0xFFFCF6)
    static let ink = Color(hex: 0x253D38)
    static let muted = Color(hex: 0x5D7068)
    static let cardboard = Color(hex: 0xE3D4BD)
    static let grid = Color(hex: 0xD1BEA0)
    static let accent = Color(hex: 0x267B61)
    static let onAccent = Color.white
    static let invalid = Color(hex: 0xC0392B)
    static let stamp = Color(hex: 0xB5523B)
    static let parcels: [Color] = [0xD98765, 0xE5B74C, 0x70A69C, 0x8F9FC3, 0xA0AE77, 0xCB8EAD].map(Color.init(hex:))

    static func parcel(_ index: Int) -> Color { parcels[((index % parcels.count) + parcels.count) % parcels.count] }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Array where Element == Cell {
    var extent: (cols: Int, rows: Int) {
        ((map(\.x).max() ?? 0) + 1, (map(\.y).max() ?? 0) + 1)
    }
}

struct BoardRectKey: PreferenceKey {
    static let defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

let packingSpace = "packing"

// MARK: - Game

struct GameView: View {
    @Bindable var model: GameModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct DragState { var parcelID: Int; var location: CGPoint; var moved: Bool }
    private struct DropTarget { var origin: Cell; var inBounds: Bool; var valid: Bool }

    @State private var drag: DragState?
    @State private var boardRect: CGRect = .zero
    @GestureState private var gestureActive = false

    private var puzzle: Puzzle { model.state.puzzle }
    private var isComplete: Bool { model.state.isComplete }
    private var pitch: CGFloat { boardRect.width / CGFloat(max(puzzle.width, 1)) }
    private var motion: Animation? { reduceMotion ? nil : .snappy(duration: 0.25) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    header
                    sizeChips
                    board.frame(maxWidth: min(proxy.size.width - 32, max(220, proxy.size.height * 0.42), 420))
                    status
                    if isComplete {
                        Button { model.nextBox() } label: {
                            Label("Next box", systemImage: "shippingbox")
                        }
                        .buttonStyle(PillButtonStyle(filled: true))
                    } else {
                        tray
                        controls
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
        .overlay(alignment: .topLeading) { floatingPiece }
        .coordinateSpace(.named(packingSpace))
        .onPreferenceChange(BoardRectKey.self) { [$boardRect] in $boardRect.wrappedValue = $0 }
        .background(Palette.background.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
        .fontDesign(.rounded)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(motion, value: model.state.placements)
        .animation(motion, value: isComplete)
        .onChange(of: puzzle) { drag = nil }
        .onChange(of: isComplete) { drag = nil }
        .onChange(of: gestureActive) { _, active in if !active { drag = nil } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { drag = nil } }
        .onChange(of: model.message) { _, text in AccessibilityNotification.Announcement(text).post() }
        .confirmationDialog("Start a new box?", isPresented: Binding(
            get: { model.pendingSize != nil },
            set: { if !$0 { model.pendingSize = nil } }
        ), titleVisibility: .visible) {
            Button("Start \(model.pendingSize?.title ?? "new") box") { model.confirmSizeChange() }
            Button("Keep packing", role: .cancel) { model.pendingSize = nil }
        } message: {
            Text("Parcels already in this box will be set aside.")
        }
        .sheet(isPresented: $model.showHelp) { HelpSheet() }
        .sheet(isPresented: $model.showSettings) { SettingsSheet(model: model) }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Parcel Pack").font(.title3.bold())
                    Text("A little room for everything.")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            Label("\(model.shipped)", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(Palette.surface, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(model.shipped) boxes shipped")
            iconButton("questionmark.circle", label: "How to play") { model.showHelp = true }
            iconButton("gearshape", label: "Settings") { model.showSettings = true }
        }
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

    private var sizeChips: some View {
        HStack(spacing: 8) {
            ForEach(BoxSize.allCases, id: \.self) { size in
                let current = size == puzzle.size
                Button { model.changeSize(size) } label: { Text(size.title) }
                    .buttonStyle(PillButtonStyle(filled: current))
                    .accessibilityLabel("\(size.title) box, \(size.width) by \(size.height)")
                    .accessibilityAddTraits(current ? .isSelected : [])
            }
        }
    }

    // MARK: Board

    private var board: some View {
        let occupancy = Dictionary(
            model.state.placements.flatMap { p in model.state.cells(for: p).map { ($0, p.parcelID) } },
            uniquingKeysWith: { first, _ in first })
        return GeometryReader { geo in
            let p = geo.size.width / CGFloat(max(puzzle.width, 1))
            ZStack(alignment: .topLeading) {
                ForEach(0..<puzzle.height, id: \.self) { y in
                    ForEach(0..<puzzle.width, id: \.self) { x in
                        cellButton(x: x, y: y, occupant: occupancy[Cell(x: x, y: y)], pitch: p)
                            .offset(x: CGFloat(x) * p, y: CGFloat(y) * p)
                    }
                }
                ForEach(model.state.placements, id: \.parcelID) { placement in
                    if let parcel = parcel(placement.parcelID) {
                        let cells = parcel.cells(rotation: placement.rotation)
                        PieceView(cells: cells, color: Palette.parcel(parcel.colorIndex), label: "\(parcel.id + 1)", pitch: p)
                            .offset(x: CGFloat(placement.origin.x) * p, y: CGFloat(placement.origin.y) * p)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                ghost(pitch: p)
                if isComplete {
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
        .aspectRatio(CGFloat(puzzle.width) / CGFloat(max(puzzle.height, 1)), contentMode: .fit)
        .padding(8)
        .background(Palette.cardboard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.grid, lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Box, \(puzzle.width) columns by \(puzzle.height) rows")
    }

    private func cellButton(x: Int, y: Int, occupant: Int?, pitch p: CGFloat) -> some View {
        Button {
            guard !isComplete else { return }
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
        .accessibilityLabel("Row \(y + 1), column \(x + 1)")
        .accessibilityValue(occupant.map { "Parcel \($0 + 1)" } ?? "Empty")
        .accessibilityHint(cellHint(occupant: occupant))
    }

    private func cellHint(occupant: Int?) -> String {
        if isComplete { return "" }
        if let occupant { return "Double tap to take parcel \(occupant + 1) back out." }
        if let id = model.selectedParcel?.id { return "Double tap to place parcel \(id + 1) with its top-left corner here." }
        return "Select a parcel first."
    }

    @ViewBuilder private func ghost(pitch p: CGFloat) -> some View {
        if let d = drag, d.moved, let target = dropTarget(d), target.inBounds, let cells = cells(for: d.parcelID) {
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
        VStack(spacing: 0) {
            Text("SHIPPED").font(.system(size: max(22, p * 0.62), weight: .black, design: .rounded)).tracking(3)
            Text("Box \(model.boxNumber)").font(.system(size: max(12, p * 0.22), weight: .bold, design: .rounded))
        }
        .foregroundStyle(Palette.stamp)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Palette.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.stamp, lineWidth: 4))
        .rotationEffect(.degrees(-9))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Box \(model.boxNumber) packed and shipped")
    }

    // MARK: Status, tray, controls

    private var status: some View {
        VStack(spacing: 4) {
            Text(model.message)
                .font(.subheadline.weight(.medium))
            if model.boxNumber == 1 && model.state.placements.isEmpty && !isComplete {
                Text("Rotate to turn. Tap a packed parcel to remove it.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 36)
        .accessibilityElement(children: .combine)
    }

    private var tray: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 3 : puzzle.parcels.count), spacing: 8) {
            ForEach(puzzle.parcels) { traySlot($0) }
        }
    }

    private func traySlot(_ parcel: Parcel) -> some View {
        let packed = model.state.placements.contains { $0.parcelID == parcel.id }
        let selected = !packed && model.selectedID == parcel.id
        let rotation = rotation(for: parcel.id)
        let cells = parcel.cells(rotation: rotation)
        let e = cells.extent
        return ZStack {
            if packed {
                VStack(spacing: 2) {
                    Image(systemName: "shippingbox.fill")
                        .font(.title3)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Palette.accent)
                                .offset(x: 6, y: 4)
                        }
                    Text("Packed").font(.caption2)
                }
                .foregroundStyle(Palette.muted)
            } else {
                PieceView(cells: cells, color: Palette.parcel(parcel.colorIndex), label: "",
                          pitch: min(16, 56 / CGFloat(max(e.cols, e.rows))))
                    .opacity(drag?.parcelID == parcel.id && drag?.moved == true ? 0.3 : 1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(selected ? Palette.accent : Palette.grid.opacity(0.7), lineWidth: selected ? 3 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .gesture(dragGesture(parcel.id), including: packed ? .subviews : .all)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Parcel \(parcel.id + 1), \(parcel.cells.count) squares, \(e.cols) wide by \(e.rows) tall")
        .accessibilityValue(packed ? "Packed" : [selected ? "Selected" : nil, "rotated \(rotation * 90) degrees"]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(packed ? [] : (selected ? [.isButton, .isSelected] : .isButton))
        .accessibilityHint(packed ? "Tap it in the box to take it out." : "Double tap to select, then choose a square in the box.")
        .accessibilityAction { if !packed { model.select(parcel.id) } }
        .overlay(alignment: .bottomTrailing) {
            if !packed {
                Text("\(parcel.id + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.ink)
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(model.state.placements.isEmpty)
            Button { model.rotateSelected() } label: { Label("Rotate", systemImage: "rotate.right") }
                .disabled(model.selectedParcel == nil)
            Button { model.hint() } label: { Label("Hint", systemImage: "lightbulb") }
        }
        .buttonStyle(PillButtonStyle())
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
        guard pitch > 0, let cells = cells(for: d.parcelID) else { return nil }
        let frame = floatingFrame(d, cells: cells)
        guard frame.intersects(boardRect) else { return nil }
        let origin = Cell(x: Int(((frame.minX - boardRect.minX) / pitch).rounded()),
                          y: Int(((frame.minY - boardRect.minY) / pitch).rounded()))
        let e = cells.extent
        let inBounds = origin.x >= 0 && origin.y >= 0
            && origin.x + e.cols <= puzzle.width && origin.y + e.rows <= puzzle.height
        let valid = inBounds && model.state.canPlace(
            Placement(parcelID: d.parcelID, origin: origin, rotation: rotation(for: d.parcelID)))
        return DropTarget(origin: origin, inBounds: inBounds, valid: valid)
    }

    @ViewBuilder private var floatingPiece: some View {
        if let d = drag, d.moved, pitch > 0, let parcel = parcel(d.parcelID), let cells = cells(for: d.parcelID) {
            let frame = floatingFrame(d, cells: cells)
            let target = dropTarget(d)
            let outside = target.map { !$0.inBounds } ?? false
            PieceView(cells: cells, color: Palette.parcel(parcel.colorIndex), label: "\(parcel.id + 1)", pitch: pitch)
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

    private func parcel(_ id: Int) -> Parcel? { puzzle.parcels.first { $0.id == id } }
    private func rotation(for id: Int) -> Int { model.rotations[id] ?? 0 }
    private func cells(for id: Int) -> [Cell]? { parcel(id)?.cells(rotation: rotation(for: id)) }
}

// MARK: - Pieces

/// Union of cell squares; outer corners rounded, shared edges flush so the parcel reads as one block.
struct PieceShape: Shape {
    let cells: [Cell]
    let pitch: CGFloat

    func path(in rect: CGRect) -> Path {
        let set = Set(cells)
        let gap = max(1, pitch * 0.05)
        let radius = pitch * 0.18
        var path = Path()
        for c in cells {
            let top = !set.contains(Cell(x: c.x, y: c.y - 1))
            let bottom = !set.contains(Cell(x: c.x, y: c.y + 1))
            let left = !set.contains(Cell(x: c.x - 1, y: c.y))
            let right = !set.contains(Cell(x: c.x + 1, y: c.y))
            let r = CGRect(x: CGFloat(c.x) * pitch + (left ? gap : 0),
                           y: CGFloat(c.y) * pitch + (top ? gap : 0),
                           width: pitch - (left ? gap : 0) - (right ? gap : 0),
                           height: pitch - (top ? gap : 0) - (bottom ? gap : 0))
            path.addPath(Path(roundedRect: r, cornerRadii: RectangleCornerRadii(
                topLeading: top && left ? radius : 0, bottomLeading: bottom && left ? radius : 0,
                bottomTrailing: bottom && right ? radius : 0, topTrailing: top && right ? radius : 0)))
        }
        return path
    }
}

struct PieceView: View {
    let cells: [Cell]
    let color: Color
    let label: String
    let pitch: CGFloat

    var body: some View {
        let e = cells.extent
        ZStack(alignment: .topLeading) {
            PieceShape(cells: cells, pitch: pitch).fill(color)
            if let first = cells.first {
                // Packing-tape seam across the first square.
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.surface.opacity(0.6))
                    .frame(width: pitch * 0.7, height: pitch * 0.16)
                    .position(x: (CGFloat(first.x) + 0.5) * pitch, y: (CGFloat(first.y) + 0.5) * pitch)
            }
            if let last = cells.last {
                Text(label)
                    .font(.system(size: pitch * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .position(x: (CGFloat(last.x) + 0.5) * pitch, y: (CGFloat(last.y) + 0.5) * pitch)
            }
        }
        .frame(width: CGFloat(e.cols) * pitch, height: CGFloat(e.rows) * pitch)
        .accessibilityHidden(true)
    }
}

// MARK: - Styles & sheets

struct PillButtonStyle: ButtonStyle {
    var filled = false

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, filled: filled)
    }

    private struct PillBody: View {
        let configuration: ButtonStyleConfiguration
        let filled: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(filled ? Palette.onAccent : Palette.ink)
                .background(filled ? Palette.accent : Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(filled ? .clear : Palette.grid, lineWidth: 1))
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("How to play") {
                    Label("Fit every parcel into the box. Every box has a perfect fit.", systemImage: "shippingbox")
                    Label("Drag a parcel onto the box. A green outline shows where it lands; red means it won't fit.", systemImage: "hand.draw")
                    Label("Or tap a parcel, then tap the square for its top-left corner.", systemImage: "hand.tap")
                    Label("Rotate turns the selected parcel. Tap a packed parcel to take it out.", systemImage: "rotate.right")
                    Label("Stuck? Hint tucks one parcel in. Undo steps back.", systemImage: "lightbulb")
                }
                Section("Take your time") {
                    Text("No timer, no lives, no score to chase. Boxes are unlimited, and your box is saved as you go.")
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

private struct SettingsSheet: View {
    @Bindable var model: GameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Sound", isOn: $model.soundEnabled)
                    Toggle("Haptics", isOn: $model.hapticsEnabled)
                }
                Section {
                    Button("New box") { model.nextBox() }
                    Button("Restart this box", role: .destructive) { model.showRestart = true }
                } header: {
                    Text("Box \(model.boxNumber)")
                } footer: {
                    Text("Play as long as you like. There's no timer and boxes never run out.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Restart this box?", isPresented: $model.showRestart, titleVisibility: .visible) {
                Button("Restart", role: .destructive) { model.restart() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All parcels come back out of the box.")
            }
        }
        .fontDesign(.rounded)
        .tint(Palette.accent)
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 360)
        #endif
    }
}
