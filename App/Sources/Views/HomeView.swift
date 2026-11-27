import SwiftUI

/// ホーム：店の看板・今日の献立の黒板・台の一覧。主なボタンは画面の下に固定
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            TileWall().ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    ShopSign()
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 16) {
                            TodayBoard()
                            StallGrid(columns: 3)
                        }
                    } else {
                        TodayBoard()
                        StallGrid(columns: 3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: sizeClass == .regular ? 980 : 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { BottomBar() }
    }
}

/// 店の奥の壁（クリームのタイル）
struct TileWall: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.wall))
            let s: CGFloat = 34
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Theme.tile))
                y += s
            }
            var x: CGFloat = 0
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(Theme.tile))
                x += s
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 看板（木の板に焼きつけた店の名前）
struct ShopSign: View {
    var body: some View {
        VStack(spacing: 2) {
            Text(tr("まんぷくピンボール", "Diner Pinball"))
                .font(Theme.sign(30))
                .kerning(1)
                .foregroundStyle(Theme.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(tr("食材をはじいて、注文をそろえて、鍋へ。", "Flip, gather, and drop it in the pot."))
                .font(Theme.body(13, .semibold))
                .foregroundStyle(Theme.woodLight)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.woodDeep)
                WoodBackground(top: Theme.woodDeep, grain: Color(hex: 0x6E4224), plank: 30)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
                    .opacity(0.8)
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.copperLight.opacity(0.7), lineWidth: 2).padding(5)
            }
            .shadow(color: Theme.ink.opacity(0.25), radius: 0, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 今日の献立（黒板）
struct TodayBoard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let menu = model.todayMenu
        let stall = menu.stall
        let played = model.save.daily[model.today]
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("今日の献立", "Today's menu"))
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.chalk)
                Spacer()
                Text(dateLabel)
                    .font(Theme.hand(16))
                    .foregroundStyle(Theme.yolk)
            }
            Text(stall.name + " ・ " + stall.tagline)
                .font(Theme.body(14, .semibold))
                .foregroundStyle(Theme.chalk.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                DishPlate(dish: menu.special, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("本日のおすすめ（点が 2 倍）", "Today's special (double points)"))
                        .font(Theme.body(10, .bold)).kerning(0.6).foregroundStyle(Theme.yolk)
                    Text(menu.special.name).font(Theme.title(16)).foregroundStyle(Theme.chalk)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                ForEach(stall.dishes.filter { $0.id != menu.special.id }.prefix(4)) { dish in
                    VStack(spacing: 3) {
                        DishPlate(dish: dish, size: 52)
                        Text(dish.name)
                            .font(Theme.body(10, .semibold))
                            .foregroundStyle(Theme.chalk.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(height: 26, alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Rectangle().fill(Theme.chalk.opacity(0.25)).frame(height: 1)
            HStack(spacing: 14) {
                stat(tr("今日の売上", "Today"), played.map { "\($0)" } ?? "—")
                stat(tr("つづけて", "Streak"), trf("%d 日", "%d days", model.save.streak))
                stat(tr("図鑑", "Recipes"), "\(model.save.discovered.count)/\(Kitchen.allDishes.count)")
            }
            Text(played == nil
                 ? (model.save.shifts == 0 ? tr("まだ開店していません。下の「開店」で今日の 3 分を始めよう", "You haven't opened yet. Tap Open below to start today's 3 minutes.") : tr("今日はまだ。だれでも同じ献立です", "Not played yet today. Same menu for everyone."))
                 : tr("今日の分はおわり。もう一度で記録を更新できます", "Done for today. Play again to beat your score."))
                .font(Theme.body(12))
                .foregroundStyle(Theme.chalk.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .fill(Theme.chalkboard)
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.woodDeep, lineWidth: 6))
                .shadow(color: Theme.ink.opacity(0.2), radius: 0, y: 4)
        )
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = Lang.locale
        f.setLocalizedDateFormatFromTemplate("MMMd E")
        return f.string(from: model.now)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(Theme.body(10, .bold)).kerning(0.6).foregroundStyle(Theme.chalk.opacity(0.7))
            Text(value).font(Theme.number(18)).foregroundStyle(Theme.chalk)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 台の一覧（無料 3・Pro 6）
struct StallGrid: View {
    @Environment(AppModel.self) private var model
    let columns: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr("お店をえらぶ", "Pick a kitchen"))
                    .font(Theme.title(18))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if !model.isPro && model.trialAvailable {
                    Text(tr("Pro の台を今日 1 回ためせます", "Try one Pro kitchen today"))
                        .font(Theme.body(11, .semibold))
                        .foregroundStyle(Theme.copperDeep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                ForEach(Kitchen.stalls) { stall in
                    StallCard(stall: stall)
                }
            }
        }
    }
}

struct StallCard: View {
    @Environment(AppModel.self) private var model
    let stall: Stall

    var body: some View {
        let locked = !model.canPlay(stall)
        let best = model.save.best[stall.id]
        Button {
            model.startStall(stall)
        } label: {
            VStack(spacing: 6) {
                // 台の小さな絵：木の色と食材の並び
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                        .fill(Theme.playfield(stall.wood).top)
                    Canvas { ctx, size in
                        let sx = size.width / TableGeometry.width, sy = size.height / 340
                        for (i, p) in stall.layout.positions.enumerated() {
                            IngredientArt.draw(stall.ingredients[i], in: ctx, at: CGPoint(x: p.x * sx, y: (p.y - 110) * sy), radius: 11, shadow: false)
                        }
                        let pot = CGPoint(x: TableGeometry.pot.x * sx, y: (TableGeometry.pot.y - 110) * sy)
                        ctx.fill(Path(ellipseIn: CGRect(x: pot.x - 8, y: pot.y - 8, width: 16, height: 16)), with: .color(Theme.copper))
                    }
                    .padding(4)
                    if locked {
                        RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).fill(Theme.ink.opacity(0.35))
                        Image(systemName: "lock.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.paper)
                    }
                }
                .frame(height: 74)
                Text(stall.name)
                    .font(Theme.title(12))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(locked ? (model.trialAvailable ? tr("おためし 1 回", "1 free try") : "Pro") : (best.map { trf("ベスト %d", "Best %d", $0) } ?? tr("まだ", "New")))
                    .font(Theme.body(10, .bold))
                    .foregroundStyle(locked ? Theme.copperDeep : Theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .fill(Theme.paper)
                    .shadow(color: Theme.woodDeep.opacity(0.35), radius: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stall." + stall.id)
        .accessibilityLabel(stall.name + (locked ? "、Pro" : ""))
    }
}

/// 画面の下に固定するボタン
struct BottomBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            Button {
                model.startDaily()
            } label: {
                Label(tr("今日の献立で開店", "Open with today's menu"), systemImage: "fork.knife")
            }
            .buttonStyle(CopperButtonStyle())
            .accessibilityIdentifier("main.daily")
            HStack(spacing: 8) {
                small(tr("図鑑", "Recipes"), "book.closed.fill", id: "main.book") { model.activeSheet = .book }
                small(tr("過去の献立", "Past menus"), "calendar", id: "main.days") { model.activeSheet = .days }
                small(tr("設定", "Settings"), "gearshape.fill", id: "main.settings") { model.activeSheet = .settings }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(
            Theme.wood
                .overlay(alignment: .top) { Rectangle().fill(Theme.woodDeep).frame(height: 3) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func small(_ title: String, _ icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(Theme.body(13, .bold))
        }
        .buttonStyle(CopperButtonStyle(prominent: false))
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(id)
    }
}
