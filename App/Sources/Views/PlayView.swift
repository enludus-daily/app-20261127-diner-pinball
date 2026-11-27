import SwiftUI

/// 遊ぶ画面：上に伝票 3 枚、まんなかに台、下にまな板。画面の左右のタップでフライ返し。
/// 広い画面（size class regular。iPhone Duo の内側など）は、左に台・右に伝票とまな板
struct PlayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            WoodBackground(top: Theme.wood, grain: Theme.woodGrain).ignoresSafeArea()
            if sizeClass == .regular {
                HStack(spacing: 14) {
                    table
                    VStack(spacing: 12) {
                        TopBar()
                        VStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { i in TicketView(slot: i, wide: true) }
                        }
                        CuttingBoard()
                        Spacer(minLength: 0)
                    }
                    .frame(width: 300)
                }
                .padding(14)
            } else {
                VStack(spacing: 6) {
                    TopBar().padding(.horizontal, 12)
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in TicketView(slot: i, wide: false) }
                    }
                    .padding(.horizontal, 10)
                    table
                    CuttingBoard().padding(.horizontal, 12)
                }
                .padding(.top, 4)
                .padding(.bottom, 6)
            }
            if model.paused { PauseCard() }
        }
        .onChange(of: model.shake) { _, _ in
            guard !reduceMotion else { return }
            Task { @MainActor in
                for x in [0, -9, 8, -6, 5, -3, 2, 0] as [CGFloat] {
                    shakeOffset = x
                    try? await Task.sleep(for: .milliseconds(55))
                }
            }
        }
    }

    private var table: some View {
        ZStack {
            TableStatic(stall: model.game.stall)
            TableDynamic(model: model)
            FlipperZones()
            if let b = model.banner { HangingSign(banner: b).transition(.move(edge: .top).combined(with: .opacity)) }
            if let c = model.coach { CoachBubble(text: c) }
        }
        .aspectRatio(TableGeometry.width / TableGeometry.height, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: shakeOffset)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.banner)
    }
}

/// 画面の左半分・右半分を押すとフライ返しが上がる（離すと下がる。両方同時に押せる）
struct FlipperZones: View {
    @Environment(AppModel.self) private var model
    @State private var leftDown = false
    @State private var rightDown = false

    var body: some View {
        HStack(spacing: 0) {
            zone(.left, $leftDown)
            zone(.right, $rightDown)
        }
    }

    private func zone(_ side: Side, _ down: Binding<Bool>) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !down.wrappedValue {
                            down.wrappedValue = true
                            model.press(side, true)
                        }
                    }
                    .onEnded { _ in
                        down.wrappedValue = false
                        model.press(side, false)
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(side == .left ? tr("左のフライ返し", "Left spatula") : tr("右のフライ返し", "Right spatula"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                model.press(side, true)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    model.press(side, false)
                }
            }
    }
}

/// 上の帯：点・のこり時間・玉・止める
struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let hud = model.hud
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(tr("売上", "Sales")).font(Theme.body(10, .bold)).foregroundStyle(Theme.paper.opacity(0.85)).kerning(0.6)
                Text("\(hud.score)")
                    .font(Theme.number(24))
                    .foregroundStyle(Theme.paper)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: hud.score)
            }
            .frame(minWidth: 72, alignment: .leading)
            Spacer(minLength: 0)
            // のこり時間（壁の時計）
            HStack(spacing: 6) {
                ClockFace(fraction: Double(hud.seconds) / Shift.duration, urgent: hud.seconds <= 30)
                    .frame(width: 26, height: 26)
                Text(String(format: "%d:%02d", hud.seconds / 60, hud.seconds % 60))
                    .font(Theme.number(20))
                    .foregroundStyle(hud.seconds <= 30 ? Theme.yolk : Theme.paper)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trf("のこり %d 秒", "%d seconds left", hud.seconds))
            Spacer(minLength: 0)
            // 玉（スプーン）
            HStack(spacing: 3) {
                ForEach(0..<Shift.ballCount, id: \.self) { i in
                    Circle()
                        .fill(i < hud.balls ? AnyShapeStyle(RadialGradient(colors: [.white, Color(hex: 0xB9C2C8), Color(hex: 0x6F7A82)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 10)) : AnyShapeStyle(Theme.woodDeep.opacity(0.5)))
                        .frame(width: 14, height: 14)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trf("玉 %d", "%d balls", hud.balls))
            Button {
                model.pause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.paper))
                    .overlay(Circle().stroke(Theme.copperDeep, lineWidth: 2))
            }
            .accessibilityLabel(tr("ひと休み", "Pause"))
            .accessibilityIdentifier("main.pause")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .fill(Theme.woodDeep)
                .shadow(color: Theme.ink.opacity(0.25), radius: 0, y: 3)
        )
    }
}

/// 壁の時計（のこり時間が扇形で減る）
struct ClockFace: View {
    let fraction: Double
    let urgent: Bool

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: r * 2, height: r * 2)), with: .color(Theme.paper))
            var wedge = Path()
            wedge.move(to: c)
            wedge.addArc(center: c, radius: r - 3, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * max(0, min(1, fraction))), clockwise: false)
            wedge.closeSubpath()
            ctx.fill(wedge, with: .color(urgent ? Theme.tomato : Theme.copper))
            ctx.stroke(Path(ellipseIn: CGRect(x: 1, y: 1, width: r * 2 - 2, height: r * 2 - 2)), with: .color(Theme.copperDeep), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }
}

/// お客の顔（待ちの段階で表情が変わる）
struct CustomerFace: View {
    let mood: Int
    let seed: Int

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let skins = [Color(hex: 0xF6D2B2), Color(hex: 0xE8B48C), Color(hex: 0xC98D66), Color(hex: 0xF3C9A6)]
            let hairs = [Color(hex: 0x3A2418), Color(hex: 0x7A4A2A), Color(hex: 0xB8B2A8), Color(hex: 0x2B2B33)]
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(skins[seed % 4]))
            var hair = Path()
            hair.addArc(center: c, radius: r, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
            hair.closeSubpath()
            ctx.fill(hair, with: .color(hairs[(seed / 4) % 4]))
            let eyeY = c.y + r * 0.05
            for dx in [-0.35, 0.35] {
                let e = CGPoint(x: c.x + dx * r, y: eyeY)
                if mood == 2 {
                    var p = Path()
                    p.move(to: CGPoint(x: e.x - r * 0.14, y: e.y - (dx < 0 ? r * 0.1 : -r * 0.1) * 0.6))
                    p.addLine(to: CGPoint(x: e.x + r * 0.14, y: e.y + (dx < 0 ? r * 0.1 : -r * 0.1) * 0.6))
                    ctx.stroke(p, with: .color(Theme.ink), lineWidth: max(1, r * 0.1))
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: e.x - r * 0.08, y: e.y - r * 0.1, width: r * 0.16, height: r * 0.2)), with: .color(Theme.ink))
                }
            }
            var mouth = Path()
            let my = c.y + r * 0.45
            switch mood {
            case 0:
                mouth.addArc(center: CGPoint(x: c.x, y: my - r * 0.12), radius: r * 0.22, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            case 1:
                mouth.move(to: CGPoint(x: c.x - r * 0.18, y: my))
                mouth.addLine(to: CGPoint(x: c.x + r * 0.18, y: my))
            default:
                mouth.addArc(center: CGPoint(x: c.x, y: my + r * 0.12), radius: r * 0.2, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            }
            ctx.stroke(mouth, with: .color(Theme.ink), style: StrokeStyle(lineWidth: max(1, r * 0.1), lineCap: .round))
            if mood > 0 {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.75, y: c.y + r * 0.2, width: r * 0.3, height: r * 0.18)), with: .color(Theme.tomato.opacity(0.35)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x + r * 0.45, y: c.y + r * 0.2, width: r * 0.3, height: r * 0.18)), with: .color(Theme.tomato.opacity(0.35)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// 伝票 1 枚
struct TicketView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let slot: Int
    let wide: Bool
    @State private var stamped = false

    var body: some View {
        let hud = model.hud
        let order = hud.orders[slot]
        ZStack {
            TicketShape()
                .fill(Theme.paper)
                .shadow(color: Theme.ink.opacity(0.22), radius: 0, x: 0, y: 2)
            if let order {
                content(order, hud.board)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .scale(scale: 0.8).combined(with: .opacity)))
            } else {
                VStack(spacing: 2) {
                    Text(tr("次のお客", "Next guest"))
                        .font(Theme.body(11, .semibold))
                        .foregroundStyle(Theme.inkSoft)
                    Text("…").font(Theme.hand(16)).foregroundStyle(Theme.inkSoft)
                }
            }
            if stamped {
                Text(tr("あがり", "UP!"))
                    .font(Theme.sign(wide ? 22 : 18))
                    .foregroundStyle(Theme.tomato)
                    .padding(.horizontal, 8)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.tomato, lineWidth: 2.5))
                    .rotationEffect(.degrees(-12))
                    .transition(.scale(scale: 1.8).combined(with: .opacity))
            }
        }
        .frame(height: wide ? 118 : 104)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: order?.id)
        .onChange(of: model.stampSlot) { _, s in
            guard s == slot else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { stamped = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeOut(duration: 0.2)) { stamped = false }
                if model.stampSlot == slot { model.stampSlot = nil }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func content(_ order: Order, _ board: [Ingredient]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                CustomerFace(mood: order.mood, seed: order.id).frame(width: wide ? 24 : 18, height: wide ? 24 : 18)
                Text(order.dish.name)
                    .font(Theme.title(wide ? 14 : 11.5))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            Rectangle().fill(Theme.tomato.opacity(0.7)).frame(height: 1.5)
            let have = board.reduce(into: [Ingredient: Int]()) { $0[$1, default: 0] += 1 }
            FlowRow(spacing: 3) {
                ForEach(Array(order.dish.lines.enumerated()), id: \.offset) { _, line in
                    let (kind, n) = line
                    let ok = (have[kind] ?? 0) >= n
                    HStack(spacing: 1) {
                        IngredientIcon(kind: kind, size: wide ? 20 : 16)
                        Text("\(n)")
                            .font(Theme.hand(wide ? 14 : 12))
                            .foregroundStyle(ok ? Theme.basil : Theme.ink)
                        if ok {
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(Theme.basil)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            // 待てる時間の帯
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.paperLine)
                    Capsule().fill(Theme.mood(order.mood)).frame(width: geo.size.width * order.ratio)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 7)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

/// 折り返して並べる（伝票の材料）
struct FlowRow: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 200
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}

/// まな板（集めた材料。いっぱいなら古いものから落ちる）
struct CuttingBoard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hud = model.hud
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<Shift.boardCapacity, id: \.self) { i in
                    ZStack {
                        Circle().fill(Theme.woodGrain.opacity(0.25)).frame(width: 30, height: 30)
                        if i < hud.board.count {
                            IngredientIcon(kind: hud.board[i], size: 30)
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                        }
                    }
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: hud.board)
            Spacer(minLength: 0)
            Text(hud.canServe ? tr("鍋をねらえ！", "Aim for the pot!") : tr("まな板", "Board"))
                .font(Theme.body(hud.canServe ? 13 : 11, .heavy))
                .foregroundStyle(hud.canServe ? Theme.tomato : Theme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Color(hex: 0xA56F42))
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.woodLight).padding(.bottom, 4)
                Circle().fill(Color(hex: 0xA56F42)).frame(width: 8, height: 8).padding(.trailing, 5).padding(.bottom, 4)
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("まな板", "Board") + "：" + (hud.board.isEmpty ? tr("空", "empty") : hud.board.map(\.name).joined(separator: "、")))
    }
}

/// 上から下りる札
struct HangingSign: View {
    let banner: Banner

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 120) {
                Rectangle().fill(Theme.woodDeep).frame(width: 2, height: 26)
                Rectangle().fill(Theme.woodDeep).frame(width: 2, height: 26)
            }
            VStack(spacing: 2) {
                Text(banner.text)
                    .font(Theme.sign(30))
                    .kerning(2)
                    .foregroundStyle(Theme.paper)
                Text(banner.sub)
                    .font(Theme.body(12, .semibold))
                    .foregroundStyle(Theme.paper.opacity(0.9))
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).fill(banner.tint))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.paper.opacity(0.6), lineWidth: 2).padding(4))
            .shadow(color: Theme.ink.opacity(0.3), radius: 0, y: 4)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}

struct CoachBubble: View {
    let text: String

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill").foregroundStyle(Theme.copper)
                Text(text)
                    .font(Theme.body(13, .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "hand.tap.fill").foregroundStyle(Theme.copper)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.paper.opacity(0.95)))
            .padding(.horizontal, 14)
            .padding(.bottom, 110)
        }
        .allowsHitTesting(false)
    }
}

/// ひと休みの札
struct PauseCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(tr("ひと休み中", "Break time"))
                    .font(Theme.sign(28))
                    .foregroundStyle(Theme.ink)
                Text(tr("お客さんも待っていてくれます", "Your guests will wait for you"))
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSoft)
                VStack(spacing: 10) {
                    Button(tr("つづける", "Resume")) { model.resume() }
                        .buttonStyle(CopperButtonStyle())
                        .accessibilityIdentifier("main.resume")
                    Button(tr("店を出る（記録しない）", "Leave (not saved)")) { model.quit() }
                        .buttonStyle(CopperButtonStyle(prominent: false))
                        .accessibilityIdentifier("main.quit")
                }
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(TicketShape().fill(Theme.paper))
            .padding(.horizontal, 28)
        }
    }
}
