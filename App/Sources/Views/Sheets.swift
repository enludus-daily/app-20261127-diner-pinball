import StoreKit
import SwiftUI

struct SheetContent: View {
    @Environment(AppModel.self) private var model
    let sheet: Sheet

    var body: some View {
        ZStack {
            TileWall().ignoresSafeArea()
            switch sheet {
            case .result: ResultSheet()
            case .book: BookSheet()
            case .settings: SettingsSheet()
            case .paywall: PaywallSheet()
            case .days: DaysSheet()
            }
        }
    }
}

/// シートの見出しと、下に固定した閉じるボタン
struct SheetFrame<Content: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    var closeTitle: String? = nil
    var onClose: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(Theme.sign(26))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(closeTitle ?? tr("閉じる", "Close")) {
                if let onClose { onClose() } else { model.activeSheet = nil }
            }
            .buttonStyle(CopperButtonStyle(prominent: closeTitle != nil))
            .accessibilityIdentifier("main.close")
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(Theme.wall.opacity(0.96).ignoresSafeArea(edges: .bottom))
        }
    }
}

// MARK: - 結果（レシート）

struct ResultSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownStars = 0

    var body: some View {
        if let r = model.result {
            let stall = Kitchen.stall(r.stallID)
            SheetFrame(title: tr("本日の売上", "Today's receipt"), closeTitle: tr("ホームへ", "Back to home"), onClose: { model.activeSheet = nil }) {
                VStack(spacing: 12) {
                    HStack {
                        Text(stall.name).font(Theme.title(16)).foregroundStyle(Theme.inkSoft)
                        Spacer()
                        if r.isBest {
                            Text(tr("自己ベスト！", "New best!"))
                                .font(Theme.body(12, .heavy))
                                .foregroundStyle(Theme.paper)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Capsule().fill(Theme.tomato))
                        }
                    }
                    Text("\(r.score)")
                        .font(Theme.number(64))
                        .kerning(-2)
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in
                            StarShape()
                                .fill(i < shownStars ? Theme.yolk : Theme.paperLine)
                                .overlay(StarShape().stroke(Theme.copperDeep.opacity(i < shownStars ? 0.8 : 0.3), lineWidth: 1.5))
                                .frame(width: 34, height: 34)
                                .scaleEffect(i < shownStars ? 1 : 0.85)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(trf("星 %d", "%d stars", r.stars))
                    HStack(spacing: 0) {
                        stat(tr("出した", "Served"), "\(r.served.count)")
                        stat(tr("帰った", "Walked out"), "\(r.left)")
                        stat(tr("連続", "Best combo"), "×\(max(1, r.bestCombo))")
                    }
                    dashed
                    if r.served.isEmpty {
                        Text(tr("まだ 1 品も出せなかった。伝票の材料が光ったら、その食材をねらおう", "No dishes yet. Aim for the glowing ingredients on the tickets."))
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        let counts = r.served.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
                        let ids = r.served.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                        ForEach(ids, id: \.self) { id in
                            if let d = Kitchen.dish(id) {
                                HStack(spacing: 10) {
                                    DishPlate(dish: d, size: 38)
                                    Text(d.name).font(Theme.body(14, .semibold)).foregroundStyle(Theme.ink)
                                    if r.newDishes.contains(id) {
                                        Text(tr("新しい", "NEW")).font(Theme.body(10, .heavy)).foregroundStyle(Theme.tomato)
                                    }
                                    Spacer()
                                    Text("×\(counts[id] ?? 1)").font(Theme.hand(16)).foregroundStyle(Theme.ink)
                                }
                            }
                        }
                    }
                    if !r.newDishes.isEmpty {
                        Text(trf("図鑑に %d 品ふえた（%d/%d）", "%d new recipes (%d/%d)", r.newDishes.count, model.save.discovered.count, Kitchen.allDishes.count))
                            .font(Theme.body(13, .bold))
                            .foregroundStyle(Theme.basil)
                    }
                    dashed
                    ShareLink(item: r.shareText(stallName: stall.name)) {
                        Label(tr("結果をシェア", "Share result"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(CopperButtonStyle(prominent: false))
                    .accessibilityIdentifier("result.share")
                    if !model.isPro {
                        ProTeaser()
                    }
                }
                .padding(16)
                .background(TicketShape().fill(Theme.paper).shadow(color: Theme.ink.opacity(0.15), radius: 0, y: 3))
            }
            .task {
                if reduceMotion || model.still {
                    shownStars = r.stars
                    return
                }
                for i in 0..<r.stars {
                    try? await Task.sleep(for: .milliseconds(320))
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { shownStars = i + 1 }
                    SoundBox.shared.play(.pop(1046.5 + Double(i) * 260), on: model.soundOn)
                    model.hitTick += 1
                }
            }
        }
    }

    private var dashed: some View {
        Rectangle().fill(.clear).frame(height: 1)
            .overlay(Line().stroke(Theme.paperLine, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.number(22)).foregroundStyle(Theme.ink)
            Text(label).font(Theme.body(11, .semibold)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<10 {
            let a = Double(i) * .pi / 5 - .pi / 2
            let rr = i % 2 == 0 ? r : r * 0.45
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// 結果の下：Pro の台の料理をちらっと見せる
struct ProTeaser: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let pro = Kitchen.stalls.filter(\.isPro)
        Button {
            model.activeSheet = .paywall
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("ほかの 6 店の料理も", "Six more kitchens with Pro"))
                    .font(Theme.title(14))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    ForEach(pro) { s in
                        DishPlate(dish: s.dishes.last ?? s.dishes[0], size: 40)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.woodLight.opacity(0.5)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 図鑑

struct BookSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let found = model.save.discovered
        SheetFrame(title: tr("料理図鑑", "Recipe book")) {
            Text(trf("%d 品のうち %d 品を出した", "%2$d of %1$d dishes served", Kitchen.allDishes.count, found.count))
                .font(Theme.body(14, .semibold))
                .foregroundStyle(Theme.inkSoft)
            ForEach(Kitchen.stalls) { stall in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(stall.name).font(Theme.title(16)).foregroundStyle(Theme.ink)
                        if stall.isPro && !model.isPro {
                            Text("Pro").font(Theme.body(10, .heavy)).foregroundStyle(Theme.paper)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Theme.copper))
                        }
                        Spacer()
                        Text("\(stall.dishes.filter { found.contains($0.id) }.count)/\(stall.dishes.count)")
                            .font(Theme.number(13)).foregroundStyle(Theme.inkSoft)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(stall.dishes) { dish in
                            let known = found.contains(dish.id)
                            VStack(spacing: 4) {
                                DishPlate(dish: dish, size: 56, known: known)
                                Text(known ? dish.name : "？？？")
                                    .font(Theme.body(11, .bold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text(known ? dish.note : dish.lines.map { "\($0.0.name)×\($0.1)" }.joined(separator: " "))
                                    .font(Theme.body(9))
                                    .foregroundStyle(Theme.inkSoft)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(height: 24, alignment: .top)
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).fill(Theme.paper))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.woodLight.opacity(0.45)))
            }
        }
    }
}

// MARK: - 設定

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        SheetFrame(title: tr("設定", "Settings")) {
            group {
                Toggle(tr("効果音", "Sound effects"), isOn: $model.soundOn)
                Toggle(tr("振動", "Haptics"), isOn: $model.hapticsOn)
                Toggle(tr("ねらう食材を光らせる", "Highlight what to aim for"), isOn: $model.hintsOn)
            }
            group {
                Toggle(isOn: Binding(get: { model.slowMode && model.isPro }, set: { model.slowMode = $0 })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("ゆっくりモード（Pro）", "Slow mode (Pro)"))
                        Text(tr("玉が 0.75 倍の速さに。ねらう練習に", "The ball moves at 0.75× speed for practice"))
                            .font(Theme.body(11)).foregroundStyle(Theme.inkSoft)
                    }
                }
                .disabled(!model.isPro)
                if !model.isPro {
                    Button(tr("Pro を見る", "See Pro")) { model.activeSheet = .paywall }
                        .buttonStyle(CopperButtonStyle())
                        .accessibilityIdentifier("settings.pro")
                }
                Button(tr("購入を復元", "Restore purchase")) {
                    Task { await model.purchases.restore(); model.syncPro() }
                }
                .buttonStyle(CopperButtonStyle(prominent: false))
            }
            group {
                Button(tr("遊び方をもう一度見る", "Show how to play again")) { model.resetOnboarding() }
                    .buttonStyle(CopperButtonStyle(prominent: false))
                Text(tr("記録は端末の中だけに残ります。ログイン・広告・データの送信はありません。", "Your records stay on this device. No login, no ads, nothing is sent anywhere."))
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func group<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { c() }
            .font(Theme.body(15, .semibold))
            .foregroundStyle(Theme.ink)
            .tint(Theme.copper)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.paper))
    }
}

// MARK: - Pro

struct PaywallSheet: View {
    @Environment(AppModel.self) private var model
    @State private var buying = false
    @State private var message: String?

    var body: some View {
        SheetFrame(title: tr("まんぷく Pro", "Diner Pinball Pro")) {
            Text(tr("1 回の買い切りで、ずっと使えます。広告はありません。", "One purchase, yours forever. No ads."))
                .font(Theme.body(14, .semibold))
                .foregroundStyle(Theme.inkSoft)
            VStack(alignment: .leading, spacing: 12) {
                feature("storefront.fill", tr("お店が 3 → 9 に", "Kitchens: 3 → 9"), tr("ラーメン屋・パン屋・屋台・石窯ピザ・カレー・海の食堂。食材の並びも注文も違う", "Noodle bar, bakery, fair stand, pizza, curry and seaside grill — new layouts and orders"))
                HStack(spacing: 6) {
                    ForEach(Kitchen.stalls.filter(\.isPro)) { s in
                        VStack(spacing: 2) {
                            DishPlate(dish: s.dishes.last ?? s.dishes[0], size: 42)
                            Text(s.name).font(Theme.body(8, .bold)).foregroundStyle(Theme.inkSoft).lineLimit(1).minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                feature("book.fill", tr("図鑑が 30 → 60 品に", "Recipe book: 30 → 60 dishes"), tr("全部のせラーメン、クロワッサン、なんでものせピザ…", "Everything ramen, croissants, supreme pizza…"))
                feature("calendar", tr("過去 30 日の献立", "The last 30 daily menus"), tr("遊びそびれた日の献立で、あとから記録を残せる", "Play the menus you missed and keep the scores"))
                feature("tortoise.fill", tr("ゆっくりモード", "Slow mode"), tr("玉が 0.75 倍の速さに。ねらう練習に", "The ball moves at 0.75× speed for practice"))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.paper))

            if model.isPro {
                Text(tr("Pro を使えます。ありがとうございます！", "Pro is active. Thank you!"))
                    .font(Theme.body(15, .bold)).foregroundStyle(Theme.basil)
            } else {
                switch model.purchases.loadState {
                case .ready:
                    ForEach(model.purchases.products, id: \.id) { product in
                        Button {
                            Task {
                                buying = true
                                let outcome = await model.purchases.purchase(product)
                                buying = false
                                model.syncPro()
                                if outcome == .purchased { model.activeSheet = nil }
                                if outcome == .pending { message = tr("承認を待っています", "Waiting for approval") }
                                if outcome == .failed { message = tr("購入できませんでした。もう一度お試しください", "The purchase didn't go through. Please try again.") }
                            }
                        } label: {
                            Text(trf("%@ で Pro にする", "Get Pro for %@", product.displayPrice))
                        }
                        .buttonStyle(CopperButtonStyle())
                        .disabled(buying)
                        .accessibilityIdentifier("paywall.buy")
                    }
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity)
                case .unavailable:
                    if model.still {
                        // 審査用の画像（docs/iap/paywall.png）にボタンを写す
                        Button(trf("%@ で Pro にする", "Get Pro for %@", Lang.isJapanese ? "¥480" : "$2.99")) {}
                            .buttonStyle(CopperButtonStyle())
                    } else {
                        Text(tr("いまは購入できません。通信を確かめて、あとで開き直してください", "Purchases aren't available right now. Check your connection and try again later."))
                            .font(Theme.body(13)).foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let message { Text(message).font(Theme.body(13, .semibold)).foregroundStyle(Theme.tomato) }
                if model.trialAvailable, let trial = Kitchen.stalls.first(where: \.isPro) {
                    Button(trf("買う前に %@ を 1 回ためす", "Try %@ once first", trial.name)) {
                        model.activeSheet = nil
                        model.startStall(trial)
                    }
                    .buttonStyle(CopperButtonStyle(prominent: false))
                    .accessibilityIdentifier("paywall.trial")
                }
                Button(tr("購入を復元", "Restore purchase")) {
                    Task { await model.purchases.restore(); model.syncPro() }
                }
                .font(Theme.body(13, .semibold))
                .foregroundStyle(Theme.copperDeep)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func feature(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.paper)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.copper))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.title(15)).foregroundStyle(Theme.ink)
                Text(body).font(Theme.body(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 過去の献立

struct DaysSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SheetFrame(title: tr("過去の献立", "Past menus")) {
            Text(model.isPro ? tr("過去 30 日の献立で遊べます", "Play any of the last 30 daily menus") : tr("今日の献立は無料。過去 30 日は Pro で遊べます", "Today's menu is free. The last 30 days come with Pro."))
                .font(Theme.body(13, .semibold))
                .foregroundStyle(Theme.inkSoft)
            ForEach(0..<30, id: \.self) { back in
                let day = Days.offset(model.now, days: -back, calendar: model.calendar)
                let menu = DailyMenu(day: day)
                let score = model.save.daily[day]
                let open = back == 0 || model.isPro
                Button {
                    if open {
                        model.activeSheet = nil
                        model.startDaily(day)
                    } else {
                        model.activeSheet = .paywall
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(String(day.suffix(5)).replacingOccurrences(of: "-", with: "/"))
                            .font(Theme.hand(16))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 56, alignment: .leading)
                        Text(menu.stall.name).font(Theme.body(14, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                        Spacer()
                        if let score {
                            Text("\(score)").font(Theme.number(15)).foregroundStyle(Theme.copperDeep)
                        } else if !open {
                            Image(systemName: "lock.fill").foregroundStyle(Theme.inkSoft)
                        } else {
                            Text(tr("遊ぶ", "Play")).font(Theme.body(12, .bold)).foregroundStyle(Theme.copper)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).fill(back == 0 ? Theme.woodLight : Theme.paper))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
