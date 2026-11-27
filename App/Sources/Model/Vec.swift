import Foundation

/// 台の上の位置と速さ（台の大きさは 360 × 600。y は下向き）
struct Vec: Equatable, Hashable, Sendable, Codable {
    var x: Double
    var y: Double

    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }

    static let zero = Vec(0, 0)
    static func + (a: Vec, b: Vec) -> Vec { Vec(a.x + b.x, a.y + b.y) }
    static func - (a: Vec, b: Vec) -> Vec { Vec(a.x - b.x, a.y - b.y) }
    static func * (a: Vec, k: Double) -> Vec { Vec(a.x * k, a.y * k) }
    static prefix func - (a: Vec) -> Vec { Vec(-a.x, -a.y) }
    static func += (a: inout Vec, b: Vec) { a = a + b }
    static func -= (a: inout Vec, b: Vec) { a = a - b }

    func dot(_ b: Vec) -> Double { x * b.x + y * b.y }
    var length: Double { (x * x + y * y).squareRoot() }
    var normalized: Vec { let l = length; return l > 1e-9 ? Vec(x / l, y / l) : Vec(0, -1) }
    /// 90 度まわした向き（角度が増える向きの速さに使う）
    var perp: Vec { Vec(-y, x) }

    static func angle(_ a: Double) -> Vec { Vec(cos(a), sin(a)) }

    func distance(to b: Vec) -> Double { (self - b).length }
}

/// 決まった種の乱数（同じ種なら同じ献立・同じ散り方になる。テストと撮影が安定する）
struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 以上 1 未満
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * unit() }
}

/// 点 p に一番近い、線分 a–b の上の点
func closestPoint(_ p: Vec, _ a: Vec, _ b: Vec) -> (point: Vec, t: Double) {
    let ab = b - a
    let len2 = ab.dot(ab)
    guard len2 > 1e-9 else { return (a, 0) }
    let t = max(0, min(1, (p - a).dot(ab) / len2))
    return (a + ab * t, t)
}
