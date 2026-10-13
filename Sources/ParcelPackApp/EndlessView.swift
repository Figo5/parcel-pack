import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

struct EndlessView: View {
    @Bindable var model: EndlessModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var boardRect = CGRect.zero
    @State private var drag: DragState?
    @GestureState private var gestureActive = false

    private struct DragState { let slot: Int; var location: CGPoint; var moved: Bool }
    private struct DropTarget { let origin: Cell; let inBounds: Bool; let valid: Bool }
    private let coordinateSpace = "endless-packing"
    private var pitch: CGFloat { boardRect.width / CGFloat(EndlessState.side) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    header.padding(.horizontal, 8)
                    board.frame(maxWidth: min(proxy.size.width - 16, 464))
                    status.padding(.horizontal, 8)
                    tray.padding(.horizontal, 8)
                    controls.padding(.horizontal, 8)
                    Text("10 points per square · 100 per cleared line")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(drag != nil)
        }
        .overlay(alignment: .topLeading) { floatingPiece }
        .coordinateSpace(.named(coordinateSpace))
        .onPreferenceChange(BoardRectKey.self) { [$boardRect] in $boardRect.wrappedValue = $0 }
        .background(Palette.background.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
        .fontDesign(.rounded)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: model.state.board)
        .onChange(of: model.state.tray) { drag = nil }
        .onChange(of: gestureActive) { _, active in if !active { drag = nil } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { drag = nil } }
        .onChange(of: model.message) { _, message in AccessibilityNotification.Announcement(message).post() }
        .confirmationDialog("Start a new game?", isPresented: $model.showNewGame, titleVisibility: .visible) {
            Button("New game") { model.confirmNewGame() }
            Button("Keep playing", role: .cancel) { model.cancelNewGame() }
        } message: {
            Text("Your current board and score will be set aside. Your best score stays.")
        }
        .sheet(isPresented: $model.showHelp) { EndlessHelpSheet() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("SCORE").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(Palette.muted)
                Text(model.state.score.formatted())
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Score \(model.state.score)")
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Label("Best", systemImage: "rosette")
                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                Text(model.best.formatted()).font(.headline)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Best score \(model.best)")
            Button { model.showHelp = true } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title3).frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Free play instructions and settings")
        }
    }

    private var board: some View {
        GeometryReader { geo in
            let p = geo.size.width / CGFloat(EndlessState.side)
            ZStack(alignment: .topLeading) {
                ForEach(0..<EndlessState.side, id: \.self) { y in
                    ForEach(0..<EndlessState.side, id: \.self) { x in
                        boardCell(x: x, y: y, pitch: p)
                            .offset(x: CGFloat(x) * p, y: CGFloat(y) * p)
                    }
                }
                if let d = drag, d.moved, let target = dropTarget(d), target.inBounds,
                   let piece = model.state.tray[d.slot] {
                    ghost(piece: piece, origin: target.origin, valid: target.valid, pitch: p)
                } else if let suggestion = model.suggestedMove,
                          let piece = model.state.tray[suggestion.slot] {
                    ghost(piece: piece, origin: suggestion.origin, valid: true, pitch: p)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(GeometryReader { inner in
                Color.clear.preference(key: BoardRectKey.self, value: inner.frame(in: .named(coordinateSpace)))
            })
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(3)
        .background(Palette.cardboard, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.grid, lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Free play board, eight columns by eight rows")
    }

    private func boardCell(x: Int, y: Int, pitch p: CGFloat) -> some View {
        let value = model.state.board[y * EndlessState.side + x]
        return Button { model.placeSelected(x: x, y: y) } label: {
            RoundedRectangle(cornerRadius: max(3, p * 0.12))
                .fill(value == 0 ? Palette.surface.opacity(0.55) : Palette.parcel(value - 1))
                .overlay(RoundedRectangle(cornerRadius: max(3, p * 0.12))
                    .strokeBorder(value == 0 ? Palette.grid.opacity(0.65) : Palette.ink.opacity(0.12), lineWidth: 1))
                .padding(1.5)
                .frame(width: p, height: p)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isGameOver)
        .accessibilityLabel("Row \(y + 1), column \(x + 1), \(value == 0 ? "empty" : "occupied")")
        .accessibilityHint(model.selectedSlot == nil ? "Choose a parcel first. Full rows and columns clear."
            : "Place the selected parcel with its top-left corner here.")
    }

    private var status: some View {
        VStack(spacing: 4) {
            if model.isGameOver {
                Text("No room left").font(.title3.bold()).foregroundStyle(Palette.stamp)
                Text("Final score \(model.state.score.formatted())").font(.headline)
            }
            Text(model.message).font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .accessibilityElement(children: .combine)
    }

    private var tray: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { slot in traySlot(slot) }
        }
    }

    private func traySlot(_ slot: Int) -> some View {
        let piece = model.state.tray[slot]
        let selected = piece != nil && model.selectedSlot == slot
        return ZStack {
            if let piece {
                let extent = piece.cells.extent
                PieceView(cells: piece.cells, color: Palette.parcel(piece.colorIndex), label: "",
                          pitch: min(22, 72 / CGFloat(max(extent.cols, extent.rows))))
                    .opacity(drag?.slot == slot && drag?.moved == true ? 0.25 : 1)
                Text("\(slot + 1)").font(.caption.bold())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(6)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.title3)
                    Text("Placed").font(.caption)
                }.foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(selected ? Palette.accent : Palette.grid, lineWidth: selected ? 3 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .gesture(dragGesture(slot), including: piece == nil || model.isGameOver ? .subviews : .all)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Parcel \(slot + 1), \(piece?.shape.description ?? "placed")")
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityAddTraits(piece == nil ? [] : (selected ? [.isButton, .isSelected] : .isButton))
        .accessibilityHint(piece == nil ? "Three new parcels arrive after all three are placed."
            : "Double tap to select, then choose an empty square on the board.")
        .accessibilityAction { model.select(slot) }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button { model.hint() } label: { Label("Hint", systemImage: "lightbulb") }
                .buttonStyle(PillButtonStyle())
                .disabled(model.isGameOver)
            Button { model.requestNewGame() } label: { Label("New game", systemImage: "arrow.clockwise") }
                .buttonStyle(PillButtonStyle(filled: model.isGameOver))
        }
    }

    private func ghost(piece: EndlessPiece, origin: Cell, valid: Bool, pitch p: CGFloat) -> some View {
        let extent = piece.cells.extent
        return PieceShape(cells: piece.cells, pitch: p)
            .fill(valid ? Palette.accent.opacity(0.25) : Palette.invalid.opacity(0.12))
            .overlay(PieceShape(cells: piece.cells, pitch: p)
                .stroke(valid ? Palette.accent : Palette.invalid,
                        style: StrokeStyle(lineWidth: 3, dash: valid ? [6, 4] : [])))
            .frame(width: CGFloat(extent.cols) * p, height: CGFloat(extent.rows) * p)
            .offset(x: CGFloat(origin.x) * p, y: CGFloat(origin.y) * p)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func dragGesture(_ slot: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
            .updating($gestureActive) { _, active, _ in active = true }
            .onChanged { value in
                let moved = hypot(value.translation.width, value.translation.height) > 8
                if drag == nil {
                    guard !moved else { return }
                    drag = DragState(slot: slot, location: value.location, moved: false)
                }
                drag?.location = value.location
                if moved { drag?.moved = true }
            }
            .onEnded { value in
                defer { drag = nil }
                guard var current = drag, current.slot == slot else { return }
                current.location = value.location
                if !current.moved { model.select(slot) }
                else if let target = dropTarget(current), target.valid {
                    model.place(slot: slot, x: target.origin.x, y: target.origin.y)
                }
            }
    }

    private func floatingFrame(_ current: DragState, piece: EndlessPiece) -> CGRect {
        let extent = piece.cells.extent
        let size = CGSize(width: CGFloat(extent.cols) * pitch, height: CGFloat(extent.rows) * pitch)
        let centerY = current.location.y - max(70, size.height / 2 + 16)
        return CGRect(x: current.location.x - size.width / 2, y: centerY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func dropTarget(_ current: DragState) -> DropTarget? {
        guard pitch > 0, let piece = model.state.tray[current.slot] else { return nil }
        let frame = floatingFrame(current, piece: piece)
        guard frame.intersects(boardRect) else { return nil }
        let origin = Cell(x: Int(((frame.minX - boardRect.minX) / pitch).rounded()),
                          y: Int(((frame.minY - boardRect.minY) / pitch).rounded()))
        let extent = piece.cells.extent
        let inside = origin.x >= 0 && origin.y >= 0
            && origin.x + extent.cols <= EndlessState.side && origin.y + extent.rows <= EndlessState.side
        return DropTarget(origin: origin, inBounds: inside,
                          valid: inside && model.state.canPlace(slot: current.slot, origin: origin))
    }

    @ViewBuilder private var floatingPiece: some View {
        if let current = drag, current.moved, pitch > 0, let piece = model.state.tray[current.slot] {
            let frame = floatingFrame(current, piece: piece)
            let valid = dropTarget(current)?.valid ?? false
            PieceView(cells: piece.cells, color: Palette.parcel(piece.colorIndex), label: "\(current.slot + 1)", pitch: pitch)
                .overlay {
                    if !valid { PieceShape(cells: piece.cells, pitch: pitch).stroke(Palette.invalid, lineWidth: 3) }
                }
                .shadow(color: .black.opacity(0.2), radius: 8, y: 5)
                .offset(x: frame.minX, y: frame.minY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct EndlessHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("parcel-pack.sound") private var sound = false
    @AppStorage("parcel-pack.haptics") private var haptics = true

    var body: some View {
        NavigationStack {
            List {
                Section("Keep packing") {
                    Text("Drag a parcel onto the board, or tap a parcel and then its top-left square. Every shape stays as shown.")
                    Text("Fill any row or column to clear it. Crossing lines clear together. Earn 10 points for each square you place and 100 for every line you clear.")
                    Text("Use all three parcels to get the next three. Placed parcels stay until a line clears; plan space for the shapes you have left.")
                    Text("Hint highlights a legal spot. It never places a parcel or adds points.")
                    Text("The game ends when none of your remaining parcels fit. Your board saves automatically, and your best score stays after a new game.")
                }
                Section("Feel & sound") {
                    Toggle("Sound", isOn: $sound)
                    #if os(iOS)
                    Toggle("Haptics", isOn: $haptics)
                    #endif
                }
            }
            .navigationTitle("Free play")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(Palette.accent)
        .presentationDetents([.medium, .large])
    }
}
