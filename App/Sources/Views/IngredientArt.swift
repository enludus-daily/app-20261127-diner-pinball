import SwiftUI

/// 食材を、つやのある丸い玉として描く（台のバンパー・伝票・まな板・図鑑で同じ絵）
enum IngredientArt {
    static func base(_ kind: Ingredient) -> Color {
        switch kind {
        case .egg: Color(hex: 0xFBF5E6)
        case .tomato: Color(hex: 0xE0463A)
        case .rice: Color(hex: 0xF7F3EA)
        case .meat: Color(hex: 0xC9574B)
        case .onion: Color(hex: 0xE9D3DF)
        case .bread: Color(hex: 0xD99D55)
        case .cheese: Color(hex: 0xF4CB4E)
        case .ham: Color(hex: 0xEE9B9A)
        case .strawberry: Color(hex: 0xE03A50)
        case .scallion: Color(hex: 0x86C063)
        case .shrimp: Color(hex: 0xF2905F)
        case .noodles: Color(hex: 0xF0D98F)
        case .seaweed: Color(hex: 0x2E4A36)
        case .flour: Color(hex: 0xF2ECDF)
        case .butter: Color(hex: 0xF7E08E)
        case .chocolate: Color(hex: 0x6E3F27)
        case .corn: Color(hex: 0xF3C135)
        case .sausage: Color(hex: 0xB8553A)
        case .potato: Color(hex: 0xC9A068)
        case .mushroom: Color(hex: 0x9C6B48)
        case .carrot: Color(hex: 0xEE8A2E)
        case .fish: Color(hex: 0x82A5BA)
        case .lemon: Color(hex: 0xF5D646)
        }
    }

    /// 食材を描く。scale は当たったときの弾み（1〜1.25）
    static func draw(_ kind: Ingredient, in ctx: GraphicsContext, at c: CGPoint, radius r: CGFloat, scale: CGFloat = 1, shadow: Bool = true) {
        let r = r * scale
        let color = base(kind)
        let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        if shadow {
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.95, y: c.y - r * 0.55 + r * 0.35, width: r * 1.9, height: r * 1.5)), with: .color(Theme.ink.opacity(0.22)))
        }
        // つや：左上が明るく右下が濃い
        ctx.fill(disc, with: .radialGradient(Gradient(colors: [color.mix(with: .white, by: 0.35), color, color.mix(with: .black, by: 0.22)]), center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.5))
        var g = ctx
        g.clip(to: disc)
        detail(kind, &g, c, r)
        ctx.stroke(disc, with: .color(color.mix(with: .black, by: 0.35).opacity(0.7)), lineWidth: max(1, r * 0.06))
        // 光の点
        let gloss = Path(ellipseIn: CGRect(x: -r * 0.25, y: -r * 0.15, width: r * 0.5, height: r * 0.3))
            .applying(CGAffineTransform(rotationAngle: -0.44))
            .applying(CGAffineTransform(translationX: c.x - r * 0.37, y: c.y - r * 0.57))
        ctx.fill(gloss, with: .color(.white.opacity(0.7)))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.2, y: c.y - r * 0.78, width: r * 0.12, height: r * 0.12)), with: .color(.white.opacity(0.6)))
    }

    private static func detail(_ kind: Ingredient, _ g: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        func circle(_ x: CGFloat, _ y: CGFloat, _ rr: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x + x * r - rr * r, y: c.y + y * r - rr * r, width: rr * r * 2, height: rr * r * 2)) }
        func line(_ pts: [(CGFloat, CGFloat)]) -> Path {
            var p = Path()
            for (i, q) in pts.enumerated() {
                let pt = CGPoint(x: c.x + q.0 * r, y: c.y + q.1 * r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            return p
        }
        let lw = max(1, r * 0.09)
        switch kind {
        case .egg:
            g.fill(circle(0.08, 0.1, 0.46), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFD45A), Color(hex: 0xF2A531)]), center: CGPoint(x: c.x, y: c.y), startRadius: 0, endRadius: r * 0.5))
        case .tomato, .strawberry, .carrot:
            let leaf = Color(hex: 0x3F8F3A)
            for k in 0..<5 {
                let a = Double(k) / 5 * 2 * .pi - .pi / 2
                g.fill(Path(ellipseIn: CGRect(x: -r * 0.1, y: -r * 0.32, width: r * 0.2, height: r * 0.36)).applying(CGAffineTransform(rotationAngle: a + .pi / 2)).applying(CGAffineTransform(translationX: c.x + cos(a) * r * 0.18, y: c.y - r * 0.72 + sin(a) * r * 0.12)), with: .color(leaf))
            }
            if kind == .strawberry {
                for (x, y) in [(-0.4, -0.1), (0.1, -0.2), (0.45, 0.05), (-0.2, 0.3), (0.25, 0.4), (-0.5, 0.35), (0.0, 0.1)] {
                    g.fill(circle(x, y, 0.06), with: .color(Color(hex: 0xFCE38A)))
                }
            }
            if kind == .carrot {
                for y in [-0.15, 0.15, 0.45] { g.stroke(line([(-0.5, y), (-0.15, y + 0.05)]), with: .color(Color(hex: 0xC7661C)), lineWidth: lw) }
            }
        case .rice:
            for (x, y, a) in [(-0.35, -0.2, 0.3), (0.2, -0.35, -0.4), (0.35, 0.15, 0.8), (-0.1, 0.35, -0.2), (-0.45, 0.25, 1.0), (0.05, 0.0, 0.5)] {
                g.fill(Path(ellipseIn: CGRect(x: -r * 0.08, y: -r * 0.15, width: r * 0.16, height: r * 0.3)).applying(CGAffineTransform(rotationAngle: a)).applying(CGAffineTransform(translationX: c.x + x * r, y: c.y + y * r)), with: .color(.white))
            }
        case .meat, .ham:
            var p = Path()
            p.addArc(center: CGPoint(x: c.x + r * 0.15, y: c.y + r * 0.1), radius: r * 0.45, startAngle: .degrees(200), endAngle: .degrees(20), clockwise: false)
            g.stroke(p, with: .color(.white.opacity(kind == .meat ? 0.8 : 0.55)), lineWidth: r * 0.16)
        case .onion:
            for x in [-0.45, 0.0, 0.45] { g.stroke(line([(x * 0.6, -0.9), (x, 0), (x * 0.6, 0.9)]), with: .color(Color(hex: 0xB98AA8).opacity(0.6)), lineWidth: lw * 0.8) }
            g.fill(circle(0, -0.85, 0.16), with: .color(Color(hex: 0xA9C76A)))
        case .bread:
            g.fill(Path(roundedRect: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.45, width: r * 1.1, height: r * 0.95), cornerRadius: r * 0.3), with: .color(Color(hex: 0xF6E3BE)))
        case .cheese:
            for (x, y, s) in [(-0.35, -0.2, 0.16), (0.3, -0.35, 0.11), (0.25, 0.3, 0.18), (-0.25, 0.4, 0.1)] { g.fill(circle(x, y, s), with: .color(Color(hex: 0xD9A72C))) }
        case .scallion:
            g.fill(Path(CGRect(x: c.x - r, y: c.y + r * 0.2, width: r * 2, height: r)), with: .color(Color(hex: 0xF1F4E2)))
            for x in [-0.4, 0.0, 0.4] { g.stroke(line([(x, -0.9), (x, 0.2)]), with: .color(Color(hex: 0x4E8F38)), lineWidth: lw) }
        case .shrimp:
            for k in 0..<4 {
                var p = Path()
                p.addArc(center: CGPoint(x: c.x + r * 0.3, y: c.y), radius: r * (0.3 + 0.2 * CGFloat(k)), startAngle: .degrees(110), endAngle: .degrees(250), clockwise: false)
                g.stroke(p, with: .color(.white.opacity(0.65)), lineWidth: lw)
            }
        case .noodles:
            for y in [-0.45, -0.15, 0.15, 0.45] {
                var p = Path()
                p.move(to: CGPoint(x: c.x - r, y: c.y + y * r))
                for k in 0..<5 { p.addQuadCurve(to: CGPoint(x: c.x - r + CGFloat(k + 1) * r * 0.4, y: c.y + y * r), control: CGPoint(x: c.x - r + (CGFloat(k) + 0.5) * r * 0.4, y: c.y + y * r + (k % 2 == 0 ? -1 : 1) * r * 0.14)) }
                g.stroke(p, with: .color(Color(hex: 0xC9A750)), lineWidth: lw)
            }
        case .seaweed:
            for y in [-0.4, 0.0, 0.4] { g.stroke(line([(-0.9, y), (0.9, y - 0.1)]), with: .color(Color(hex: 0x6E9A72).opacity(0.6)), lineWidth: lw * 0.7) }
        case .flour:
            g.fill(Path(CGRect(x: c.x - r, y: c.y - r * 0.62, width: r * 2, height: r * 0.16)), with: .color(Color(hex: 0xC79A64)))
            for (x, y) in [(-0.3, 0.1), (0.2, 0.25), (0.0, -0.1), (0.35, -0.05), (-0.15, 0.45)] { g.fill(circle(x, y, 0.05), with: .color(Color(hex: 0xD9CDB5))) }
        case .butter:
            g.fill(Path(roundedRect: CGRect(x: c.x - r * 0.5, y: c.y - r * 0.4, width: r, height: r * 0.8), cornerRadius: r * 0.12), with: .color(Color(hex: 0xFCEFB4)))
            g.stroke(line([(-0.5, -0.4), (-0.2, -0.65), (0.75, -0.65), (0.5, -0.4)]), with: .color(Color(hex: 0xE0C25E)), lineWidth: lw * 0.8)
        case .chocolate:
            for x in [-0.33, 0.33] { g.stroke(line([(x, -1), (x, 1)]), with: .color(Color(hex: 0x4A2716)), lineWidth: lw) }
            for y in [-0.33, 0.33] { g.stroke(line([(-1, y), (1, y)]), with: .color(Color(hex: 0x4A2716)), lineWidth: lw) }
        case .corn:
            for row in 0..<5 { for col in 0..<4 { g.fill(circle(-0.45 + CGFloat(col) * 0.3, -0.6 + CGFloat(row) * 0.28, 0.1), with: .color(Color(hex: 0xFBDD6E))) } }
            g.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.3, y: c.y + r * 0.3, width: r * 0.9, height: r * 1.2)), with: .color(Color(hex: 0x7DAA4C)))
        case .sausage:
            for k in -1...1 { g.stroke(line([(CGFloat(k) * 0.4 - 0.2, -0.5), (CGFloat(k) * 0.4 + 0.2, 0.5)]), with: .color(Color(hex: 0x7A3020)), lineWidth: lw) }
        case .potato:
            for (x, y) in [(-0.35, -0.25), (0.3, 0.05), (-0.1, 0.4), (0.4, -0.45)] { g.fill(circle(x, y, 0.07), with: .color(Color(hex: 0x8F6B3E))) }
        case .mushroom:
            g.fill(Path(CGRect(x: c.x - r * 0.28, y: c.y, width: r * 0.56, height: r)), with: .color(Color(hex: 0xF3E6CF)))
            for (x, y) in [(-0.4, -0.35), (0.25, -0.5), (0.45, -0.1), (-0.05, -0.15)] { g.fill(circle(x, y, 0.1), with: .color(Color(hex: 0xF3E6CF))) }
        case .fish:
            g.fill(circle(-0.45, -0.1, 0.12), with: .color(.white))
            g.fill(circle(-0.45, -0.1, 0.06), with: .color(Theme.ink))
            for x in [0.0, 0.25] { g.stroke(line([(x, -0.6), (x - 0.15, 0), (x, 0.6)]), with: .color(Color(hex: 0x5A7C92)), lineWidth: lw * 0.8) }
        case .lemon:
            g.fill(circle(0, 0, 0.7), with: .color(Color(hex: 0xFCEB9A)))
            for k in 0..<6 {
                let a = Double(k) / 6 * 2 * .pi
                g.stroke(line([(0, 0), (CGFloat(cos(a)) * 0.68, CGFloat(sin(a)) * 0.68)]), with: .color(Color(hex: 0xF5D646)), lineWidth: lw)
            }
        }
    }
}

/// 食材の絵 1 つ（伝票・まな板・図鑑で使う）
struct IngredientIcon: View {
    let kind: Ingredient
    var size: CGFloat = 22

    var body: some View {
        Canvas { ctx, s in
            IngredientArt.draw(kind, in: ctx, at: CGPoint(x: s.width / 2, y: s.height / 2), radius: min(s.width, s.height) / 2 - 1, shadow: false)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(kind.name)
    }
}

/// 料理の皿（図鑑・結果）。材料の色を皿の上に並べる
struct DishPlate: View {
    let dish: Dish
    var size: CGFloat = 64
    var known = true

    var body: some View {
        Canvas { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let r = min(s.width, s.height) / 2 - 2
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.9 + r * 0.12, width: r * 2, height: r * 1.9)), with: .color(Theme.ink.opacity(0.15)))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r * 0.78, y: c.y - r * 0.78, width: r * 1.56, height: r * 1.56)), with: .color(Theme.paperLine), lineWidth: 1)
            guard known else {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.55, width: r * 1.1, height: r * 1.1)), with: .color(Theme.paperLine))
                return
            }
            let items = dish.lines.flatMap { k, n in Array(repeating: k, count: n) }
            for (i, k) in items.enumerated() {
                let a = Double(i) / Double(max(1, items.count)) * 2 * .pi - .pi / 2
                let d = items.count == 1 ? 0 : r * 0.36
                IngredientArt.draw(k, in: ctx, at: CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d), radius: r * (items.count > 3 ? 0.3 : 0.36), shadow: false)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(known ? dish.name : tr("まだ作っていない料理", "Not cooked yet"))
    }
}
