import Foundation

/// 物理と決まりをつないだ 1 回の営業。画面とテストと自動の打ち手が同じものを動かす
struct Game: Sendable {
    var physics: PinballPhysics
    var shift: Shift
    /// 次の玉が出るまで（秒）
    private(set) var serveIn: Double?
    /// 鍋から玉が出るまで（秒）
    private(set) var ejectIn: Double?
    /// 物理で起きたこと（描く側・音の側が受け取る）
    private(set) var tableEvents: [TableEvent] = []

    static let serveDelay = 1.2
    static let ejectDelay = 0.9

    init(stall: Stall, seed: UInt64, slow: Bool = false) {
        physics = PinballPhysics(bumpers: stall.layout.positions, seed: seed &* 31 &+ 7)
        physics.slow = slow
        shift = Shift(stall: stall, seed: seed)
    }

    var stall: Stall { shift.stall }
    var isOver: Bool { shift.phase == .over }
    /// 玉が鍋の中（湯気の動き）
    var ballInPot: Bool { ejectIn != nil }

    mutating func start() {
        shift.open()
        serveIn = 0.6
    }

    mutating func press(_ side: Side, _ down: Bool) { physics.press(side, down) }

    mutating func step(_ dt: Double) {
        guard shift.phase == .playing else {
            physics.advance(dt)
            return
        }
        if let s = serveIn {
            let left = s - dt
            if left <= 0 {
                serveIn = nil
                physics.serve()
                shift.ballServed()
            } else {
                serveIn = left
            }
        }
        if let e = ejectIn {
            let left = e - dt
            if left <= 0 {
                ejectIn = nil
                physics.eject()
            } else {
                ejectIn = left
            }
        }
        physics.advance(dt)
        for event in physics.drainEvents() {
            tableEvents.append(event)
            switch event {
            case .bumper(let i):
                shift.hit(stall.ingredients[i])
            case .pot:
                shift.pot()
                ejectIn = Game.ejectDelay
            case .drain:
                shift.drained()
                if shift.phase == .playing { serveIn = Game.serveDelay }
            case .sling, .flipperHit, .pepper:
                break
            }
        }
        shift.tick(dt)
    }

    mutating func drainTableEvents() -> [TableEvent] {
        defer { tableEvents.removeAll() }
        return tableEvents
    }
}
