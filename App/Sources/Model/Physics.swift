import Foundation

/// 台の決まった形（壁・スリング・フリッパーの位置）。食材のバンパーと鍋は Stall で変わる。
/// 大きさは 360 × 600、y は下向き。描く側（Views/TableArt.swift）も同じ数字を使う
enum TableGeometry {
    static let width = 360.0
    static let height = 600.0
    static let ballRadius = 9.0
    static let bumperRadius = 25.0
    static let flipperLength = 66.0
    static let flipperRadius = 6.0
    static let leftPivot = Vec(102, 532)
    static let rightPivot = Vec(258, 532)
    /// フリッパーの角度（下がっている・上がっている）。左は右下向きが +、右は左右を反転
    static let restAngle = 30.0 * .pi / 180
    static let upAngle = -24.0 * .pi / 180
    static let pot = Vec(180, 352)
    static let potRadius = 20.0
    /// 鍋に入ったと決める、玉の中心と鍋の中心の距離
    static let potCapture = 11.0
    static let pepper = Vec(180, 104)
    static let pepperRadius = 9.0
    static let serve = Vec(180, 46)
    /// 落ちた（玉を失う）と決める高さ
    static let drainY = 612.0

    /// 上のアーチ（左の壁の上から右の壁の上まで）
    static let arch: [Vec] = (0...16).map { i in
        let a = Double.pi + Double.pi * Double(i) / 16
        return Vec(180 + 166 * cos(a), 112 + 98 * sin(a))
    }

    static let leftSling = [Vec(54, 398), Vec(54, 452), Vec(92, 480)]
    static let rightSling = [Vec(306, 398), Vec(306, 452), Vec(268, 480)]

    /// 壁の線分（はね返りの強さつき。kick は スリングの面）
    static let walls: [Wall] = {
        var w: [Wall] = []
        for i in 0..<(arch.count - 1) { w.append(Wall(a: arch[i], b: arch[i + 1])) }
        w.append(Wall(a: Vec(14, 112), b: Vec(14, 455)))
        w.append(Wall(a: Vec(346, 112), b: Vec(346, 455)))
        // 下の案内の坂（フリッパーの付け根へ）
        w.append(Wall(a: Vec(14, 455), b: Vec(96, 527)))
        w.append(Wall(a: Vec(346, 455), b: Vec(264, 527)))
        // スリング（三角。斜めの面だけが弾く）
        w.append(Wall(a: leftSling[0], b: leftSling[1]))
        w.append(Wall(a: leftSling[1], b: leftSling[2]))
        w.append(Wall(a: leftSling[0], b: leftSling[2], kick: 330))
        w.append(Wall(a: rightSling[0], b: rightSling[1]))
        w.append(Wall(a: rightSling[1], b: rightSling[2]))
        w.append(Wall(a: rightSling[0], b: rightSling[2], kick: 330))
        return w
    }()
}

struct Wall: Sendable {
    var a: Vec
    var b: Vec
    var kick: Double = 0
}

enum Side: Int, Sendable, Codable { case left, right }

struct Flipper: Sendable {
    let side: Side
    var angle: Double
    var omega = 0.0
    var pressed = false

    init(side: Side) {
        self.side = side
        angle = TableGeometry.restAngle
    }

    var pivot: Vec { side == .left ? TableGeometry.leftPivot : TableGeometry.rightPivot }

    /// 画面の上の向き（右のフリッパーは左右を反転）
    var worldAngle: Double { side == .left ? angle : .pi - angle }

    var tip: Vec { pivot + Vec.angle(worldAngle) * TableGeometry.flipperLength }

    /// 0 = 下がっている、1 = 上がりきった
    var lift: Double { (TableGeometry.restAngle - angle) / (TableGeometry.restAngle - TableGeometry.upAngle) }

    /// 上がる速さ・下がる速さ（ラジアン/秒）
    static let upSpeed = 22.0
    static let downSpeed = 14.0

    mutating func step(_ dt: Double) {
        let target = pressed ? TableGeometry.upAngle : TableGeometry.restAngle
        let before = angle
        if angle > target {
            angle = max(target, angle - Flipper.upSpeed * dt)
        } else if angle < target {
            angle = min(target, angle + Flipper.downSpeed * dt)
        }
        let d = (angle - before) / dt
        // 画面の上の角速度（右は反転）
        omega = side == .left ? d : -d
    }
}

/// 物理で起きたこと（決まりの側と、音・振動・動きの側が受け取る）
enum TableEvent: Equatable, Sendable {
    case bumper(Int)
    case sling(Side)
    case flipperHit(Side)
    case pot
    case drain
    case pepper
}

/// 台の上の玉とフリッパー（決まった刻みで進める。SpriteKit を使わず、テストと同じ物理で動く）
struct PinballPhysics: Sendable {
    static let gravity = 760.0
    static let maxSpeed = 1150.0
    static let substep = 1.0 / 240

    var bumpers: [Vec]
    var ball: Vec
    var velocity: Vec
    var inPlay: Bool
    var flippers = [Flipper(side: .left), Flipper(side: .right)]
    /// ゆっくりモード（Pro）：時間の進みを 0.75 倍にする
    var slow = false
    /// 食材が弾んでいる時間（描く側が使う）
    var bumperGlow: [Double]
    var events: [TableEvent] = []
    private var stuckTime = 0.0
    private var rng: SeededRNG

    init(bumpers: [Vec], seed: UInt64) {
        self.bumpers = bumpers
        bumperGlow = Array(repeating: 0, count: bumpers.count)
        ball = TableGeometry.serve
        velocity = .zero
        inPlay = false
        rng = SeededRNG(seed: seed)
    }

    mutating func press(_ side: Side, _ down: Bool) { flippers[side.rawValue].pressed = down }

    /// おたまから玉を落とす
    mutating func serve() {
        ball = TableGeometry.serve + Vec(rng.range(-6, 6), 0)
        velocity = Vec(rng.range(-70, 70), 40)
        inPlay = true
        stuckTime = 0
    }

    /// 鍋から玉を出す（どちらかのフリッパーへ転がす）
    mutating func eject() {
        ball = TableGeometry.pot + Vec(0, TableGeometry.potRadius + TableGeometry.ballRadius + 1)
        let dir = rng.unit() < 0.5 ? -1.0 : 1.0
        velocity = Vec(dir * rng.range(90, 150), rng.range(120, 180))
        inPlay = true
        stuckTime = 0
    }

    /// dt 秒進める（細かい刻みに分ける）
    mutating func advance(_ dt: Double) {
        let scaled = slow ? dt * 0.75 : dt
        var left = scaled
        while left > 1e-9 {
            let h = min(PinballPhysics.substep, left)
            step(h)
            left -= h
        }
        for i in bumperGlow.indices { bumperGlow[i] = max(0, bumperGlow[i] - dt) }
    }

    mutating func drainEvents() -> [TableEvent] {
        defer { events.removeAll() }
        return events
    }

    private mutating func step(_ h: Double) {
        for i in flippers.indices { flippers[i].step(h) }
        guard inPlay else { return }
        velocity.y += PinballPhysics.gravity * h
        ball += velocity * h
        collideWalls()
        collidePepper()
        collideBumpers()
        for i in flippers.indices { collideFlipper(i) }
        let speed = velocity.length
        if speed > PinballPhysics.maxSpeed { velocity = velocity * (PinballPhysics.maxSpeed / speed) }

        if ball.distance(to: TableGeometry.pot) < TableGeometry.potCapture {
            inPlay = false
            velocity = .zero
            ball = TableGeometry.pot
            events.append(.pot)
            return
        }
        if ball.y > TableGeometry.drainY {
            inPlay = false
            events.append(.drain)
            return
        }
        // 壁ぎわで止まったら、そっと押し出す
        if speed < 8 && !onFlipper {
            stuckTime += h
            if stuckTime > 2 {
                velocity = Vec(rng.range(-120, 120), -160)
                stuckTime = 0
            }
        } else {
            stuckTime = 0
        }
    }

    var onFlipper: Bool {
        flippers.contains { f in
            closestPoint(ball, f.pivot, f.tip).point.distance(to: ball) < TableGeometry.ballRadius + TableGeometry.flipperRadius + 2
        }
    }

    private mutating func collideWalls() {
        let r = TableGeometry.ballRadius
        for w in TableGeometry.walls {
            let (q, _) = closestPoint(ball, w.a, w.b)
            let d = ball - q
            let dist = d.length
            guard dist < r else { continue }
            let n = dist > 1e-6 ? d * (1 / dist) : (w.b - w.a).perp.normalized
            ball = q + n * r
            let vn = velocity.dot(n)
            if vn < 0 {
                velocity -= n * ((1 + 0.45) * vn)
                // 壁をこする向きの速さを少し落とす
                let t = velocity - n * velocity.dot(n)
                velocity -= t * 0.02
            }
            if w.kick > 0 && vn < -40 {
                let out = velocity.dot(n)
                if out < w.kick { velocity += n * (w.kick - out) }
                events.append(.sling(w.a.x < 180 ? .left : .right))
            }
        }
    }

    private mutating func collidePepper() {
        let r = TableGeometry.ballRadius + TableGeometry.pepperRadius
        let d = ball - TableGeometry.pepper
        let dist = d.length
        guard dist < r else { return }
        let n = d.normalized
        ball = TableGeometry.pepper + n * r
        let vn = velocity.dot(n)
        if vn < 0 {
            velocity -= n * ((1 + 0.6) * vn)
            events.append(.pepper)
        }
    }

    private mutating func collideBumpers() {
        let r = TableGeometry.ballRadius + TableGeometry.bumperRadius
        for (i, c) in bumpers.enumerated() {
            let d = ball - c
            let dist = d.length
            guard dist < r else { continue }
            let n = d.normalized
            ball = c + n * r
            let vn = velocity.dot(n)
            if vn < 0 {
                velocity -= n * ((1 + 0.85) * vn)
                // 食材がぷるんと弾く（外向きの速さを最低 340 に）
                let out = velocity.dot(n)
                if out < 340 { velocity += n * (340 - out) }
                bumperGlow[i] = 0.35
                events.append(.bumper(i))
            }
        }
    }

    private mutating func collideFlipper(_ i: Int) {
        let f = flippers[i]
        let r = TableGeometry.ballRadius + TableGeometry.flipperRadius
        let (q, _) = closestPoint(ball, f.pivot, f.tip)
        let d = ball - q
        let dist = d.length
        guard dist < r else { return }
        let n = dist > 1e-6 ? d * (1 / dist) : Vec(0, -1)
        ball = q + n * r
        // フリッパーの、当たった所の速さ
        let vf = (q - f.pivot).perp * f.omega
        let rel = velocity - vf
        let vn = rel.dot(n)
        if vn < 0 {
            let moving = abs(f.omega) > 1
            let e = moving ? 0.55 : 0.25
            velocity = rel - n * ((1 + e) * vn) + vf
            if moving && velocity.y < -250 { events.append(.flipperHit(f.side)) }
        }
    }
}
