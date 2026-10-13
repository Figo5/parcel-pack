import SwiftUI
#if SWIFT_PACKAGE
import ParcelCore
#endif

/// The depot is drawn from the player's actual building and equipment levels.
struct DepotScene: View {
    let account: TycoonAccount

    private var stage: Int { account.stage.rawValue }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 360, size.height / 224)
            context.translateBy(x: (size.width - 360 * scale) / 2, y: (size.height - 224 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            drawDepot(in: &context)
        }
        .aspectRatio(360.0 / 224.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your \(account.stage.title), workbench level \(account.level(.workbench)), shelves level \(account.level(.shelves)), delivery van level \(account.level(.van))")
    }

    private func drawDepot(in context: inout GraphicsContext) {
        let left = CGPoint(x: 24, y: 126)
        let back = CGPoint(x: 176, y: 66)
        let right = CGPoint(x: 338, y: 125)
        let front = CGPoint(x: 185, y: 189)
        polygon([CGPoint(x: 30, y: 144), CGPoint(x: 183, y: 205), CGPoint(x: 344, y: 140), CGPoint(x: 187, y: 81)],
                color: Palette.ink.opacity(0.07), in: &context)
        polygon([CGPoint(x: 24, y: 76), CGPoint(x: 176, y: 16), back, left],
                color: stage < 2 ? Color(hex: 0xE9DCC8) : Color(hex: 0xD6E0D6), in: &context)
        polygon([CGPoint(x: 176, y: 16), CGPoint(x: 338, y: 75), right, back],
                color: stage < 2 ? Color(hex: 0xF0E5D3) : Color(hex: 0xE8EEE4), in: &context)
        polygon([left, back, right, front], color: Color(hex: stage < 2 ? 0xD3BD98 : 0xC4C8B4), in: &context)
        polygon([left, front, CGPoint(x: 185, y: 197), CGPoint(x: 24, y: 134)], color: Color(hex: 0xB29C7D), in: &context)
        polygon([front, right, CGPoint(x: 338, y: 133), CGPoint(x: 185, y: 197)], color: Color(hex: 0x9FAD99), in: &context)

        // Floor joints follow the room's two axes.
        for step in 1..<6 {
            let fraction = CGFloat(step) / 6
            line(from: interpolate(left, back, fraction), to: interpolate(front, right, fraction),
                 color: Palette.ink.opacity(0.08), width: 1, in: &context)
            line(from: interpolate(left, front, fraction), to: interpolate(back, right, fraction),
                 color: Palette.ink.opacity(0.08), width: 1, in: &context)
        }

        if stage == 0 {
            // A sunny spare room, before the business has a loading bay.
            polygon([CGPoint(x: 235, y: 53), CGPoint(x: 275, y: 67), CGPoint(x: 275, y: 96), CGPoint(x: 235, y: 82)],
                    color: Color(hex: 0x9DCBC6), in: &context)
            line(from: CGPoint(x: 255, y: 60), to: CGPoint(x: 255, y: 89), color: Palette.surface, width: 3, in: &context)
            line(from: CGPoint(x: 235, y: 67), to: CGPoint(x: 275, y: 81), color: Palette.surface, width: 3, in: &context)
            plant(at: CGPoint(x: 300, y: 123), in: &context)
        } else {
            loadingBay(at: CGPoint(x: 254, y: 66), large: stage >= 3, in: &context)
            if stage >= 2 {
                polygon([CGPoint(x: 255, y: 124), CGPoint(x: 292, y: 137), CGPoint(x: 262, y: 150), CGPoint(x: 225, y: 136)],
                        color: Color(hex: 0xE0B952), in: &context)
                for index in 0..<4 {
                    let x = CGFloat(index) * 8
                    line(from: CGPoint(x: 232 + x, y: 134 + x * 0.35), to: CGPoint(x: 240 + x, y: 130 + x * 0.35),
                         color: Palette.ink.opacity(0.35), width: 3, in: &context)
                }
            }
        }

        let rackCount = min(4, 1 + stage / 2 + account.level(.shelves) / 4)
        for rack in (0..<rackCount).reversed() {
            shelf(at: CGPoint(x: 42 + CGFloat(rack) * 30, y: 113 - CGFloat(rack) * 12),
                  stocked: min(6, 2 + account.level(.shelves)), in: &context)
        }

        let deskCount = min(3, 1 + account.level(.workbench) / 4)
        for index in 0..<deskCount {
            workbench(at: CGPoint(x: 130 + CGFloat(index) * 50, y: 133 + CGFloat(index) * 17),
                      upgraded: account.level(.workbench) > 0, in: &context)
        }
        for index in 0..<min(6, 1 + stage + account.level(.shelves) / 4) {
            box(at: CGPoint(x: 214 + CGFloat(index % 3) * 17, y: 163 + CGFloat(index % 3) * 6 - CGFloat(index / 3) * 17),
                width: 17, height: 14, color: Palette.cardboard, in: &context)
        }

        if account.level(.van) > 0 {
            van(at: CGPoint(x: 274, y: 174), upgraded: account.level(.van) >= 5, in: &context)
        } else {
            box(at: CGPoint(x: 283, y: 173), width: 20, height: 18, color: Color(hex: 0xD4AF78), in: &context)
            box(at: CGPoint(x: 307, y: 183), width: 16, height: 13, color: Palette.cardboard, in: &context)
        }

        if stage >= 3 {
            polygon([CGPoint(x: 168, y: 32), CGPoint(x: 178, y: 28), CGPoint(x: 331, y: 84), CGPoint(x: 321, y: 88)],
                    color: Palette.accent, in: &context)
            line(from: CGPoint(x: 324, y: 87), to: CGPoint(x: 324, y: 127), color: Palette.accent, width: 5, in: &context)
        }
        if stage == 4 {
            shelf(at: CGPoint(x: 290, y: 122), stocked: 6, in: &context)
            polygon([CGPoint(x: 165, y: 55), CGPoint(x: 194, y: 65), CGPoint(x: 194, y: 85), CGPoint(x: 165, y: 75)],
                    color: Palette.surface, in: &context)
            context.draw(Text("HUB").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(Palette.accent),
                         at: CGPoint(x: 179, y: 71))
        }
    }

    private func shelf(at origin: CGPoint, stocked: Int, in context: inout GraphicsContext) {
        let x = origin.x, y = origin.y
        polygon([CGPoint(x: x - 12, y: y - 45), CGPoint(x: x + 11, y: y - 54), CGPoint(x: x + 11, y: y), CGPoint(x: x - 12, y: y + 9)],
                color: Color(hex: 0x899F8B), in: &context)
        for row in 0..<3 {
            let top = y - CGFloat(row) * 17
            line(from: CGPoint(x: x - 12, y: top + 4), to: CGPoint(x: x + 11, y: top - 5),
                 color: Palette.ink.opacity(0.45), width: 3, in: &context)
            for column in 0..<2 where row * 2 + column < stocked {
                let bx = x - 9 + CGFloat(column) * 11
                box(at: CGPoint(x: bx, y: top - 3 - CGFloat(column) * 4), width: 10, height: 10,
                    color: Palette.parcel(row + column), in: &context)
            }
        }
        line(from: CGPoint(x: x - 12, y: y - 45), to: CGPoint(x: x - 12, y: y + 10), color: Palette.ink.opacity(0.4), width: 3, in: &context)
        line(from: CGPoint(x: x + 11, y: y - 54), to: CGPoint(x: x + 11, y: y), color: Palette.ink.opacity(0.4), width: 3, in: &context)
    }

    private func workbench(at origin: CGPoint, upgraded: Bool, in context: inout GraphicsContext) {
        let x = origin.x, y = origin.y
        for corner in [CGPoint(x: x - 27, y: y), CGPoint(x: x + 3, y: y + 11), CGPoint(x: x + 29, y: y)] {
            line(from: corner, to: CGPoint(x: corner.x, y: corner.y + 22), color: Palette.ink.opacity(0.75), width: 4, in: &context)
        }
        polygon([CGPoint(x: x - 31, y: y - 4), CGPoint(x: x - 4, y: y - 16), CGPoint(x: x + 32, y: y - 4), CGPoint(x: x + 5, y: y + 9)],
                color: upgraded ? Color(hex: 0x86B2A1) : Color(hex: 0xDCB780), in: &context)
        polygon([CGPoint(x: x - 31, y: y - 4), CGPoint(x: x + 5, y: y + 9), CGPoint(x: x + 5, y: y + 13), CGPoint(x: x - 31, y: y)],
                color: upgraded ? Palette.accent : Color(hex: 0xBB9364), in: &context)
        box(at: CGPoint(x: x - 7, y: y - 9), width: 19, height: 12, color: Palette.cardboard, in: &context)
        if upgraded {
            context.fill(Path(roundedRect: CGRect(x: x + 12, y: y - 9, width: 10, height: 5), cornerRadius: 2), with: .color(Palette.surface))
        }
    }

    private func box(at origin: CGPoint, width: CGFloat, height: CGFloat, color: Color, in context: inout GraphicsContext) {
        let x = origin.x, y = origin.y, half = width / 2, depth = width * 0.32
        polygon([CGPoint(x: x, y: y - height), CGPoint(x: x + half, y: y - height - depth), CGPoint(x: x + width, y: y - height), CGPoint(x: x + half, y: y - height + depth)],
                color: color, in: &context)
        polygon([CGPoint(x: x, y: y - height), CGPoint(x: x + half, y: y - height + depth), CGPoint(x: x + half, y: y + depth), CGPoint(x: x, y: y)],
                color: color.opacity(0.8), in: &context)
        polygon([CGPoint(x: x + half, y: y - height + depth), CGPoint(x: x + width, y: y - height), CGPoint(x: x + width, y: y), CGPoint(x: x + half, y: y + depth)],
                color: color.opacity(0.62), in: &context)
        line(from: CGPoint(x: x + width * 0.26, y: y - height - depth * 0.5),
             to: CGPoint(x: x + width * 0.76, y: y - height + depth * 0.5), color: Palette.surface.opacity(0.8), width: 2, in: &context)
    }

    private func loadingBay(at origin: CGPoint, large: Bool, in context: inout GraphicsContext) {
        let x = origin.x, y = origin.y, width: CGFloat = large ? 53 : 42
        polygon([CGPoint(x: x, y: y), CGPoint(x: x + width, y: y + width * 0.36), CGPoint(x: x + width, y: y + width * 0.36 + 34), CGPoint(x: x, y: y + 34)],
                color: Color(hex: 0xA1AFA0), in: &context)
        for row in 1..<5 {
            line(from: CGPoint(x: x + 2, y: y + CGFloat(row) * 6),
                 to: CGPoint(x: x + width - 2, y: y + width * 0.36 + CGFloat(row) * 6),
                 color: Palette.ink.opacity(0.22), width: 1, in: &context)
        }
        if !large {
            polygon([CGPoint(x: x - 2, y: y - 4), CGPoint(x: x + width + 2, y: y + width * 0.36 - 4),
                     CGPoint(x: x + width + 2, y: y + width * 0.36 + 3), CGPoint(x: x - 2, y: y + 3)],
                    color: Palette.accent, in: &context)
        }
    }

    private func van(at origin: CGPoint, upgraded: Bool, in context: inout GraphicsContext) {
        let x = origin.x, y = origin.y
        let color = upgraded ? Color(hex: 0x267B61) : Color(hex: 0x70A69C)
        context.fill(Path(roundedRect: CGRect(x: x, y: y - 22, width: 50, height: 25), cornerRadius: 5), with: .color(color))
        polygon([CGPoint(x: x + 36, y: y - 22), CGPoint(x: x + 54, y: y - 15), CGPoint(x: x + 58, y: y + 3), CGPoint(x: x + 36, y: y + 3)],
                color: Palette.accent, in: &context)
        polygon([CGPoint(x: x + 39, y: y - 19), CGPoint(x: x + 51, y: y - 14), CGPoint(x: x + 53, y: y - 6), CGPoint(x: x + 39, y: y - 6)],
                color: Color(hex: 0xD8E9E2), in: &context)
        for wheel in [x + 10, x + 46] {
            context.fill(Path(ellipseIn: CGRect(x: wheel - 5, y: y - 1, width: 10, height: 10)), with: .color(Palette.ink))
            context.fill(Path(ellipseIn: CGRect(x: wheel - 2, y: y + 2, width: 4, height: 4)), with: .color(Palette.surface))
        }
        context.draw(Text(Image(systemName: "shippingbox.fill")).font(.system(size: 12)).foregroundStyle(Palette.surface),
                     at: CGPoint(x: x + 20, y: y - 10))
    }

    private func plant(at origin: CGPoint, in context: inout GraphicsContext) {
        context.fill(Path(roundedRect: CGRect(x: origin.x - 6, y: origin.y - 6, width: 12, height: 13), cornerRadius: 3), with: .color(Palette.parcel(0)))
        for leaf in [CGFloat(-1), 0, 1] {
            context.fill(Path(ellipseIn: CGRect(x: origin.x - 5 + leaf * 5, y: origin.y - 22 - abs(leaf) * 3, width: 9, height: 18)), with: .color(Palette.accent))
        }
    }

    private func polygon(_ points: [CGPoint], color: Color, in context: inout GraphicsContext) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    private func line(from: CGPoint, to: CGPoint, color: Color, width: CGFloat, in context: inout GraphicsContext) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private func interpolate(_ from: CGPoint, _ to: CGPoint, _ fraction: CGFloat) -> CGPoint {
        CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction)
    }
}
