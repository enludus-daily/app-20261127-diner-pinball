import SwiftUI

/// 台の座標（360 × 600）を画面の大きさに合わせる
struct TableFrame {
    let scale: CGFloat
    let origin: CGPoint

    init(size: CGSize) {
        scale = min(size.width / TableGeometry.width, size.height / TableGeometry.height)
        origin = CGPoint(x: (size.width - TableGeometry.width * scale) / 2, y: (size.height - TableGeometry.height * scale) / 2)
    }

    func pt(_ v: Vec) -> CGPoint { CGPoint(x: origin.x + v.x * scale, y: origin.y + v.y * scale) }
    func len(_ d: Double) -> CGFloat { d * scale }
}

/// 台の止まった部分（板・壁・スリング・鍋・こしょうひき・おたま）。1 回だけ描く
struct TableStatic: View {
    let stall: Stall

    var body: some View {
        Canvas { ctx, size in
            let f = TableFrame(size: size)
            TableStatic.draw(ctx, f, stall)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func outline(_ f: TableFrame) -> Path {
        var p = Path()
        p.move(to: f.pt(Vec(14, 600)))
        p.addLine(to: f.pt(Vec(14, 112)))
        for v in TableGeometry.arch.dropFirst() { p.addLine(to: f.pt(v)) }
        p.addLine(to: f.pt(Vec(346, 600)))
        p.closeSubpath()
        return p
    }

    static func draw(_ ctx: GraphicsContext, _ f: TableFrame, _ stall: Stall) {
        let wood = Theme.playfield(stall.wood)
        let shape = outline(f)
        // 板（上から下へ少し暗く）
        ctx.fill(shape, with: .linearGradient(Gradient(colors: [wood.top.mix(with: .white, by: 0.12), wood.top, wood.top.mix(with: Theme.woodDeep, by: 0.18)]), startPoint: f.pt(Vec(180, 0)), endPoint: f.pt(Vec(180, 600))))
        var g = ctx
        g.clip(to: shape)
        // 板の継ぎ目と木目
        var y = 20.0
        var row = 0
        while y < 600 {
            g.fill(Path(CGRect(origin: f.pt(Vec(0, y)), size: CGSize(width: f.len(360), height: max(0.8, f.len(1))))), with: .color(wood.grain.opacity(0.45)))
            let off = row % 2 == 0 ? 70.0 : 170.0
            var x = off
            while x < 360 {
                g.fill(Path(CGRect(origin: f.pt(Vec(x, y)), size: CGSize(width: max(0.8, f.len(1)), height: f.len(44)))), with: .color(wood.grain.opacity(0.3)))
                x += 190
            }
            for k in 1...2 {
                var path = Path()
                let gy = y + Double(k) * 14
                path.move(to: f.pt(Vec(0, gy)))
                var gx = 0.0
                while gx < 360 {
                    gx += 45
                    path.addQuadCurve(to: f.pt(Vec(gx, gy + (k == 1 ? 1.5 : -1.5))), control: f.pt(Vec(gx - 22, gy + (row % 2 == 0 ? 3 : -3))))
                }
                g.stroke(path, with: .color(wood.grain.opacity(0.18)), lineWidth: max(0.6, f.len(0.8)))
            }
            y += 44
            row += 1
        }
        // 店の名前（板に焼きつけた文字）
        let name = Text(stall.name).font(Theme.sign(f.len(17))).foregroundStyle(Theme.woodDeep.opacity(0.32))
        g.draw(name, at: f.pt(Vec(180, 72)))
        // 下の落ちる所（暗い溝）
        g.fill(Path(CGRect(origin: f.pt(Vec(0, 578)), size: CGSize(width: f.len(360), height: f.len(30)))), with: .linearGradient(Gradient(colors: [.clear, Theme.ink.opacity(0.45)]), startPoint: f.pt(Vec(0, 572)), endPoint: f.pt(Vec(0, 600))))

        // 鍋（真上から：銅のふち・取っ手・スープ）
        let pot = f.pt(TableGeometry.pot)
        let pr = f.len(TableGeometry.potRadius)
        for dx in [-1.0, 1.0] {
            ctx.fill(Path(roundedRect: CGRect(x: pot.x + dx * pr * 1.05 - (dx < 0 ? pr * 0.5 : 0), y: pot.y - pr * 0.2, width: pr * 0.5, height: pr * 0.4), cornerRadius: pr * 0.15), with: .color(Theme.copperDeep))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: pot.x - pr * 1.12, y: pot.y - pr * 1.0, width: pr * 2.24, height: pr * 2.3)), with: .color(Theme.ink.opacity(0.25)))
        ctx.fill(Path(ellipseIn: CGRect(x: pot.x - pr * 1.12, y: pot.y - pr * 1.12, width: pr * 2.24, height: pr * 2.24)), with: .linearGradient(Gradient(colors: [Theme.copperLight, Theme.copper, Theme.copperDeep]), startPoint: CGPoint(x: pot.x - pr, y: pot.y - pr), endPoint: CGPoint(x: pot.x + pr, y: pot.y + pr)))
        ctx.fill(Path(ellipseIn: CGRect(x: pot.x - pr * 0.86, y: pot.y - pr * 0.86, width: pr * 1.72, height: pr * 1.72)), with: .radialGradient(Gradient(colors: [Color(hex: 0xC9762F), Color(hex: 0x7A3A17)]), center: pot, startRadius: 0, endRadius: pr))

        // こしょうひき（上の小さな柱）
        let pep = f.pt(TableGeometry.pepper)
        let rr = f.len(TableGeometry.pepperRadius)
        ctx.fill(Path(ellipseIn: CGRect(x: pep.x - rr, y: pep.y - rr * 0.6, width: rr * 2, height: rr * 2)), with: .color(Theme.ink.opacity(0.25)))
        ctx.fill(Path(ellipseIn: CGRect(x: pep.x - rr, y: pep.y - rr, width: rr * 2, height: rr * 2)), with: .radialGradient(Gradient(colors: [Color(hex: 0x9A6440), Color(hex: 0x4E2C18)]), center: CGPoint(x: pep.x - rr * 0.3, y: pep.y - rr * 0.3), startRadius: 0, endRadius: rr * 1.3))
        ctx.fill(Path(ellipseIn: CGRect(x: pep.x - rr * 0.35, y: pep.y - rr * 0.35, width: rr * 0.7, height: rr * 0.7)), with: .color(Theme.copperLight))

        // おたま（玉が出てくる所）
        let ladle = f.pt(TableGeometry.serve)
        var handle = Path()
        handle.move(to: CGPoint(x: ladle.x + f.len(10), y: ladle.y - f.len(4)))
        handle.addLine(to: CGPoint(x: ladle.x + f.len(48), y: ladle.y - f.len(20)))
        ctx.stroke(handle, with: .color(Color(hex: 0xA9B0B5)), style: StrokeStyle(lineWidth: f.len(5), lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: ladle.x - f.len(13), y: ladle.y - f.len(11), width: f.len(26), height: f.len(22))), with: .radialGradient(Gradient(colors: [Color(hex: 0xEEF1F3), Color(hex: 0x9AA3A9)]), center: ladle, startRadius: 0, endRadius: f.len(14)))

        // 壁のふち（銅の縁どり）
        var rim = Path()
        rim.move(to: f.pt(Vec(14, 455)))
        rim.addLine(to: f.pt(Vec(14, 112)))
        for v in TableGeometry.arch.dropFirst() { rim.addLine(to: f.pt(v)) }
        rim.addLine(to: f.pt(Vec(346, 455)))
        ctx.stroke(rim, with: .color(Theme.copperDeep), style: StrokeStyle(lineWidth: f.len(7), lineCap: .round, lineJoin: .round))
        ctx.stroke(rim, with: .color(Theme.copperLight), style: StrokeStyle(lineWidth: f.len(2.5), lineCap: .round, lineJoin: .round))
        // 下の案内の坂
        for (a, b) in [(Vec(14, 455), Vec(96, 527)), (Vec(346, 455), Vec(264, 527))] {
            var p = Path()
            p.move(to: f.pt(a))
            p.addLine(to: f.pt(b))
            ctx.stroke(p, with: .color(Theme.copperDeep), style: StrokeStyle(lineWidth: f.len(7), lineCap: .round))
            ctx.stroke(p, with: .color(Theme.copperLight), style: StrokeStyle(lineWidth: f.len(2.5), lineCap: .round))
        }
        // スリング（クリームの台にトマト色のゴム）
        for tri in [TableGeometry.leftSling, TableGeometry.rightSling] {
            var p = Path()
            p.move(to: f.pt(tri[0]))
            p.addLine(to: f.pt(tri[1]))
            p.addLine(to: f.pt(tri[2]))
            p.closeSubpath()
            ctx.fill(p, with: .color(Theme.paper))
            ctx.stroke(p, with: .color(Theme.woodDeep.opacity(0.6)), lineWidth: f.len(1.5))
            var band = Path()
            band.move(to: f.pt(tri[0]))
            band.addLine(to: f.pt(tri[2]))
            ctx.stroke(band, with: .color(Theme.tomato), style: StrokeStyle(lineWidth: f.len(4), lineCap: .round))
        }
    }
}

/// 台の動く部分（食材の弾み・狙いの光・フリッパー・玉・湯気・点の文字）。毎こま描くのはここだけ
struct TableDynamic: View {
    let model: AppModel

    var body: some View {
        // frame が変わったときだけ描き直す（止めている間は変わらない）
        let _ = model.frame
        Canvas { ctx, size in
            let f = TableFrame(size: size)
            draw(ctx, f)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ ctx: GraphicsContext, _ f: TableFrame) {
        let game = model.game
        let stall = game.stall
        let wanted = Set(model.hintsOn ? game.shift.wanted : [])
        let clock = model.clock
        // 食材のバンパー
        for (i, pos) in game.physics.bumpers.enumerated() {
            let kind = stall.ingredients[i]
            let c = f.pt(pos)
            let r = f.len(TableGeometry.bumperRadius)
            let glow = game.physics.bumperGlow[i]
            if wanted.contains(kind) {
                let pulse = 1 + 0.06 * sin(clock * 6)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r * 1.28 * pulse, y: c.y - r * 1.28 * pulse, width: r * 2.56 * pulse, height: r * 2.56 * pulse)), with: .color(Theme.yolk), style: StrokeStyle(lineWidth: f.len(3), dash: [f.len(6), f.len(5)]))
            }
            let bounce = glow > 0 ? 1 + 0.25 * sin(glow / 0.35 * .pi) : 1
            IngredientArt.draw(kind, in: ctx, at: c, radius: r, scale: bounce)
        }
        // 鍋：出せるときは光る、玉が入ったら湯気
        let pot = f.pt(TableGeometry.pot)
        let pr = f.len(TableGeometry.potRadius)
        if game.shift.canServe {
            let a = 0.55 + 0.35 * sin(clock * 7)
            ctx.stroke(Path(ellipseIn: CGRect(x: pot.x - pr * 1.45, y: pot.y - pr * 1.45, width: pr * 2.9, height: pr * 2.9)), with: .color(Theme.yolk.opacity(a)), lineWidth: f.len(4))
        }
        if game.ballInPot || model.steam > 0 {
            for k in 0..<4 {
                let t = (clock * 0.9 + Double(k) * 0.25).truncatingRemainder(dividingBy: 1)
                let x = pot.x + CGFloat(sin(clock * 3 + Double(k) * 1.7)) * pr * 0.5
                let yy = pot.y - pr * 0.4 - CGFloat(t) * pr * 2.8
                let s = pr * (0.35 + 0.5 * t)
                ctx.fill(Path(ellipseIn: CGRect(x: x - s, y: yy - s, width: s * 2, height: s * 2)), with: .color(.white.opacity(0.55 * (1 - t))))
            }
        }
        // フリッパー（フライ返し）
        for fl in game.physics.flippers {
            let a = f.pt(fl.pivot), b = f.pt(fl.tip)
            var p = Path()
            p.move(to: a)
            p.addLine(to: b)
            ctx.stroke(p, with: .color(Theme.ink.opacity(0.25)), style: StrokeStyle(lineWidth: f.len(15), lineCap: .round))
            ctx.stroke(p, with: .color(Theme.copperDeep), style: StrokeStyle(lineWidth: f.len(13), lineCap: .round))
            ctx.stroke(p, with: .linearGradient(Gradient(colors: [Theme.copperLight, Theme.copper]), startPoint: a, endPoint: b), style: StrokeStyle(lineWidth: f.len(9), lineCap: .round))
            // フライ返しの穴
            for t in [0.45, 0.62, 0.79] {
                let q = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - f.len(1.6), y: q.y - f.len(1.6), width: f.len(3.2), height: f.len(3.2))), with: .color(Theme.copperDeep))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: a.x - f.len(5), y: a.y - f.len(5), width: f.len(10), height: f.len(10))), with: .color(Theme.woodDeep))
        }
        // 玉（銀のスプーンの丸）
        if game.physics.inPlay {
            let c = f.pt(game.physics.ball)
            let r = f.len(TableGeometry.ballRadius)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.9, y: c.y - r * 0.5, width: r * 2, height: r * 1.8)), with: .color(Theme.ink.opacity(0.25)))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .radialGradient(Gradient(colors: [.white, Color(hex: 0xC7CED3), Color(hex: 0x6F7A82)]), center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.4))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.5, y: c.y - r * 0.6, width: r * 0.45, height: r * 0.3)), with: .color(.white.opacity(0.9)))
        }
        // 点の文字（浮いて消える）
        for pop in model.pops {
            let age = clock - pop.born
            guard age >= 0 && age < 1.1 else { continue }
            var c = f.pt(pop.at)
            c.y -= CGFloat(age) * f.len(36)
            let text = Text(pop.text).font(Theme.number(f.len(pop.big ? 20 : 14))).foregroundStyle(pop.color)
            var g = ctx
            g.opacity = 1 - max(0, age - 0.6) / 0.5
            g.draw(text, at: c)
        }
    }
}
