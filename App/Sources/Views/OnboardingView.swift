import SwiftUI

/// はじめての 3 ページ（動く見本：台の上で玉が食材に当たる）
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let page = model.onboardingPage
        ZStack {
            TileWall().ignoresSafeArea()
            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(i == page ? Theme.copper : Theme.paperLine).frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                .padding(.top, 12)
                Group {
                    switch page {
                    case 0: pageOne
                    case 1: pageTwo
                    default: pageThree
                    }
                }
                .frame(maxWidth: 520)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .id(page)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: page)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if page < 2 {
                    Button(tr("つぎへ", "Next")) { model.onboardingPage += 1; model.pressTick += 1 }
                        .buttonStyle(CopperButtonStyle())
                        .accessibilityIdentifier("main.onboardNext")
                } else {
                    Button(tr("開店する", "Open the kitchen")) { model.pressTick += 1; model.onboarded = true }
                        .buttonStyle(CopperButtonStyle())
                        .accessibilityIdentifier("main.onboardStart")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: 560)
        }
    }

    private func heading(_ title: String, _ body: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(Theme.sign(25))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(body)
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pageOne: some View {
        VStack(spacing: 16) {
            heading(tr("フライ返しで、食材をはじく", "Flip the ball into the food"), tr("画面の左右をタップすると、下のフライ返しが上がる。玉が食材に当たると、まな板に 1 つのる。", "Tap the left or right side to raise the spatulas. Each ingredient you hit lands on your board."))
            OnboardingTable()
                .frame(height: 300)
        }
    }

    private var pageTwo: some View {
        VStack(spacing: 16) {
            heading(tr("伝票の材料をそろえる", "Gather what the ticket asks for"), tr("お客は 3 人まで。待たせすぎると帰ってしまう。光っている食材がいま要るもの。", "Up to three guests at once. Keep them waiting too long and they leave. Glowing ingredients are what you need."))
            HStack(spacing: 8) {
                ForEach(Array(Kitchen.stall("diner").dishes.prefix(3).enumerated()), id: \.offset) { i, dish in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            CustomerFace(mood: i, seed: i * 5 + 1).frame(width: 20, height: 20)
                            Text(dish.name).font(Theme.title(12)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                        }
                        Rectangle().fill(Theme.tomato.opacity(0.7)).frame(height: 1.5)
                        HStack(spacing: 2) {
                            ForEach(Array(dish.lines.enumerated()), id: \.offset) { _, line in
                                IngredientIcon(kind: line.0, size: 18)
                                Text("\(line.1)").font(Theme.hand(12)).foregroundStyle(Theme.ink)
                            }
                        }
                        Capsule().fill(Theme.mood(i)).frame(height: 5).frame(maxWidth: .infinity, alignment: .leading).scaleEffect(x: [0.9, 0.45, 0.15][i], anchor: .leading)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(TicketShape().fill(Theme.paper).shadow(color: Theme.ink.opacity(0.2), radius: 0, y: 2))
                }
            }
            HStack(spacing: 6) {
                ForEach([Ingredient.egg, .egg, .tomato], id: \.self) { k in IngredientIcon(kind: k, size: 34) }
                Spacer()
                Text(tr("まな板（6 つまで）", "Board (holds 6)")).font(Theme.body(12, .bold)).foregroundStyle(Theme.inkSoft)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.woodLight))
        }
    }

    private var pageThree: some View {
        VStack(spacing: 16) {
            heading(tr("鍋に落として、あがり！", "Drop it in the pot. Order up!"), tr("材料がそろったら、真ん中の銅の鍋をねらう。3 分の営業で、何品出せるか。毎日ちがう献立が届く。", "When the ticket is complete, aim for the copper pot in the middle. How many dishes can you serve in 3 minutes? A new menu every day."))
            ZStack {
                Circle().fill(Theme.copper).frame(width: 130, height: 130)
                Circle().fill(Color(hex: 0x8C4521)).frame(width: 104, height: 104)
                DishPlate(dish: Kitchen.stall("diner").dishes[0], size: 84)
            }
            .padding(.vertical, 8)
            Text(tr("記録は端末の中だけ。ログイン・広告はありません。", "Records stay on your device. No login, no ads."))
                .font(Theme.body(12, .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

/// 案内の動く見本：玉が食材に当たって弾む（表示中だけ動く。動きを減らす設定なら止まった絵）
struct OnboardingTable: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stall = Kitchen.stall("diner")
    @State private var start = Date()

    var body: some View {
        if reduceMotion || Launch.scene != nil || Launch.isFreshUITest {
            frame(at: 0.8)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                frame(at: ctx.date.timeIntervalSince(start).truncatingRemainder(dividingBy: 2.4))
            }
        }
    }

    /// t 秒目の絵：玉が左のフライ返しから右上の食材へ飛んで弾む
    private func frame(at t: Double) -> some View {
        Canvas { ctx, size in
            let f = TableFrame(size: size)
            TableStatic.draw(ctx, f, stall)
            let target = stall.layout.positions[1]
            let from = Vec(150, 520)
            let p: Vec
            if t < 0.9 {
                let k = t / 0.9
                p = from + (target + Vec(-20, 26) - from) * k
            } else {
                let k = min(1, (t - 0.9) / 1.0)
                p = target + Vec(-20, 26) + Vec(-80, 120) * k
            }
            for (i, pos) in stall.layout.positions.enumerated() {
                let bounce = i == 1 && t > 0.9 && t < 1.25 ? 1 + 0.25 * sin((t - 0.9) / 0.35 * .pi) : 1
                IngredientArt.draw(stall.ingredients[i], in: ctx, at: f.pt(pos), radius: f.len(TableGeometry.bumperRadius), scale: bounce)
            }
            var fl = Flipper(side: .left)
            if t < 0.15 { fl.angle = TableGeometry.upAngle }
            let fr = Flipper(side: .right)
            for flp in [fl, fr] {
                var path = Path()
                path.move(to: f.pt(flp.pivot))
                path.addLine(to: f.pt(flp.tip))
                ctx.stroke(path, with: .color(Theme.copper), style: StrokeStyle(lineWidth: f.len(11), lineCap: .round))
            }
            let c = f.pt(p)
            let r = f.len(TableGeometry.ballRadius)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .radialGradient(Gradient(colors: [.white, Color(hex: 0x8D979E)]), center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.3))
            if t > 0.9 && t < 1.7 {
                let text = Text("+" + stall.ingredients[1].name).font(Theme.number(f.len(16))).foregroundStyle(Theme.woodDeep)
                ctx.draw(text, at: f.pt(target + Vec(0, -40 - (t - 0.9) * 30)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .accessibilityLabel(tr("見本：玉が食材に当たる", "Example: the ball hits an ingredient"))
    }
}
