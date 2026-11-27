import SwiftUI

@main
struct DinerPinballApp: App {
    /// アプリ全体で 1 つだけ（App の init は何度も呼ばれることがあるので、ここで作り直さない）
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ZStack {
            if !model.onboarded {
                OnboardingView().transition(.opacity)
            } else if model.screen == .play {
                PlayView().transition(.opacity)
            } else {
                HomeView().transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.screen)
        .environment(model)
        // 昼の食堂の色（木・銅・伝票）を自前で描くので、ライトに固定する
        .preferredColorScheme(.light)
        .sheet(item: $model.activeSheet, onDismiss: {
            if model.activeSheet == nil && model.result != nil && model.screen == .play { model.resultClosed() }
        }) { sheet in
            SheetContent(sheet: sheet)
                .environment(model)
                .environment(\.locale, Lang.locale)
                .presentationCornerRadius(Theme.radiusL)
                .presentationDetents([.large])
                .interactiveDismissDisabled(sheet == .result)
        }
        // 手応えの表（README）：押す・食材に当たる・あがり・連続・失敗・知らせ
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.hitTick) { _, _ in model.hapticsOn ? .impact(weight: .light, intensity: 0.6) : nil }
        .sensoryFeedback(trigger: model.serveTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.comboTick) { _, _ in model.hapticsOn ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: model.failTick) { _, _ in model.hapticsOn ? .error : nil }
        .sensoryFeedback(trigger: model.warnTick) { _, _ in model.hapticsOn ? .warning : nil }
        .modifier(WideOverride(on: Launch.scene == "wide" || Launch.scene == "widehome"))
        .task { await Launch.run(model) }
        .task { await model.purchases.load(); model.syncPro() }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
        .onChange(of: scenePhase) { _, phase in
            guard !model.still, !Launch.isDemo else { return }
            if phase == .active {
                model.now = Date()
                model.save.refreshStreak(today: model.today, yesterday: model.yesterday)
            } else if model.screen == .play {
                // 離れたら止める（時間が勝手に進まないように）
                model.pause()
            }
        }
        .environment(\.locale, Lang.locale)
    }
}

/// 撮影の場面 wide だけ、広い画面の並べ方（size class regular）を強制する（Duo の内側は CI で描かれないため）
struct WideOverride: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.environment(\.horizontalSizeClass, .regular) } else { content }
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static let shared: AppModel = makeModel()

    /// 撮影の日（決まった日にして、今日の献立が毎回同じになるように）
    static func stageDate() -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 12, minute: 30)) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            let model = AppModel(persists: false, now: stageDate())
            model.soundOn = false
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let model = AppModel(persists: false, now: stageDate())
        model.still = scene != nil
        let name = scene ?? ""
        model.onboarded = !name.hasPrefix("onboarding")
        model.onboardingPage = name == "onboarding2" ? 1 : (name == "onboarding3" ? 2 : 0)
        if name != "empty" && !name.hasPrefix("onboarding") {
            model.save = sampleSave(model)
        }
        if isDemo { model.save.tutorialDone = true }
        return model
    }

    /// 見本：遊んで 5 日目くらい
    static func sampleSave(_ model: AppModel) -> SaveData {
        var s = SaveData()
        s.best = ["diner": 1_240, "cafe": 860, "wok": 410]
        for id in ["omurice", "hamburg", "eggrice", "tomatosoup", "steak", "locomoco", "eggsando", "cheesetoast", "frenchtoast", "hamegg", "friedrice", "eggsoup"] {
            s.cooked[id] = Int(Days.seed(id) % 6) + 1
        }
        s.shifts = 9
        s.totalServed = 58
        s.streak = 4
        s.bestStreak = 6
        s.lastDaily = model.yesterday
        s.tutorialDone = true
        for (i, v) in [980, 1_120, 0, 760, 1_310].enumerated() where v > 0 {
            s.daily[Days.offset(model.now, days: -(5 - i), calendar: model.calendar)] = v
        }
        return s
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        if scene.hasPrefix("onboarding") { return }
        let menu = model.todayMenu
        func dailyGame() -> Game { Game(stall: menu.stall, seed: menu.seed) }
        switch scene {
        case "play", "wide":
            model.stage(dailyGame(), run: .daily(menu.day), seconds: 38)
            fillBoard(model, partly: true)
            model.stagePop("+" + model.game.stall.ingredients[1].name, at: model.game.physics.bumpers[1] + Vec(0, -30), color: Theme.woodDeep)
        case "serve":
            model.stage(dailyGame(), run: .daily(menu.day), seconds: 64)
            fillBoard(model, partly: false)
            model.stageSteam()
            model.stagePop(trf("+%d ×%d", "+%d ×%d", 84, 2), at: TableGeometry.pot + Vec(0, -34), color: Theme.tomato, big: true)
            model.stagePop(trf("%@ あがり！", "%@ is up!", model.game.shift.activeOrders.first?.dish.name ?? ""), at: TableGeometry.pot + Vec(0, -60), color: Theme.ink)
        case "lastcall":
            model.stage(dailyGame(), run: .daily(menu.day), seconds: 151)
            model.showBanner(tr("ラストオーダー", "Last call"), tr("のこり 30 秒", "30 seconds left"), tint: Theme.tomato)
        case "pause":
            model.stage(dailyGame(), run: .daily(menu.day), seconds: 20)
            model.paused = true
        case "pro":
            model.forcePro = true
            model.stage(Game(stall: Kitchen.stall("ramen"), seed: 9), run: .stall("ramen"), seconds: 45)
            fillBoard(model, partly: true)
        case "result":
            model.result = ShiftResult(stallID: menu.stall.id, day: menu.day, score: 1_386, served: ["omurice", "hamburg", "omurice", "locomoco", "tomatosoup", "steak", "eggrice", "hayashi", "omurice"], left: 2, bestCombo: 3)
            model.result?.newDishes = ["hayashi"]
            model.result?.isBest = true
            model.screen = .play
            model.stage(dailyGame(), run: .daily(menu.day), seconds: 60)
            model.activeSheet = .result
        case "book": model.activeSheet = .book
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        case "days": model.activeSheet = .days
        default: break
        }
    }

    /// 撮影用：いちばん待たせている伝票の材料を、まな板にのせる（partly なら 1 つ足りない）
    static func fillBoard(_ model: AppModel, partly: Bool) {
        guard let order = model.game.shift.activeOrders.min(by: { $0.remaining < $1.remaining }) else { return }
        var items = order.dish.lines.flatMap { k, n in Array(repeating: k, count: n) }
        if partly && items.count > 1 { items.removeLast() }
        let room = Shift.boardCapacity - model.game.shift.board.count
        if items.count > room {
            for k in items { model.game.shift.hit(k) }
        } else {
            for k in items { model.game.shift.hit(k) }
        }
        _ = model.game.shift.drainEvents()
        model.refreshHud()
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 今日の献立で開店 → 狙って食材に当てる → そろったら鍋へ → あがり → 閉店のレシート
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .milliseconds(Int(s * 1000))) }
        model.soundOn = true
        model.onboarded = true
        await wait(1.5)
        model.autopilot = AutoPlayer(style: .aim(jitter: 0.01), seed: 4)
        model.startDaily()
        await wait(15)
        model.autopilot = nil
        model.game.shift.close()
        model.advance(1.0 / 60)
    }
}
