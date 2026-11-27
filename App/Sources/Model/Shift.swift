import Foundation

/// 伝票（1 人のお客の注文）
struct Order: Identifiable, Equatable, Sendable {
    let id: Int
    let dish: Dish
    let patience: Double
    var waited = 0.0

    var remaining: Double { max(0, patience - waited) }
    var ratio: Double { patience > 0 ? remaining / patience : 0 }
    /// 待ちの段階（0 にこにこ・1 そわそわ・2 いらいら）
    var mood: Int { ratio > 0.5 ? 0 : (ratio > 0.22 ? 1 : 2) }
}

/// 1 回の営業（3 分）の決まり。物理（PinballPhysics）から切り離してテストする
struct Shift: Sendable {
    enum Phase: Equatable, Sendable { case ready, playing, over }

    /// 1 回の長さ（秒）・玉の数・まな板に置ける数
    static let duration = 180.0
    static let ballCount = 3
    static let boardCapacity = 6
    /// 玉を出してからこの秒数のうちに落ちたら、玉を返す
    static let ballSave = 6.0
    /// 伝票が空いてから次のお客が来るまで
    static let nextOrderDelay = 2.5
    /// 続けて出したと数える間（秒）
    static let comboWindow = 20.0

    /// 待てる時間（秒）：材料 1 つで 26 秒 + 18 秒
    static func patience(for dish: Dish) -> Double { 18 + Double(dish.size) * 26 }

    enum Event: Equatable, Sendable {
        case gathered(Ingredient)
        case dropped(Ingredient)
        case served(dishID: String, points: Int, combo: Int, makanai: Int)
        case notReady
        case left(dishID: String)
        case newOrder
        case ballLost(remaining: Int)
        case ballSaved
        case lastCall
        case closed
        case special(dishID: String)
    }

    let stall: Stall
    /// 本日のおすすめ（出すと点が 2 倍）
    var specialID: String?
    private(set) var phase: Phase = .ready
    private(set) var time = 0.0
    private(set) var balls = Shift.ballCount
    private(set) var score = 0
    private(set) var board: [Ingredient] = []
    private(set) var orders: [Order?] = [nil, nil, nil]
    private(set) var served: [String] = []
    private(set) var leftCount = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var hits = 0
    private(set) var events: [Event] = []
    private var lastServe = -100.0
    private var ballServedAt = 0.0
    private var refill: [Double?] = [nil, nil, nil]
    private var nextOrderID = 0
    private var rng: SeededRNG
    private var lastCallSent = false

    init(stall: Stall, seed: UInt64) {
        self.stall = stall
        rng = SeededRNG(seed: seed)
    }

    var timeLeft: Double { max(0, Shift.duration - time) }

    var activeOrders: [Order] { orders.compactMap { $0 } }

    /// 開店：最初のお客 3 人（待てる時間を少しずらす）
    mutating func open() {
        guard phase == .ready else { return }
        phase = .playing
        for i in 0..<3 {
            orders[i] = makeOrder(extra: Double(i) * 12)
        }
    }

    private mutating func makeOrder(extra: Double = 0) -> Order {
        // 同じ料理が並ばないように選ぶ
        let current = Set(activeOrders.map(\.dish.id))
        var pool = stall.dishes.filter { !current.contains($0.id) }
        if pool.isEmpty { pool = stall.dishes }
        let dish = pool[Int(rng.unit() * Double(pool.count)) % pool.count]
        nextOrderID += 1
        return Order(id: nextOrderID, dish: dish, patience: Shift.patience(for: dish) + extra)
    }

    mutating func drainEvents() -> [Event] {
        defer { events.removeAll() }
        return events
    }

    /// 時間を進める（お客が待つ・帰る・次のお客が来る・閉店）
    mutating func tick(_ dt: Double) {
        guard phase == .playing else { return }
        time += dt
        for i in orders.indices {
            if var o = orders[i] {
                o.waited += dt
                if o.remaining <= 0 {
                    orders[i] = nil
                    refill[i] = time + Shift.nextOrderDelay
                    leftCount += 1
                    events.append(.left(dishID: o.dish.id))
                } else {
                    orders[i] = o
                }
            } else if let at = refill[i], time >= at {
                refill[i] = nil
                orders[i] = makeOrder()
                events.append(.newOrder)
            } else if refill[i] == nil {
                refill[i] = time + Shift.nextOrderDelay
            }
        }
        if !lastCallSent && timeLeft <= 30 {
            lastCallSent = true
            events.append(.lastCall)
        }
        if time >= Shift.duration { close() }
    }

    /// 玉を出した
    mutating func ballServed() { ballServedAt = time }

    /// 食材に当たった：まな板に 1 つ置く（いっぱいなら古いものから落ちる）
    mutating func hit(_ kind: Ingredient) {
        guard phase == .playing else { return }
        hits += 1
        board.append(kind)
        events.append(.gathered(kind))
        if board.count > Shift.boardCapacity {
            events.append(.dropped(board.removeFirst()))
        }
    }

    /// 玉が鍋に入った：作れる注文のうち、いちばん待たせているものを出す
    @discardableResult
    mutating func pot() -> Bool {
        guard phase == .playing else { return false }
        let ready = orders.indices.filter { i in orders[i].map { $0.dish.isSatisfied(by: board) } ?? false }
        guard let pick = ready.min(by: { orders[$0]!.remaining < orders[$1]!.remaining }), let order = orders[pick] else {
            events.append(.notReady)
            return false
        }
        for (kind, n) in order.dish.recipe {
            for _ in 0..<n {
                if let at = board.firstIndex(of: kind) { board.remove(at: at) }
            }
        }
        orders[pick] = nil
        refill[pick] = time + Shift.nextOrderDelay
        combo = time - lastServe <= Shift.comboWindow ? min(3, combo + 1) : 1
        bestCombo = max(bestCombo, combo)
        lastServe = time
        // 残った材料のうち、ほかの伝票に要らないものは まかない（1 つ 3 点）
        let needed = activeOrders.reduce(into: [Ingredient: Int]()) { acc, o in
            for (k, n) in o.dish.recipe { acc[k, default: 0] += n }
        }
        var keep: [Ingredient] = []
        var count: [Ingredient: Int] = [:]
        var makanai = 0
        for k in board {
            count[k, default: 0] += 1
            if count[k]! <= needed[k, default: 0] { keep.append(k) } else { makanai += 1 }
        }
        board = keep
        let tip = Int((order.ratio * 10).rounded())
        let special = order.dish.id == specialID ? 2 : 1
        let points = (order.dish.points + tip) * combo * special + makanai * 3
        score += points
        served.append(order.dish.id)
        events.append(.served(dishID: order.dish.id, points: points, combo: combo, makanai: makanai))
        if special > 1 { events.append(.special(dishID: order.dish.id)) }
        return true
    }

    /// 玉が下に落ちた
    mutating func drained() {
        guard phase == .playing else { return }
        if time - ballServedAt <= Shift.ballSave {
            events.append(.ballSaved)
            return
        }
        balls -= 1
        events.append(.ballLost(remaining: balls))
        if balls <= 0 { close() }
    }

    /// 店じまい（時間切れ・玉が尽きた・やめた）
    mutating func close() {
        guard phase == .playing else { return }
        phase = .over
        events.append(.closed)
    }

    /// 次に当てたい食材（いちばん待たせている伝票の、足りない材料）。案内の光と自動の打ち手が使う
    var wanted: [Ingredient] {
        let sorted = activeOrders.sorted { $0.remaining < $1.remaining }
        for o in sorted {
            var have = board
            var need: [Ingredient] = []
            for (k, n) in o.dish.lines {
                for _ in 0..<n {
                    if let at = have.firstIndex(of: k) { have.remove(at: at) } else { need.append(k) }
                }
            }
            if !need.isEmpty { return need }
        }
        return []
    }

    /// 鍋に入れれば出せる伝票がある
    var canServe: Bool { activeOrders.contains { $0.dish.isSatisfied(by: board) } }
}
