import Foundation
import Observation
import SwiftUI

/// 遊び方（今日の献立・台を選んで・Pro の台のおためし）
enum RunKind: Equatable {
    case daily(String)
    case stall(String)
    case trial(String)

    var day: String? { if case .daily(let d) = self { d } else { nil } }
}

enum Sheet: String, Identifiable {
    case result, book, settings, paywall, days
    var id: String { rawValue }
}

enum Screen { case home, play }

/// 上から下りる札（開店・ラストオーダー・閉店）
struct Banner: Equatable {
    let id: Int
    let text: String
    let sub: String
    let tint: Color
}

/// 台の上に浮いて消える文字
struct Pop: Identifiable {
    let id: Int
    let text: String
    let at: Vec
    let color: Color
    let big: Bool
    let born: Double
}

/// 画面の上の数（毎こまではなく、変わったときと 1 秒に 10 回だけ書き換える）
struct Hud: Equatable {
    var score = 0
    var seconds = 180
    var balls = Shift.ballCount
    var orders: [Order?] = [nil, nil, nil]
    var board: [Ingredient] = []
    var combo = 0
    var canServe = false
    var served = 0
}

@MainActor
@Observable
final class AppModel {
    // 記録と設定
    var save: SaveData
    var onboarded: Bool { didSet { if persists { UserDefaults.standard.set(onboarded, forKey: "diner.onboarded") } } }
    var onboardingPage = 0
    var soundOn: Bool { didSet { persist("diner.sound", soundOn) } }
    var hapticsOn: Bool { didSet { persist("diner.haptics", hapticsOn) } }
    var hintsOn: Bool { didSet { persist("diner.hints", hintsOn) } }
    var slowMode: Bool { didSet { persist("diner.slow", slowMode) } }

    // 画面
    var screen: Screen = .home
    var activeSheet: Sheet?
    var paused = false
    var banner: Banner?
    var hud = Hud()
    var result: ShiftResult?
    var run: RunKind = .daily("")
    /// 台が揺れる（玉を落とした）
    var shake = 0
    /// 出したときの伝票の動き（伝票の位置）
    var stampSlot: Int?
    /// 案内の吹き出し（はじめての 1 回）
    var coach: String?
    /// 毎こま 1 つ増える（動く部分の Canvas だけがこれを見る）
    private(set) var frame = 0

    // 手応え（振動の合図）
    var pressTick = 0
    var hitTick = 0
    var serveTick = 0
    var comboTick = 0
    var failTick = 0
    var warnTick = 0

    // 毎こま変わるもの（画面の書き換えを起こさない）
    @ObservationIgnored var game: Game
    @ObservationIgnored private(set) var clock = 0.0
    @ObservationIgnored private(set) var pops: [Pop] = []
    @ObservationIgnored private(set) var steam = 0.0
    @ObservationIgnored var autopilot: AutoPlayer?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var lastTime: Double?
    @ObservationIgnored private var hudTimer = 0.0
    @ObservationIgnored private var popID = 0
    @ObservationIgnored private var bannerID = 0
    @ObservationIgnored private var drawSkip = 0

    let persists: Bool
    /// 撮影：動かさない
    var still = false
    var now: Date
    let calendar = Calendar.current
    let purchases: PurchaseStore
    /// 撮影で Pro を見せる
    var forcePro = false
    var reduceMotion = false

    static let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.020"

    init(persists: Bool = true, now: Date = Date()) {
        self.persists = persists
        self.now = now
        let d = UserDefaults.standard
        if persists {
            save = SaveStore.load()
            onboarded = d.bool(forKey: "diner.onboarded")
            soundOn = d.object(forKey: "diner.sound") as? Bool ?? true
            hapticsOn = d.object(forKey: "diner.haptics") as? Bool ?? true
            hintsOn = d.object(forKey: "diner.hints") as? Bool ?? true
            slowMode = d.bool(forKey: "diner.slow")
        } else {
            save = SaveData()
            onboarded = false
            soundOn = true
            hapticsOn = true
            hintsOn = true
            slowMode = false
        }
        game = Game(stall: Kitchen.stalls[0], seed: 1)
        let pro = ProductID.pro(bundleID: AppModel.bundleID)
        purchases = PurchaseStore(productIDs: [pro], proProductIDs: [pro])
        save.refreshStreak(today: today, yesterday: yesterday)
    }

    private func persist(_ key: String, _ v: Bool) { if persists { UserDefaults.standard.set(v, forKey: key) } }

    var today: String { Days.key(now, calendar: calendar) }
    var yesterday: String { Days.offset(now, days: -1, calendar: calendar) }
    var todayMenu: DailyMenu { DailyMenu(day: today) }
    var isPro: Bool { forcePro || purchases.entitlements.isPro }
    var trialAvailable: Bool { !isPro && save.trialDay != today }

    func canPlay(_ stall: Stall) -> Bool { !stall.isPro || isPro }

    // MARK: - 始める・止める

    func startDaily(_ day: String? = nil) {
        let menu = DailyMenu(day: day ?? today)
        begin(Game(stall: menu.stall, seed: menu.seed, slow: slowMode && isPro), run: .daily(menu.day))
    }

    func startStall(_ stall: Stall) {
        if !canPlay(stall) {
            guard trialAvailable else { activeSheet = .paywall; return }
            save.trialDay = today
            writeSave()
            begin(Game(stall: stall, seed: UInt64(Date().timeIntervalSince1970 * 1000), slow: false), run: .trial(stall.id))
            return
        }
        begin(Game(stall: stall, seed: UInt64(Date().timeIntervalSince1970 * 1000), slow: slowMode && isPro), run: .stall(stall.id))
    }

    func begin(_ g: Game, run kind: RunKind) {
        pressTick += 1
        game = g
        run = kind
        pops = []
        steam = 0
        clock = 0
        result = nil
        game.start()
        refreshHud()
        screen = .play
        paused = false
        coach = save.tutorialDone ? nil : tr("画面の左右をタップして、フライ返しで玉をはじこう", "Tap the left or right side to flip the spatulas")
        showBanner(tr("開店", "Open"), game.stall.name, tint: Theme.basil)
        SoundBox.shared.play(.open, on: soundOn)
        startLoop()
    }

    func pause() {
        guard screen == .play, !game.isOver else { return }
        pressTick += 1
        paused = true
        releaseFlippers()
    }

    func resume() {
        pressTick += 1
        paused = false
        lastTime = nil
    }

    /// 遊ぶのをやめてホームへ（記録しない）
    func quit() {
        pressTick += 1
        loop?.cancel()
        loop = nil
        paused = false
        screen = .home
        banner = nil
    }

    func press(_ side: Side, _ down: Bool) {
        guard screen == .play, !paused, !still else { return }
        game.press(side, down)
        if down {
            SoundBox.shared.play(.flip, on: soundOn)
            if coach != nil {
                coach = nil
                save.tutorialDone = true
            }
        }
    }

    private func releaseFlippers() {
        game.press(.left, false)
        game.press(.right, false)
    }

    // MARK: - 毎こま

    func startLoop() {
        loop?.cancel()
        lastTime = nil
        guard !still else { return }
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self else { return }
                self.tick()
            }
        }
    }

    func tick() {
        let t = ProcessInfo.processInfo.systemUptime
        defer { lastTime = t }
        guard screen == .play, !paused, activeSheet == nil, let last = lastTime else { return }
        let dt = min(1.0 / 20, max(0, t - last))
        advance(dt)
    }

    /// dt 秒進める（撮影の準備でも使う）
    func advance(_ dt: Double, visual: Bool = true) {
        if var ap = autopilot {
            ap.drive(&game, dt: dt)
            autopilot = ap
        }
        game.step(dt)
        clock += dt
        steam = max(0, steam - dt)
        handleEvents(visual: visual)
        hudTimer += dt
        if hudTimer >= 0.1 {
            hudTimer = 0
            refreshHud()
        }
        if visual {
            pops.removeAll { clock - $0.born > 1.2 }
            // UI テストでは描き直しを 1 秒 20 回に減らす（XCUITest が落ち着くのを待てるように）
            drawSkip += 1
            if !Launch.isFreshUITest || drawSkip % 3 == 0 { frame &+= 1 }
        }
    }

    func refreshHud() {
        let s = game.shift
        var h = Hud()
        h.score = s.score
        h.seconds = Int(s.timeLeft.rounded(.up))
        h.balls = s.balls
        h.orders = s.orders
        h.board = s.board
        h.combo = s.combo
        h.canServe = s.canServe
        h.served = s.served.count
        if h != hud { hud = h }
    }

    private func pop(_ text: String, at: Vec, color: Color = Theme.ink, big: Bool = false) {
        popID += 1
        pops.append(Pop(id: popID, text: text, at: at, color: color, big: big, born: clock))
    }

    private func handleEvents(visual: Bool) {
        var changed = false
        for e in game.drainTableEvents() {
            switch e {
            case .bumper(let i):
                let kind = game.stall.ingredients[i]
                if visual { pop("+" + kind.name, at: game.physics.bumpers[i] + Vec(0, -30), color: Theme.woodDeep) }
                SoundBox.shared.play(.pop(kind.pitch), on: soundOn && visual)
                hitTick += 1
            case .sling:
                SoundBox.shared.play(.sling, on: soundOn && visual)
            case .pot:
                steam = 1.2
                SoundBox.shared.play(.plop, on: soundOn && visual)
            case .pepper, .flipperHit, .drain:
                break
            }
        }
        for e in game.shift.drainEvents() {
            changed = true
            switch e {
            case .gathered:
                break
            case .dropped(let k):
                if visual { pop(trf("%@ がこぼれた", "%@ fell off", k.name), at: Vec(180, 470), color: Theme.inkSoft) }
            case .served(let id, let points, let combo, let makanai):
                serveTick += 1
                if combo > 1 { comboTick += 1 }
                SoundBox.shared.play(combo > 1 ? .combo : .bell, on: soundOn && visual)
                if visual {
                    let name = Kitchen.dish(id)?.name ?? ""
                    pop(combo > 1 ? trf("+%d ×%d", "+%d ×%d", points, combo) : trf("+%d", "+%d", points), at: TableGeometry.pot + Vec(0, -34), color: Theme.tomato, big: true)
                    pop(trf("%@ あがり！", "%@ is up!", name), at: TableGeometry.pot + Vec(0, -60), color: Theme.ink)
                    if makanai > 0 { pop(trf("まかない +%d", "Staff meal +%d", makanai * 3), at: TableGeometry.pot + Vec(0, 40), color: Theme.inkSoft) }
                }
                if let slot = hud.orders.firstIndex(where: { $0?.dish.id == id }) { stampSlot = slot }
            case .notReady:
                if visual { pop(tr("まだ材料が足りない", "Not enough yet"), at: TableGeometry.pot + Vec(0, -36), color: Theme.inkSoft) }
                SoundBox.shared.play(.miss, on: soundOn && visual)
            case .left:
                warnTick += 1
                SoundBox.shared.play(.sigh, on: soundOn && visual)
            case .newOrder:
                break
            case .ballLost:
                failTick += 1
                shake += 1
                SoundBox.shared.play(.thud, on: soundOn && visual)
            case .ballSaved:
                if visual { pop(tr("おかわり！", "Ball saved!"), at: Vec(180, 500), color: Theme.basil, big: true) }
            case .lastCall:
                warnTick += 1
                showBanner(tr("ラストオーダー", "Last call"), tr("のこり 30 秒", "30 seconds left"), tint: Theme.tomato)
                SoundBox.shared.play(.lastCall, on: soundOn && visual)
            case .closed:
                if visual { finish() }
            }
        }
        if changed { refreshHud() }
    }

    func showBanner(_ text: String, _ sub: String, tint: Color) {
        bannerID += 1
        let id = bannerID
        banner = Banner(id: id, text: text, sub: sub, tint: tint)
        guard !still else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            if self?.banner?.id == id { self?.banner = nil }
        }
    }

    // MARK: - 終わり

    func finish() {
        loop?.cancel()
        loop = nil
        releaseFlippers()
        refreshHud()
        var r = ShiftResult(game.shift, day: run.day)
        if persists && !Launch.isDemo {
            r = save.record(r, today: today, yesterday: yesterday)
            writeSave()
        }
        result = r
        SoundBox.shared.play(.close, on: soundOn)
        serveTick += 1
        showBanner(tr("閉店", "Closed"), trf("%d 品", "%d dishes", r.served.count), tint: Theme.woodDeep)
        let delay = still ? 0 : 900
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            self?.activeSheet = .result
        }
    }

    /// 結果を閉じた：ホームへ。価値を感じた直後に 1 日 1 回だけ Pro を見せる
    func resultClosed() {
        screen = .home
        banner = nil
        guard !isPro, !still, save.shifts >= 2, save.paywallDay != today else { return }
        save.paywallDay = today
        writeSave()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            self?.activeSheet = .paywall
        }
    }

    func writeSave() {
        if persists { SaveStore.write(save) }
    }

    func syncPro() {
        if !isPro && slowMode { slowMode = false }
    }

    func resetOnboarding() {
        onboardingPage = 0
        onboarded = false
        activeSheet = nil
    }

    // MARK: - 撮影の準備

    /// 撮影用に、自動の打ち手で seconds 秒だけ進めた所で止める
    func stage(_ g: Game, run kind: RunKind, seconds: Double, style: AutoPlayer.Style = .random) {
        game = g
        run = kind
        game.start()
        var ap = AutoPlayer(style: style, seed: 3)
        var t = 0.0
        while t < seconds && !game.isOver {
            ap.drive(&game, dt: 1.0 / 60)
            game.step(1.0 / 60)
            _ = game.drainTableEvents()
            _ = game.shift.drainEvents()
            t += 1.0 / 60
        }
        clock = t
        screen = .play
        refreshHud()
        frame &+= 1
    }

    func stagePop(_ text: String, at: Vec, color: Color, big: Bool = false) {
        pop(text, at: at, color: color, big: big)
        pops = pops.map { Pop(id: $0.id, text: $0.text, at: $0.at, color: $0.color, big: $0.big, born: clock - 0.25) }
    }

    func stageSteam() { steam = 1 }
}
