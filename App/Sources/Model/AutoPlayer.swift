import Foundation

/// 自動の打ち手（テストの「うれしい・惜しい・怖い」の割合と、デモの再生に使う）
struct AutoPlayer: Sendable {
    enum Style: Sendable {
        /// でたらめに打つ：玉が下に来たら、決まっていない高さでどちらかを押す
        case random
        /// 狙って打つ：押す時刻を先読みで選ぶ（人の手のずれ jitter 秒を足す）
        case aim(jitter: Double)
    }

    /// 何を狙うか
    enum Target: Equatable, Sendable {
        case bumper(Int)
        case pot
    }

    let style: Style
    private var rng: SeededRNG
    private var holdLeft = 0.0
    private var holding: Side?
    private var armedY: Double?
    private var plan: (side: Side, at: Double)?
    private var clock = 0.0
    private var cooldown = 0.0
    /// 打ったときの狙い（テストが結果と比べる）
    private(set) var lastShotTarget: Target?
    /// 打った回数
    private(set) var shots = 0

    init(style: Style, seed: UInt64) {
        self.style = style
        rng = SeededRNG(seed: seed)
    }

    /// 決まりから、いま狙うものを選ぶ（出せるなら鍋、そうでなければ足りない食材）
    static func target(for game: Game) -> Target {
        if game.shift.canServe { return .pot }
        let wanted = game.shift.wanted
        if let first = wanted.first, let i = game.stall.ingredients.firstIndex(of: first) { return .bumper(i) }
        return .bumper(0)
    }

    /// 1 こま分、ボタンを押す・離す
    mutating func drive(_ game: inout Game, dt: Double, target: Target? = nil) {
        clock += dt
        cooldown = max(0, cooldown - dt)
        if let side = holding {
            holdLeft -= dt
            if holdLeft <= 0 {
                game.press(side, false)
                holding = nil
                cooldown = 0.12
            }
            return
        }
        let p = game.physics
        guard p.inPlay, cooldown == 0 else { plan = nil; armedY = nil; return }
        let inZone = p.ball.y > 455 && p.ball.y < 580
        guard inZone else { plan = nil; armedY = nil; return }
        let side: Side = p.ball.x < 180 ? .left : .right
        switch style {
        case .random:
            if armedY == nil { armedY = rng.range(475, 560) }
            if let y = armedY, p.ball.y >= y {
                flip(side, &game)
                armedY = nil
                lastShotTarget = target
            }
        case .aim(let jitter):
            if plan == nil {
                let goal = target ?? AutoPlayer.target(for: game)
                if let best = AutoPlayer.bestDelay(game: game, side: side, goal: goal) {
                    plan = (side, clock + max(0, best + rng.range(-jitter, jitter)))
                    lastShotTarget = goal
                } else {
                    // 狙えないときは、落ちないように打つ
                    if p.velocity.y > 0 && p.ball.y > 520 {
                        flip(side, &game)
                        lastShotTarget = nil
                    }
                }
            }
            if let pl = plan, clock >= pl.at {
                flip(pl.side, &game)
                plan = nil
            }
        }
    }

    private mutating func flip(_ side: Side, _ game: inout Game) {
        game.press(side, true)
        holding = side
        holdLeft = 0.22
        shots += 1
    }

    /// 先読み：いまから d 秒後に押したら、最初に何に当たるか
    static func firstHit(game: Game, side: Side, delay: Double) -> Target? {
        var p = game.physics
        _ = p.drainEvents()
        let dt = 1.0 / 120
        var t = 0.0
        var pressed = false
        var launched = false
        while t < 2.2 {
            if !pressed && t >= delay { p.press(side, true); pressed = true }
            if pressed && t >= delay + 0.22 { p.press(side, false) }
            p.advance(dt)
            for e in p.drainEvents() {
                switch e {
                case .bumper(let i): if launched { return .bumper(i) }
                case .pot: return .pot
                case .drain: return nil
                case .flipperHit: launched = true
                default: break
                }
            }
            // 打ち上げずに下へ落ちていった
            if !pressed && p.ball.y > 590 { return nil }
            if launched && p.velocity.y > 0 && p.ball.y > 470 { return nil }
            t += dt
        }
        return nil
    }

    /// 狙いに当たる押す時刻（なければ nil）。当たる時刻の幅のまんなかを選ぶ
    static func bestDelay(game: Game, side: Side, goal: Target) -> Double? {
        var hits: [Double] = []
        var d = 0.0
        while d <= 0.6 {
            if firstHit(game: game, side: side, delay: d) == goal { hits.append(d) }
            d += 0.01
        }
        guard !hits.isEmpty else { return nil }
        // つながった幅のうち、いちばん長いもののまんなか
        var best: [Double] = []
        var run: [Double] = []
        for h in hits {
            if let last = run.last, h - last > 0.015 { run = [] }
            run.append(h)
            if run.count > best.count { best = run }
        }
        return best[best.count / 2]
    }
}
