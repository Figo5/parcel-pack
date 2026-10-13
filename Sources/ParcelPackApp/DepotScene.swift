import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

/// A cutaway shipping floor. Owned equipment and hired teams determine its contents.
struct DepotScene: View {
    let account: TycoonAccount

    private var district: Neighborhood { account.progression.district }
    private var stage: Int {
        district == .oldTown ? account.stage.rawValue
            : min(4, ((account.progression.branches[district]?.level ?? 1) + 1) / 2)
    }
    private var roomWidth: CGFloat { CGFloat(8 + min(stage, 2)) }
    private var roomDepth: CGFloat { stage >= 2 ? 8 : 7 }
    private var localTeams: [TycoonTeam] { account.teams.filter { $0.key.neighborhood == district }.map(\.value) }
    private var workers: Int { localTeams.reduce(0) { $0 + $1.workers } }
    private var managers: Int { localTeams.filter(\.hasManager).count }
    private var originX: CGFloat { 180 - (roomWidth - roomDepth) * 8.5 }
    private var canvasHeight: CGFloat {
        account.level(.van) >= 5 ? 310 : account.level(.van) > 0 ? 286 : stage >= 2 ? 260 : 242
    }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 360, size.height / canvasHeight)
            context.translateBy(x: (size.width - 360 * scale) / 2, y: (size.height - canvasHeight * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            drawRoom(in: &context)
        }
        .aspectRatio(360.0 / canvasHeight, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your \(district.title) \(district == .oldTown ? account.stage.title.lowercased() : "branch"), \(workers) \(workers == 1 ? "worker" : "workers") and \(managers) \(managers == 1 ? "manager" : "managers"). \(account.equipmentMilestoneTitle(.workbench)) level \(account.level(.workbench)), \(account.equipmentMilestoneTitle(.shelves)) level \(account.level(.shelves)), \(account.equipmentMilestoneTitle(.van)) level \(account.level(.van)), \(account.equipmentMilestoneTitle(.labels)) level \(account.level(.labels)), \(account.equipmentMilestoneTitle(.conveyor)) level \(account.level(.conveyor)), \(account.equipmentMilestoneTitle(.dispatchDesk)) level \(account.level(.dispatchDesk)).")
    }

    private func point(_ u: CGFloat, _ v: CGFloat, _ z: CGFloat = 0) -> CGPoint {
        CGPoint(x: originX + (u - v) * 17, y: 91 + (u + v) * 8 - z * 17)
    }

    private func drawRoom(in context: inout GraphicsContext) {
        let width = roomWidth, depth = roomDepth
        let wallHeight: CGFloat = stage >= 3 ? 4.5 : 4
        let floor = [point(0, 0), point(width, 0), point(width, depth), point(0, depth)]
        let shadow = floor.map { CGPoint(x: $0.x + 4, y: $0.y + 13) }
        polygon(shadow, color: Palette.ink.opacity(0.06), in: &context)
        polygon(floor.map { CGPoint(x: $0.x + 2, y: $0.y + 7) }, color: Palette.ink.opacity(0.08), in: &context)

        let leftWall = [point(0, 0, wallHeight), point(0, depth, wallHeight), point(0, depth), point(0, 0)]
        let rightWall = [point(0, 0, wallHeight), point(width, 0, wallHeight), point(width, 0), point(0, 0)]
        gradient(leftWall, colors: [Color(hex: 0xECE2CE), Color(hex: stage >= 2 ? 0xCFD9CD : 0xDDCFB5)],
                 from: point(0, 0, wallHeight), to: point(0, depth), in: &context)
        gradient(rightWall, colors: [Palette.surface, Color(hex: stage >= 2 ? 0xE3E9DD : 0xEAE0CB)],
                 from: point(0, 0, wallHeight), to: point(width, 0), in: &context)
        polygon(floor, color: Color(hex: stage >= 2 ? 0xC9CCB8 : 0xD9C6A7), in: &context)
        polygon([point(0, depth), point(width, depth), point(width, depth, -0.4), point(0, depth, -0.4)],
                color: Color(hex: 0xAD9A7B), in: &context)
        polygon([point(width, 0), point(width, depth), point(width, depth, -0.4), point(width, 0, -0.4)],
                color: Color(hex: 0xB6BDA6), in: &context)

        // Seams, skirting and sunlight give the little room its materials and depth.
        for u in stride(from: CGFloat(1), to: width, by: 1) {
            line(point(u, 0), point(u, depth), color: Palette.ink.opacity(0.08), width: 0.8, in: &context)
        }
        for v in stride(from: CGFloat(1), to: depth, by: 1) {
            line(point(0, v), point(width, v), color: Palette.ink.opacity(0.07), width: 0.8, in: &context)
        }
        line(point(0, 0, 0.12), point(0, depth, 0.12), color: Color(hex: 0xB2B79C), width: 3, in: &context)
        line(point(0, 0, 0.12), point(width, 0, 0.12), color: Color(hex: 0xB2B79C), width: 3, in: &context)
        line(point(0, 0, wallHeight), point(0, depth, wallHeight), color: Palette.surface, width: 3, in: &context)
        line(point(0, 0, wallHeight), point(width, 0, wallHeight), color: Palette.surface, width: 3, in: &context)
        polygon([point(3.4, 0.2), point(5.8, 0.2), point(7.3, 4.4), point(3.7, 5.1)],
                color: Palette.surface.opacity(0.19), in: &context)

        wallSign(district.title.uppercased(), center: point(0, 3.4, 3.25), angle: -25, width: 91, in: &context)
        window(in: &context)
        noticeboard(in: &context)
        if stage >= 2 {
            for v in [CGFloat(0.15), depth - 0.15] {
                line(point(0, v, 0.1), point(0, v, wallHeight), color: Color(hex: 0x8EA592), width: 4, in: &context)
            }
            line(point(width - 0.15, 0, 0.1), point(width - 0.15, 0, wallHeight),
                 color: Color(hex: 0x8EA592), width: 4, in: &context)
        }
        if stage >= 3 {
            ceilingLight(at: point(3.2, 0.5, wallHeight - 0.3), in: &context)
            ceilingLight(at: point(7.5, 0.5, wallHeight - 0.3), in: &context)
        }

        loadingDoor(in: &context)
        floorZone(u: width - 2.75, v: 0.55, width: 2.3, depth: 2.0,
                  color: Color(hex: 0xE5C574), in: &context)

        let rackCount = min(3, 1 + stage / 3 + account.level(.shelves) / 5)
        for index in 0..<rackCount {
            rack(u: 0.38, v: 0.4 + CGFloat(index) * 2.15,
                 level: account.level(.shelves),
                 stock: min(9, 4 + stage + account.level(.shelves) / 5), in: &context)
        }
        floorZone(u: 2.55, v: 2.75, width: 3.8, depth: 2.8,
                  color: Palette.accent.opacity(0.13), in: &context)
        packingBench(u: 3.0, v: 3.0, level: account.level(.workbench), withPrinter: account.level(.labels) > 0, in: &context)
        if account.level(.workbench) >= 5 && stage >= 1 {
            packingBench(u: 5.6, v: 5.0, level: account.level(.workbench), withPrinter: false, in: &context)
        }
        if account.level(.dispatchDesk) > 0 {
            dispatchDesk(u: width - 3.8, v: 1.35, in: &context)
        }

        // Cardboard shipping crates belong to every room; machinery only appears when bought.
        pallet(u: 1.65, v: depth - 1.35, in: &context)
        let storageCrates = min(6, 3 + stage + account.level(.shelves) / 10)
        for index in 0..<storageCrates {
            let u = 1.75 + CGFloat(index % 2) * 0.62
            let v = depth - 1.25 + CGFloat((index / 2) % 2) * 0.55
            let z: CGFloat = index >= 4 ? 0.7 : 0.13
            parcel(u: u, v: v, z: z, width: 0.55, depth: 0.5, height: 0.57,
                   color: Color(hex: index % 2 == 0 ? 0xDAB483 : 0xE4C79F), in: &context)
        }
        pallet(u: width - 2.45, v: 1.0, in: &context)
        parcel(u: width - 2.3, v: 1.15, z: 0.13, width: 0.85, depth: 0.6, height: 0.7,
               color: Palette.cardboard, in: &context)
        parcel(u: width - 1.6, v: 1.6, z: 0.13, width: 0.62, depth: 0.65, height: 0.85,
               color: Color(hex: 0xD1AD7C), in: &context)
        if stage >= 2 {
            parcel(u: width - 2.1, v: 1.25, z: 0.85, width: 0.55, depth: 0.55, height: 0.5,
                   color: Palette.parcel(2), in: &context)
        }
        handCart(u: width - 0.8, v: 3.05, in: &context)
        plant(at: point(0.7, depth - 0.3), in: &context)

        if account.level(.conveyor) > 0 {
            conveyor(u: 3.1, v: depth - 1.0, level: account.level(.conveyor), in: &context)
        }
        drawStaff(in: &context)

        if account.level(.van) > 0 {
            van(at: CGPoint(x: 264, y: 254), level: account.level(.van), in: &context)
            if account.level(.van) >= 5 {
                van(at: CGPoint(x: 174, y: 276), level: account.level(.van), in: &context)
            }
            if account.level(.van) >= 20 {
                van(at: CGPoint(x: 84, y: 277), level: account.level(.van), in: &context)
            }
        } else {
            // A paper shipment label on the room's exposed front edge.
            var label = context
            label.translateBy(x: point(4.0, depth, -0.22).x, y: point(4.0, depth, -0.22).y)
            label.rotate(by: .degrees(25))
            label.draw(Text("READY TO GO").font(.system(size: 7, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.surface), at: .zero)
        }
    }

    private func window(in context: inout GraphicsContext) {
        let u: CGFloat = 2.0, width: CGFloat = 1.55, low: CGFloat = 1.9, high: CGFloat = 3.2
        let points = [point(u, 0, high), point(u + width, 0, high), point(u + width, 0, low), point(u, 0, low)]
        polygon(points, color: Color(hex: 0x9EC5BE), in: &context)
        switch district {
        case .oldTown:
            break
        case .harbor:
            for z in [CGFloat(2.1), 2.3, 2.5] {
                line(point(u + 0.08, 0.01, z), point(u + width - 0.08, 0.01, z), color: Palette.surface.opacity(0.7), width: 1, in: &context)
            }
        case .artsQuarter:
            polygon([point(u + 0.18, 0.01, 3.0), point(u + 0.6, 0.01, 3.0), point(u + 0.6, 0.01, 2.4), point(u + 0.18, 0.01, 2.4)],
                    color: Palette.parcel(0), in: &context)
            polygon([point(u + 0.75, 0.01, 2.75), point(u + 1.2, 0.01, 2.75), point(u + 1.2, 0.01, 2.1), point(u + 0.75, 0.01, 2.1)],
                    color: Palette.parcel(1), in: &context)
        case .uptown:
            for index in 0..<3 {
                let start = u + 0.08 + CGFloat(index) * 0.48
                let top: CGFloat = index == 1 ? 3.08 : 2.75
                polygon([point(start, 0.01, top), point(start + 0.38, 0.01, top), point(start + 0.38, 0.01, low), point(start, 0.01, low)],
                        color: Color(hex: 0x829894), in: &context)
            }
        }
        context.stroke(path(points), with: .color(Palette.surface), lineWidth: 3)
        line(point(u + width / 2, 0, high), point(u + width / 2, 0, low), color: Palette.surface, width: 2, in: &context)
        line(point(u, 0, (low + high) / 2), point(u + width, 0, (low + high) / 2), color: Palette.surface, width: 2, in: &context)
        line(point(u - 0.1, 0.08, low), point(u + width + 0.1, 0.08, low), color: Palette.cardboard, width: 4, in: &context)
    }

    private func noticeboard(in context: inout GraphicsContext) {
        let u: CGFloat = 4.1
        polygon([point(u, 0, 2.9), point(u + 1.1, 0, 2.9), point(u + 1.1, 0, 1.65), point(u, 0, 1.65)],
                color: Color(hex: 0xBEAB8A), in: &context)
        for index in 0..<3 {
            let offset = CGFloat(index % 2) * 0.48
            let top = 2.7 - CGFloat(index / 2) * 0.6
            polygon([point(u + 0.13 + offset, 0.02, top), point(u + 0.48 + offset, 0.02, top),
                     point(u + 0.48 + offset, 0.02, top - 0.4), point(u + 0.13 + offset, 0.02, top - 0.4)],
                    color: index == 1 ? Palette.parcel(1) : Palette.surface, in: &context)
        }
    }

    private func loadingDoor(in context: inout GraphicsContext) {
        let u = roomWidth - 2.8
        let width: CGFloat = 2.35
        let height: CGFloat = stage == 0 ? 2.5 : 3.1
        let outline = [point(u, 0.02, height), point(u + width, 0.02, height),
                       point(u + width, 0.02), point(u, 0.02)]
        polygon(outline, color: Color(hex: stage < 2 ? 0x7E9E8D : 0xA6B0A0), in: &context)
        context.stroke(path(outline), with: .color(Color(hex: 0x748D7B)), lineWidth: 3)
        if stage < 2 {
            polygon([point(u + 0.3, 0.04, height - 0.3), point(u + width - 0.3, 0.04, height - 0.3),
                     point(u + width - 0.3, 0.04, 1.1), point(u + 0.3, 0.04, 1.1)],
                    color: Color(hex: 0xC2D6C9), in: &context)
            line(point(u + width - 0.35, 0.08, 0.9), point(u + width - 0.35, 0.08, 1.15),
                 color: Palette.surface, width: 2, in: &context)
            if stage == 1 {
                cuboid(u: u - 0.1, v: 0, z: height, width: width + 0.2, depth: 0.35, height: 0.15,
                        color: Palette.accent, in: &context)
            }
        } else {
            for z in stride(from: CGFloat(0.25), to: height, by: 0.3) {
                line(point(u + 0.08, 0.07, z), point(u + width - 0.08, 0.07, z),
                     color: Palette.ink.opacity(0.25), width: 1, in: &context)
            }
            line(point(u + 0.65, 0.1, 0.2), point(u + width - 0.65, 0.1, 0.2),
                 color: Palette.ink, width: 2, in: &context)
        }
        wallSign(stage == 0 ? "SHIPMENTS" : "OUTBOUND", center: point(u + width / 2, 0, height + 0.4),
                 angle: 25, width: 68, in: &context)
    }

    private func wallSign(_ title: String, center: CGPoint, angle: Double, width: CGFloat, in context: inout GraphicsContext) {
        var sign = context
        sign.translateBy(x: center.x, y: center.y)
        sign.rotate(by: .degrees(angle))
        let rect = CGRect(x: -width / 2, y: -9, width: width, height: 18)
        sign.fill(Path(roundedRect: rect.offsetBy(dx: 1, dy: 2), cornerRadius: 3), with: .color(Palette.ink.opacity(0.1)))
        sign.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Palette.surface))
        sign.draw(Text(title).font(.system(size: title == "PARCEL PACK" ? 10 : 8, weight: .black, design: .rounded))
            .foregroundStyle(Palette.accent), at: .zero)
    }

    private func ceilingLight(at origin: CGPoint, in context: inout GraphicsContext) {
        context.fill(Path(roundedRect: CGRect(x: origin.x - 14, y: origin.y - 2, width: 28, height: 5), cornerRadius: 2),
                     with: .color(Palette.cardboard))
        context.fill(Path(roundedRect: CGRect(x: origin.x - 11, y: origin.y - 1, width: 22, height: 2), cornerRadius: 1),
                     with: .color(Palette.surface))
    }

    private func rack(u: CGFloat, v: CGFloat, level: Int, stock: Int, in context: inout GraphicsContext) {
        let upgraded = level > 0
        let height: CGFloat = level >= 20 ? 3.3 : upgraded ? 2.65 : 1.9
        let metal = level >= 10 ? Palette.accent : upgraded ? Color(hex: 0x648875) : Color(hex: 0xAA8860)
        polygon([point(u, v), point(u, v + 1.95), point(u, v + 1.95, height), point(u, v, height)],
                color: Color(hex: upgraded ? 0xA7B9A4 : 0xC5AF88), in: &context)
        let tiers = level >= 20 ? 4 : upgraded ? 3 : 2
        for row in 0..<tiers {
            let z = 0.16 + CGFloat(row) * 0.82
            cuboid(u: u, v: v, z: z, width: 0.8, depth: 1.95, height: 0.1, color: metal, in: &context)
            for column in 0..<3 where row * 3 + column < stock {
                parcel(u: u + 0.05, v: v + 0.09 + CGFloat(column) * 0.61, z: z + 0.1,
                       width: 0.65, depth: 0.5, height: 0.57,
                       color: row == 0 ? Color(hex: 0xD5B789) : Palette.parcel(row + column), in: &context)
            }
        }
        for end in [v, v + 1.95] {
            for front in [u, u + 0.8] {
                line(point(front, end), point(front, end, height), color: metal, width: upgraded ? 3 : 2, in: &context)
            }
        }
        cuboid(u: u, v: v, z: height, width: 0.8, depth: 1.95, height: 0.1, color: metal, in: &context)
        if level >= 30 {
            for end in [v + 0.3, v + 1.6] {
                let lamp = point(u + 0.85, end, height - 0.25)
                context.fill(Path(ellipseIn: CGRect(x: lamp.x - 2, y: lamp.y - 2, width: 4, height: 4)), with: .color(Palette.parcel(1)))
            }
        }
    }

    private func packingBench(u: CGFloat, v: CGFloat, level: Int, withPrinter: Bool, in context: inout GraphicsContext) {
        let legColor = level > 0 ? Color(hex: 0x719581) : Color(hex: 0x9A7951)
        for leg in [(CGFloat(0.15), CGFloat(0.15)), (2.55, 0.15), (0.15, 1.45), (2.55, 1.45)] {
            cuboid(u: u + leg.0, v: v + leg.1, z: 0, width: 0.13, depth: 0.13, height: 1.2, color: legColor, in: &context)
        }
        cuboid(u: u, v: v, z: 1.2, width: 2.85, depth: 1.7, height: 0.17,
                color: level > 0 ? Color(hex: 0x8DB5A0) : Color(hex: 0xD9B888), in: &context)
        floorZone(u: u + 0.2, v: v + 0.2, width: 1.65, depth: 1.2, z: 1.39,
                  color: Palette.accent.opacity(0.75), in: &context)
        for offset in [CGFloat(0.5), 1.0, 1.5] {
            line(point(u + offset, v + 0.2, 1.4), point(u + offset, v + 1.4, 1.4),
                 color: Palette.surface.opacity(0.18), width: 0.6, in: &context)
        }
        parcel(u: u + 0.4, v: v + 0.45, z: 1.4, width: 0.9, depth: 0.72, height: 0.7,
               color: Color(hex: 0xE0BF90), in: &context)
        parcel(u: u + 1.1, v: v + 1.0, z: 1.4, width: 0.55, depth: 0.5, height: 0.45,
               color: Palette.parcel(2), in: &context)
        if withPrinter {
            cuboid(u: u + 2.02, v: v + 0.45, z: 1.4, width: 0.65, depth: 0.6, height: 0.38,
                    color: Palette.ink, in: &context)
            floorZone(u: u + 2.13, v: v + 0.5, width: 0.42, depth: 0.47, z: 1.8,
                      color: Palette.surface, in: &context)
            line(point(u + 2.2, v + 0.6, 1.82), point(u + 2.5, v + 0.6, 1.82), color: Palette.accent, width: 1, in: &context)
            if account.level(.labels) >= 5 {
                for offset in [CGFloat(0.7), 0.9, 1.1] {
                    floorZone(u: u + 2.15, v: v + offset, width: 0.32, depth: 0.16, z: 1.42,
                              color: Palette.surface, in: &context)
                }
            }
            if account.level(.labels) >= 10 {
                line(point(u + 2.03, v + 0.45, 1.82), point(u + 2.03, v + 1.35, 1.82),
                     color: Palette.accent, width: 2, in: &context)
            }
            if account.level(.labels) >= 20 {
                cuboid(u: u + 2.12, v: v + 0.55, z: 1.82, width: 0.38, depth: 0.26, height: 0.25,
                        color: Palette.surface, in: &context)
            }
            if account.level(.labels) >= 30 {
                for offset in stride(from: CGFloat(0.08), to: 0.38, by: 0.07) {
                    line(point(u + 2.12 + offset, v + 0.57, 2.08), point(u + 2.12 + offset, v + 0.79, 2.08),
                         color: Palette.ink, width: 0.8, in: &context)
                }
            }
        } else {
            floorZone(u: u + 2.05, v: v + 0.25, width: 0.58, depth: 0.72, z: 1.39,
                      color: Palette.surface, in: &context)
        }
        let tape = point(u + 2.2, v + 1.15, 1.42)
        context.fill(Path(ellipseIn: CGRect(x: tape.x - 4, y: tape.y - 2, width: 8, height: 5)), with: .color(Palette.parcel(1)))
        context.fill(Path(ellipseIn: CGRect(x: tape.x - 1.5, y: tape.y - 1, width: 3, height: 2)), with: .color(Palette.surface))
        if level >= 10 {
            for end in [u + 0.3, u + 1.65] {
                line(point(end, v + 0.25, 1.42), point(end, v + 1.45, 1.42),
                     color: Palette.parcel(1), width: 1.5, in: &context)
            }
        }
        if level >= 20 {
            line(point(u + 0.1, v + 1.7, 0.9), point(u + 2.75, v + 1.7, 0.9),
                 color: Palette.accent, width: 3, in: &context)
        }
        if level >= 30 {
            for end in [u + 0.2, u + 2.65] {
                line(point(end, v + 0.1, 1.4), point(end, v + 0.1, 2.4), color: Palette.accent, width: 2, in: &context)
            }
            line(point(u + 0.2, v + 0.1, 2.4), point(u + 2.65, v + 0.1, 2.4), color: Palette.accent, width: 3, in: &context)
        }
    }

    private func dispatchDesk(u: CGFloat, v: CGFloat, in context: inout GraphicsContext) {
        for corner in [(CGFloat(0.15), CGFloat(0.15)), (1.5, 0.15), (0.15, 1.0), (1.5, 1.0)] {
            cuboid(u: u + corner.0, v: v + corner.1, z: 0, width: 0.1, depth: 0.1, height: 1.25,
                    color: Palette.accent, in: &context)
        }
        cuboid(u: u, v: v, z: 1.25, width: 1.75, depth: 1.2, height: 0.12,
                color: Color(hex: 0xDAB98A), in: &context)
        let monitor = [point(u + 0.25, v + 0.4, 2.15), point(u + 1.1, v + 0.4, 2.15),
                       point(u + 1.1, v + 0.4, 1.55), point(u + 0.25, v + 0.4, 1.55)]
        polygon(monitor, color: Palette.ink, in: &context)
        polygon([point(u + 0.32, v + 0.42, 2.07), point(u + 1.03, v + 0.42, 2.07),
                 point(u + 1.03, v + 0.42, 1.65), point(u + 0.32, v + 0.42, 1.65)],
                color: Color(hex: 0xACD1C2), in: &context)
        line(point(u + 0.65, v + 0.4, 1.55), point(u + 0.65, v + 0.4, 1.38), color: Palette.ink, width: 2, in: &context)
        floorZone(u: u + 1.15, v: v + 0.45, width: 0.45, depth: 0.5, z: 1.39, color: Palette.surface, in: &context)
        if account.level(.dispatchDesk) >= 5 {
            floorZone(u: u + 0.22, v: v + 0.85, width: 0.75, depth: 0.2, z: 1.39, color: Color(hex: 0xACD1C2), in: &context)
        }
        if account.level(.dispatchDesk) >= 10 {
            cuboid(u: u + 1.15, v: v + 0.1, z: 1.4, width: 0.42, depth: 0.16, height: 0.65,
                    color: Palette.ink, in: &context)
        }
        if account.level(.dispatchDesk) >= 20 {
            wallSign("ROUTES", center: point(u + 0.9, 0.1, 3.25), angle: 25, width: 54, in: &context)
        }
        if account.level(.dispatchDesk) >= 30 {
            let lamp = point(u + 1.36, v + 0.25, 2.05)
            context.fill(Path(ellipseIn: CGRect(x: lamp.x - 2, y: lamp.y - 2, width: 4, height: 4)), with: .color(Palette.parcel(1)))
            line(point(u + 0.2, v + 0.9, 1.42), point(u + 1.0, v + 0.9, 1.42),
                 color: Palette.accent, width: 2, in: &context)
        }
    }

    private func conveyor(u: CGFloat, v: CGFloat, level: Int, in context: inout GraphicsContext) {
        let width: CGFloat = 1.8 + CGFloat(min(30, level)) * 0.065
        for end in [u + 0.15, u + width - 0.2] {
            cuboid(u: end, v: v + 0.25, z: 0, width: 0.12, depth: 0.12, height: 0.6, color: Palette.accent, in: &context)
        }
        cuboid(u: u, v: v, z: 0.6, width: width, depth: 0.65, height: 0.2, color: Palette.ink, in: &context)
        for offset in stride(from: CGFloat(0.12), to: width, by: 0.2) {
            line(point(u + offset, v, 0.81), point(u + offset, v + 0.65, 0.81),
                 color: Color(hex: 0xAEC0AF), width: 1.2, in: &context)
        }
        line(point(u, v + 0.65, 0.83), point(u + width, v + 0.65, 0.83), color: Palette.accent, width: 2, in: &context)
        parcel(u: u + width * 0.5, v: v + 0.08, z: 0.83, width: 0.55, depth: 0.48, height: 0.48,
               color: Palette.cardboard, in: &context)
        if level >= 5 {
            cuboid(u: u, v: v - 0.8, z: 0.6, width: width, depth: 0.65, height: 0.2, color: Palette.ink, in: &context)
            for offset in stride(from: CGFloat(0.12), to: width, by: 0.2) {
                line(point(u + offset, v - 0.8, 0.81), point(u + offset, v - 0.15, 0.81),
                     color: Color(hex: 0xAEC0AF), width: 1.2, in: &context)
            }
        }
        if level >= 10 {
            for edge in [v - 0.8, v + 0.65] {
                line(point(u + width - 0.5, edge, 0.8), point(u + width - 0.5, edge, 1.85),
                     color: Palette.accent, width: 3, in: &context)
            }
            line(point(u + width - 0.5, v - 0.8, 1.85), point(u + width - 0.5, v + 0.65, 1.85),
                 color: level >= 20 ? Palette.parcel(1) : Palette.accent, width: level >= 20 ? 5 : 3, in: &context)
        }
        if level >= 30 {
            cuboid(u: u + width - 0.3, v: v + 0.8, z: 0, width: 0.6, depth: 0.4, height: 1.4,
                    color: Color(hex: 0x8DB5A0), in: &context)
        }
    }

    private func pallet(u: CGFloat, v: CGFloat, in context: inout GraphicsContext) {
        cuboid(u: u, v: v, z: 0, width: 1.5, depth: 1.25, height: 0.12, color: Color(hex: 0xB0926E), in: &context)
        for offset in stride(from: CGFloat(0.15), to: 1.4, by: 0.3) {
            line(point(u + offset, v, 0.13), point(u + offset, v + 1.25, 0.13),
                 color: Color(hex: 0xE0CCA8), width: 2, in: &context)
        }
    }

    private func handCart(u: CGFloat, v: CGFloat, in context: inout GraphicsContext) {
        line(point(u, v), point(u, v, 1.65), color: Palette.accent, width: 3, in: &context)
        line(point(u, v + 0.6), point(u, v + 0.6, 1.65), color: Palette.accent, width: 3, in: &context)
        line(point(u, v, 1.65), point(u, v + 0.6, 1.65), color: Palette.accent, width: 3, in: &context)
        for end in [v, v + 0.6] {
            let wheel = point(u + 0.1, end)
            context.fill(Path(ellipseIn: CGRect(x: wheel.x - 3, y: wheel.y - 3, width: 6, height: 6)), with: .color(Palette.ink))
        }
        parcel(u: u - 0.4, v: v + 0.08, z: 0.1, width: 0.5, depth: 0.45, height: 0.6,
               color: Palette.cardboard, in: &context)
    }

    private func drawStaff(in context: inout GraphicsContext) {
        let workerPositions: [(CGFloat, CGFloat)] = [(4.5, 5.15), (5.65, 4.9), (6.1, 6.25), (2.35, 3.6), (7.15, 3.9), (6.9, 5.9)]
        var shown = 0
        for (customerIndex, customer) in TycoonAccount.automatableCustomers.filter({ $0.neighborhood == district }).enumerated() {
            let count = account.teams[customer]?.workers ?? 0
            for _ in 0..<min(count, 2) where shown < workerPositions.count {
                let position = workerPositions[shown]
                person(at: point(min(position.0, roomWidth - 0.8), min(position.1, roomDepth - 0.5)),
                       color: Palette.parcel(customerIndex + 2), manager: false, in: &context)
                shown += 1
            }
        }
        for index in 0..<min(managers, 3) {
            person(at: point(roomWidth - 2.8 + CGFloat(index) * 0.55, 2.8 + CGFloat(index) * 0.6),
                   color: Palette.accent, manager: true, in: &context)
        }
    }

    private func person(at origin: CGPoint, color: Color, manager: Bool, in context: inout GraphicsContext) {
        let x = origin.x, y = origin.y
        context.fill(Path(ellipseIn: CGRect(x: x - 7, y: y - 1, width: 15, height: 6)), with: .color(Palette.ink.opacity(0.13)))
        line(CGPoint(x: x - 2, y: y - 9), CGPoint(x: x - 3, y: y), color: Palette.ink, width: 3, in: &context)
        line(CGPoint(x: x + 2, y: y - 9), CGPoint(x: x + 4, y: y), color: Palette.ink, width: 3, in: &context)
        context.fill(Path(roundedRect: CGRect(x: x - 5, y: y - 23, width: 11, height: 16), cornerRadius: 4), with: .color(color))
        line(CGPoint(x: x - 4, y: y - 19), CGPoint(x: x - 7, y: y - 13), color: color, width: 3, in: &context)
        line(CGPoint(x: x + 5, y: y - 19), CGPoint(x: x + 8, y: y - 14), color: color, width: 3, in: &context)
        context.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 31, width: 9, height: 10)), with: .color(Color(hex: 0xC9A37C)))
        if manager {
            line(CGPoint(x: x, y: y - 21), CGPoint(x: x + 1, y: y - 13), color: Palette.surface, width: 2, in: &context)
            context.fill(Path(roundedRect: CGRect(x: x + 5, y: y - 18, width: 7, height: 9), cornerRadius: 1), with: .color(Palette.surface))
            line(CGPoint(x: x + 7, y: y - 15), CGPoint(x: x + 10, y: y - 15), color: Palette.muted, width: 1, in: &context)
        } else {
            context.fill(Path(roundedRect: CGRect(x: x - 5, y: y - 32, width: 11, height: 4), cornerRadius: 2), with: .color(color))
            context.fill(Path(roundedRect: CGRect(x: x - 3, y: y - 20, width: 7, height: 11), cornerRadius: 2), with: .color(Palette.surface.opacity(0.35)))
        }
    }

    private func van(at origin: CGPoint, level: Int, in context: inout GraphicsContext) {
        let x = origin.x, y = origin.y
        context.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 1, width: 78, height: 13)), with: .color(Palette.ink.opacity(0.11)))
        let color = level >= 10 ? Palette.accent : Color(hex: 0x75A596)
        polygon([CGPoint(x: x, y: y - 30), CGPoint(x: x + 13, y: y - 35), CGPoint(x: x + 54, y: y - 21), CGPoint(x: x + 41, y: y - 16)],
                color: Color(hex: 0x9FC4AF), in: &context)
        polygon([CGPoint(x: x, y: y - 30), CGPoint(x: x + 41, y: y - 16), CGPoint(x: x + 41, y: y + 5), CGPoint(x: x, y: y - 9)],
                color: color, in: &context)
        polygon([CGPoint(x: x + 41, y: y - 16), CGPoint(x: x + 54, y: y - 21), CGPoint(x: x + 69, y: y - 5), CGPoint(x: x + 58, y: y + 9), CGPoint(x: x + 41, y: y + 5)],
                color: Palette.accent, in: &context)
        polygon([CGPoint(x: x + 46, y: y - 14), CGPoint(x: x + 53, y: y - 17), CGPoint(x: x + 62, y: y - 7), CGPoint(x: x + 55, y: y - 3)],
                color: Color(hex: 0xD2E5DB), in: &context)
        for wheel in [CGPoint(x: x + 11, y: y - 6), CGPoint(x: x + 50, y: y + 7)] {
            context.fill(Path(ellipseIn: CGRect(x: wheel.x - 5, y: wheel.y - 5, width: 10, height: 10)), with: .color(Palette.ink))
            context.fill(Path(ellipseIn: CGRect(x: wheel.x - 2, y: wheel.y - 2, width: 4, height: 4)), with: .color(Palette.surface))
        }
        var badge = context
        badge.translateBy(x: x + 21, y: y - 13)
        badge.rotate(by: .degrees(19))
        badge.draw(Text(Image(systemName: "shippingbox.fill")).font(.system(size: 12)).foregroundStyle(Palette.surface), at: .zero)
        line(CGPoint(x: x + 3, y: y - 12), CGPoint(x: x + 36, y: y),
             color: level >= 30 ? Palette.parcel(1) : Palette.surface.opacity(0.65), width: level >= 30 ? 3 : 2, in: &context)
    }

    private func plant(at origin: CGPoint, in context: inout GraphicsContext) {
        context.fill(Path(roundedRect: CGRect(x: origin.x - 6, y: origin.y - 6, width: 13, height: 11), cornerRadius: 3), with: .color(Palette.parcel(0)))
        for offset in [CGFloat(-5), 0, 5] {
            context.fill(Path(ellipseIn: CGRect(x: origin.x + offset - 4, y: origin.y - 20 - abs(offset) * 0.5, width: 8, height: 16)), with: .color(Palette.accent))
        }
    }

    private func parcel(u: CGFloat, v: CGFloat, z: CGFloat, width: CGFloat, depth: CGFloat, height: CGFloat, color: Color, in context: inout GraphicsContext) {
        cuboid(u: u, v: v, z: z, width: width, depth: depth, height: height, color: color, in: &context)
        floorZone(u: u + width * 0.42, v: v, width: width * 0.18, depth: depth, z: z + height + 0.01,
                  color: Palette.surface.opacity(0.65), in: &context)
        polygon([point(u + width * 0.42, v + depth + 0.01, z + height), point(u + width * 0.6, v + depth + 0.01, z + height),
                 point(u + width * 0.6, v + depth + 0.01, z), point(u + width * 0.42, v + depth + 0.01, z)],
                color: Palette.surface.opacity(0.4), in: &context)
        if width >= 0.7 {
            polygon([point(u + width * 0.12, v + depth + 0.02, z + height * 0.7),
                     point(u + width * 0.36, v + depth + 0.02, z + height * 0.7),
                     point(u + width * 0.36, v + depth + 0.02, z + height * 0.35),
                     point(u + width * 0.12, v + depth + 0.02, z + height * 0.35)],
                    color: Palette.surface.opacity(0.85), in: &context)
        }
    }

    private func cuboid(u: CGFloat, v: CGFloat, z: CGFloat, width: CGFloat, depth: CGFloat, height: CGFloat, color: Color, in context: inout GraphicsContext) {
        let right = [point(u + width, v, z), point(u + width, v + depth, z),
                     point(u + width, v + depth, z + height), point(u + width, v, z + height)]
        let front = [point(u, v + depth, z), point(u + width, v + depth, z),
                     point(u + width, v + depth, z + height), point(u, v + depth, z + height)]
        let top = [point(u, v, z + height), point(u + width, v, z + height),
                   point(u + width, v + depth, z + height), point(u, v + depth, z + height)]
        polygon(right, color: color, in: &context)
        polygon(right, color: Palette.ink.opacity(0.17), in: &context)
        polygon(front, color: color, in: &context)
        polygon(front, color: Palette.ink.opacity(0.07), in: &context)
        polygon(top, color: color, in: &context)
        polygon(top, color: Palette.surface.opacity(0.12), in: &context)
    }

    private func floorZone(u: CGFloat, v: CGFloat, width: CGFloat, depth: CGFloat, z: CGFloat = 0.02, color: Color, in context: inout GraphicsContext) {
        polygon([point(u, v, z), point(u + width, v, z), point(u + width, v + depth, z), point(u, v + depth, z)],
                color: color, in: &context)
    }

    private func path(_ points: [CGPoint]) -> Path {
        var result = Path()
        guard let first = points.first else { return result }
        result.move(to: first)
        points.dropFirst().forEach { result.addLine(to: $0) }
        result.closeSubpath()
        return result
    }

    private func polygon(_ points: [CGPoint], color: Color, in context: inout GraphicsContext) {
        context.fill(path(points), with: .color(color))
    }

    private func gradient(_ points: [CGPoint], colors: [Color], from: CGPoint, to: CGPoint, in context: inout GraphicsContext) {
        context.fill(path(points), with: .linearGradient(Gradient(colors: colors), startPoint: from, endPoint: to))
    }

    private func line(_ from: CGPoint, _ to: CGPoint, color: Color, width: CGFloat, in context: inout GraphicsContext) {
        var line = Path()
        line.move(to: from)
        line.addLine(to: to)
        context.stroke(line, with: .color(color), lineWidth: width)
    }
}
