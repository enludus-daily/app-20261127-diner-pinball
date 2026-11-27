import Foundation
import Testing
@testable import DinerPinball

// 決まり（物理・注文・まな板・点・記録）のテスト。画面から切り離してある

struct KitchenTests {
    @Test func everyStallHasFiveIngredientsAndDishesMadeFromThem() {
        #expect(Kitchen.stalls.count == 9)
        for stall in Kitchen.stalls {
            #expect(stall.ingredients.count == 5)
            #expect(Set(stall.ingredients).count == 5)
            #expect(stall.layout.positions.count == 5)
            #expect(stall.dishes.count == (stall.isPro ? 5 : 10))
            for dish in stall.dishes {
                #expect(dish.size >= 2 && dish.size <= Shift.boardCapacity)
                #expect(Set(dish.recipe.keys).isSubset(of: Set(stall.ingredients)), "\(dish.id) は \(stall.id) の食材だけで作れる")
            }
        }
    }

    @Test func freeHasThirtyDishesAndProAddsThirty() {
        let free = Kitchen.freeStalls.flatMap(\.dishes)
        #expect(free.count == 30)
        #expect(Kitchen.allDishes.count == 60)
        #expect(Set(Kitchen.allDishes.map(\.id)).count == 60, "料理の id は重ならない")
    }

    @Test func everyNameHasEnglish() {
        for dish in Kitchen.allDishes {
            #expect(!dish.en.isEmpty && !dish.noteEn.isEmpty)
            #expect(dish.en.unicodeScalars.allSatisfy { $0.value < 0x3000 }, "\(dish.id) の英語に日本語が残っていない")
        }
        for stall in Kitchen.stalls {
            #expect(stall.en.unicodeScalars.allSatisfy { $0.value < 0x3000 })
        }
    }

    @Test func bumpersDoNotOverlapThePotOrEachOther() {
        for layout in [BumperLayout.cross, .arch, .vee] {
            let ps = layout.positions
            for (i, a) in ps.enumerated() {
                #expect(a.distance(to: TableGeometry.pot) > TableGeometry.bumperRadius + TableGeometry.potRadius + TableGeometry.ballRadius * 2)
                for b in ps[(i + 1)...] {
                    #expect(a.distance(to: b) > TableGeometry.bumperRadius * 2 + TableGeometry.ballRadius * 2, "玉が食材のあいだを通れる")
                }
            }
        }
    }
}

struct ShiftTests {
    let diner = Kitchen.stall("diner")

    func opened(seed: UInt64 = 1) -> Shift {
        var s = Shift(stall: diner, seed: seed)
        s.open()
        return s
    }

    @Test func opensWithThreeDifferentOrders() {
        let s = opened()
        #expect(s.activeOrders.count == 3)
        #expect(Set(s.activeOrders.map(\.dish.id)).count == 3)
    }

    @Test func potWithoutIngredientsServesNothing() {
        var s = opened()
        let served = s.pot()
        #expect(!served)
        #expect(s.drainEvents().contains(.notReady))
        #expect(s.score == 0)
    }

    @Test func gatheringTheRecipeAndPottingServesTheDish() {
        var s = opened()
        let dish = s.activeOrders[0].dish
        for (k, n) in dish.recipe { for _ in 0..<n { s.hit(k) } }
        #expect(s.canServe)
        let served = s.pot()
        #expect(served)
        #expect(s.served.count == 1)
        #expect(s.score >= dish.points)
        #expect(s.activeOrders.count == 2, "出した伝票が空く")
    }

    @Test func boardDropsTheOldestWhenFull() {
        var s = opened()
        for _ in 0..<Shift.boardCapacity { s.hit(.egg) }
        _ = s.drainEvents()
        s.hit(.tomato)
        #expect(s.board.count == Shift.boardCapacity)
        #expect(s.board.last == .tomato)
        #expect(s.drainEvents().contains(.dropped(.egg)))
    }

    @Test func customersLeaveWhenKeptWaitingAndANewOneComes() {
        var s = opened()
        let first = s.activeOrders[0]
        for _ in 0..<Int((first.patience + 0.5) * 10) { s.tick(0.1) }
        #expect(s.leftCount >= 1)
        for _ in 0..<Int(Shift.nextOrderDelay * 10 + 2) { s.tick(0.1) }
        #expect(s.activeOrders.count == 3)
    }

    @Test func servingQuicklyInARowBuildsACombo() {
        var s = opened()
        for _ in 0..<2 {
            let dish = s.activeOrders[0].dish
            for (k, n) in dish.recipe { for _ in 0..<n { s.hit(k) } }
            s.pot()
            s.tick(3)
        }
        #expect(s.combo == 2)
        #expect(s.bestCombo == 2)
    }

    @Test func leftoversNotNeededBecomeStaffMeal() {
        var s = opened()
        let dish = s.activeOrders[0].dish
        for (k, n) in dish.recipe { for _ in 0..<n { s.hit(k) } }
        // どの伝票にも要らない食材を探して足す
        let need = Set(s.activeOrders.dropFirst().flatMap { $0.dish.recipe.keys })
        if let spare = diner.ingredients.first(where: { !need.contains($0) && dish.recipe[$0] == nil }) {
            s.hit(spare)
            _ = s.drainEvents()
            s.pot()
            let served = s.drainEvents().compactMap { e -> Int? in if case .served(_, _, _, let m) = e { m } else { nil } }
            #expect(served.first == 1)
            #expect(!s.board.contains(spare))
        }
    }

    @Test func ballSaveReturnsAnEarlyDrain() {
        var s = opened()
        s.ballServed()
        s.tick(2)
        s.drained()
        #expect(s.balls == Shift.ballCount)
        s.tick(Shift.ballSave + 1)
        s.drained()
        #expect(s.balls == Shift.ballCount - 1)
    }

    @Test func closesAfterThreeMinutesOrThreeBalls() {
        var s = opened()
        for _ in 0..<1810 { s.tick(0.1) }
        #expect(s.phase == .over)
        var t = opened()
        for _ in 0..<Shift.ballCount {
            t.tick(Shift.ballSave + 1)
            t.drained()
        }
        #expect(t.phase == .over)
    }

    @Test func lastCallAtThirtySeconds() {
        var s = opened()
        var saw = false
        for _ in 0..<1600 {
            s.tick(0.1)
            if s.drainEvents().contains(.lastCall) { saw = true; #expect(abs(s.timeLeft - 30) < 0.2) }
        }
        #expect(saw)
    }
}

struct PhysicsTests {
    @Test func aServedBallFallsAndDrainsWithoutFlipping() {
        var p = PinballPhysics(bumpers: BumperLayout.cross.positions, seed: 3)
        p.serve()
        var events: [TableEvent] = []
        for _ in 0..<(60 * 30) where p.inPlay {
            p.advance(1.0 / 60)
            events += p.drainEvents()
        }
        #expect(events.contains(.drain) || events.contains(.pot))
    }

    @Test func aRaisedFlipperSendsTheBallUp() {
        var p = PinballPhysics(bumpers: [], seed: 1)
        p.ball = Vec(140, 530)
        p.velocity = Vec(0, 60)
        p.inPlay = true
        p.advance(0.05)
        p.press(.left, true)
        var best = 0.0
        for _ in 0..<12 {
            p.advance(1.0 / 60)
            best = min(best, p.velocity.y)
        }
        #expect(best < -500, "フリッパーで上へはじく")
    }

    @Test func flipperStaysWithinItsAngles() {
        var f = Flipper(side: .right)
        f.pressed = true
        for _ in 0..<30 { f.step(1.0 / 120) }
        #expect(abs(f.angle - TableGeometry.upAngle) < 1e-9)
        #expect(f.tip.y < f.pivot.y, "右のフリッパーも上がると先が上を向く")
        f.pressed = false
        for _ in 0..<60 { f.step(1.0 / 120) }
        #expect(abs(f.angle - TableGeometry.restAngle) < 1e-9)
    }

    @Test func middleGapLetsTheBallDrain() {
        let l = Flipper(side: .left).tip, r = Flipper(side: .right).tip
        #expect(r.x - l.x - TableGeometry.flipperRadius * 2 > TableGeometry.ballRadius * 2, "真ん中は玉が落ちる幅")
    }
}

/// うれしい・惜しい・怖い を数字で（監督 #58 の表）。自動の打ち手でアプリと同じ物理を回す
struct TensionTests {
    /// 狙い（食材か鍋）と、打ったあと最初に当たったものを数える
    static func shots(style: AutoPlayer.Style, games: Int, seconds: Double, pot: Bool) -> (good: Int, total: Int) {
        var good = 0, total = 0
        for g in 0..<games {
            var game = Game(stall: Kitchen.freeStalls[g % 3], seed: UInt64(1000 + g))
            game.start()
            var ap = AutoPlayer(style: style, seed: UInt64(77 + g))
            var rng = SeededRNG(seed: UInt64(5 + g))
            var target: AutoPlayer.Target = pot ? .pot : .bumper(Int(rng.unit() * 5))
            var pending: AutoPlayer.Target?
            var lastShots = 0
            var launched = false
            var t = 0.0
            while t < seconds && !game.isOver {
                ap.drive(&game, dt: 1.0 / 60, target: target)
                if ap.shots != lastShots { lastShots = ap.shots; pending = target; launched = false }
                game.step(1.0 / 60)
                for e in game.drainTableEvents() {
                    guard let pt = pending else { continue }
                    switch e {
                    case .flipperHit: launched = true
                    case .bumper(let i) where launched:
                        total += 1
                        if pt == .bumper(i) { good += 1 }
                        pending = nil
                        target = pot ? .pot : .bumper(Int(rng.unit() * 5))
                    case .pot where launched:
                        total += 1
                        if pt == .pot { good += 1 }
                        pending = nil
                    case .drain:
                        if launched { total += 1 }
                        pending = nil
                    default: break
                    }
                }
                t += 1.0 / 60
            }
        }
        return (good, total)
    }

    @Test func aimingHitsTheChosenIngredientMuchMoreThanRandom() {
        let aimed = Self.shots(style: .aim(jitter: 0.02), games: 3, seconds: 50, pot: false)
        let random = Self.shots(style: .random, games: 6, seconds: 180, pot: false)
        let a = Double(aimed.good) / Double(max(1, aimed.total))
        let r = Double(random.good) / Double(max(1, random.total))
        #expect(aimed.total >= 20 && random.total >= 40)
        #expect(a >= 0.4, "狙うと 4 割以上（\(a)）")
        #expect(r <= 0.25, "でたらめは 2 割前後（\(r)）")
        #expect(a >= r * 2.5, "狙うと でたらめの 2.5 倍以上（\(a) / \(r)）")
    }

    @Test func aimingAtThePotGoesInThirtyToFiftyPercent() {
        let aimed = Self.shots(style: .aim(jitter: 0.02), games: 3, seconds: 50, pot: true)
        let rate = Double(aimed.good) / Double(max(1, aimed.total))
        #expect(aimed.total >= 20)
        #expect(rate >= 0.3 && rate <= 0.5, "鍋は狙っても 3〜5 割（\(rate)）")
    }

    @Test func randomPlayLosesTwentyToFortyPercentOfCustomers() {
        var left = 0, served = 0
        for g in 0..<12 {
            var game = Game(stall: Kitchen.freeStalls[g % 3], seed: UInt64(500 + g))
            game.start()
            var ap = AutoPlayer(style: .random, seed: UInt64(900 + g))
            while !game.isOver {
                ap.drive(&game, dt: 1.0 / 60)
                game.step(1.0 / 60)
                _ = game.drainTableEvents()
            }
            left += game.shift.leftCount
            served += game.shift.served.count
        }
        let rate = Double(left) / Double(max(1, left + served))
        #expect(rate >= 0.2 && rate <= 0.4, "でたらめだと 2〜4 割のお客が帰る（\(rate)）")
    }
}

struct RecordsTests {
    @Test func dailyMenuIsTheSameForEveryoneOnADayAndUsesAFreeStall() {
        let a = DailyMenu(day: "2026-11-27"), b = DailyMenu(day: "2026-11-27")
        #expect(a.stall.id == b.stall.id && a.seed == b.seed)
        #expect(!a.stall.isPro)
        let stalls = Set((1...30).map { DailyMenu(day: String(format: "2026-12-%02d", $0)).stall.id })
        #expect(stalls.count == 3, "ひと月で無料の 3 台が全部出る")
    }

    @Test func streakGrowsOnConsecutiveDaysAndResets() {
        var s = SaveData()
        _ = s.record(ShiftResult(stallID: "diner", day: "2026-11-26", score: 100, served: ["omurice"], left: 0, bestCombo: 1), today: "2026-11-26", yesterday: "2026-11-25")
        _ = s.record(ShiftResult(stallID: "diner", day: "2026-11-27", score: 50, served: [], left: 1, bestCombo: 0), today: "2026-11-27", yesterday: "2026-11-26")
        #expect(s.streak == 2)
        _ = s.record(ShiftResult(stallID: "diner", day: "2026-11-27", score: 80, served: [], left: 0, bestCombo: 0), today: "2026-11-27", yesterday: "2026-11-26")
        #expect(s.streak == 2, "同じ日に 2 回遊んでも増えない")
        #expect(s.daily["2026-11-27"] == 80)
        s.refreshStreak(today: "2026-11-30", yesterday: "2026-11-29")
        #expect(s.streak == 0)
        #expect(s.bestStreak == 2)
    }

    @Test func newDishesAndBestAreReported() {
        var s = SaveData()
        let r1 = s.record(ShiftResult(stallID: "cafe", day: nil, score: 120, served: ["eggsando", "eggsando", "crepe"], left: 0, bestCombo: 2), today: "d", yesterday: "y")
        #expect(r1.newDishes == ["eggsando", "crepe"])
        #expect(r1.isBest)
        let r2 = s.record(ShiftResult(stallID: "cafe", day: nil, score: 90, served: ["eggsando"], left: 0, bestCombo: 1), today: "d", yesterday: "y")
        #expect(r2.newDishes.isEmpty)
        #expect(!r2.isBest)
        #expect(s.cooked["eggsando"] == 3)
    }

    @Test func savedDataRoundTrips() throws {
        let defaults = try #require(UserDefaults(suiteName: "diner-test"))
        defaults.removePersistentDomain(forName: "diner-test")
        var s = SaveData()
        s.best["diner"] = 321
        s.cooked["omurice"] = 2
        SaveStore.write(s, defaults)
        #expect(SaveStore.load(defaults) == s)
    }

    @Test func starsFollowDishesServed() {
        func r(_ n: Int) -> ShiftResult { ShiftResult(stallID: "diner", day: nil, score: 0, served: Array(repeating: "omurice", count: n), left: 0, bestCombo: 0) }
        #expect(r(2).stars == 0)
        #expect(r(3).stars == 1)
        #expect(r(7).stars == 2)
        #expect(r(12).stars == 3)
    }
}
