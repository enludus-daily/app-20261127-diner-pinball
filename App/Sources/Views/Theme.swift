import SwiftUI

/// 昼の食堂の調理台：木のカウンター・銅の鍋・トマトの赤・卵の黄・伝票のクリーム。
/// 色・書体・角丸・影はここだけで決める（画面ごとに色を書かない）
enum Theme {
    // 木（カウンター）の段階：明るい木・ふつう・濃い木・木目の線
    static let woodLight = Color(hex: 0xEFCF9F)
    static let wood = Color(hex: 0xD9A66B)
    static let woodDeep = Color(hex: 0x8F5A33)
    static let woodGrain = Color(hex: 0xB9814D)
    /// 台ごとの木（0 明るい・1 赤み・2 濃い）
    static func playfield(_ wood: Int) -> (top: Color, grain: Color) {
        switch wood {
        case 1: (Color(hex: 0xE8BE93), Color(hex: 0xC98F62))
        case 2: (Color(hex: 0xD6AC7C), Color(hex: 0xA87648))
        default: (Color(hex: 0xF0D3A6), Color(hex: 0xCFA170))
        }
    }

    // 銅（鍋・フリッパーの金具・主なボタン）の段階
    static let copperLight = Color(hex: 0xF0B27C)
    static let copper = Color(hex: 0xC7703A)
    static let copperDeep = Color(hex: 0x8E4420)

    // 伝票の紙とインク
    static let paper = Color(hex: 0xFFF8EA)
    static let paperLine = Color(hex: 0xEBDCC0)
    static let ink = Color(hex: 0x3A2418)
    static let inkSoft = Color(hex: 0x6E5040)

    /// 差し色：トマトの赤（伝票の見出し・いらいら・失った玉）と卵の黄（光・点・連続）
    static let tomato = Color(hex: 0xD9473A)
    static let yolk = Color(hex: 0xF5C342)
    static let basil = Color(hex: 0x4E8B4A)

    /// 黒板（今日の献立）
    static let chalkboard = Color(hex: 0x2F3D35)
    static let chalk = Color(hex: 0xF4F1E6)

    /// 店の外の壁（画面のいちばん奥）
    static let wall = Color(hex: 0xF6E7CE)
    static let tile = Color(hex: 0xEAD5B3)

    /// 待ちの段階の色（にこにこ・そわそわ・いらいら）
    static func mood(_ m: Int) -> Color { [basil, Color(hex: 0xE39B2D), tomato][max(0, min(2, m))] }

    // 書体：看板は太いセリフ、数字は丸い等幅、伝票の手書きは Noteworthy
    static func sign(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .serif) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded).monospacedDigit() }
    static func hand(_ size: CGFloat) -> Font { .custom("Noteworthy-Bold", size: size) }

    // 角丸の段階
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 14
    static let radiusL: CGFloat = 22
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

/// 銅の板のボタン（下辺だけ濃い 4pt の厚み。押すと沈む）
struct CopperButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Theme.body(17, .bold))
            .foregroundStyle(prominent ? Theme.paper : Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .fill(prominent ? Theme.copperDeep : Theme.woodDeep.opacity(0.55))
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .fill(prominent ? Theme.copper : Theme.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                .fill(LinearGradient(colors: [.white.opacity(prominent ? 0.28 : 0), .clear], startPoint: .top, endPoint: .center))
                        )
                        .padding(.bottom, pressed ? 0 : 4)
                        .offset(y: pressed ? 4 : 0)
                }
            }
            .offset(y: pressed ? 0 : -2)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
            .contentShape(Rectangle())
    }
}

/// 伝票の紙（上に赤い線・下がぎざぎざ）
struct TicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tooth: CGFloat = 6
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tooth / 2))
        let n = max(4, Int(rect.width / tooth))
        let w = rect.width / CGFloat(n)
        for i in 0..<n {
            let x = rect.maxX - CGFloat(i) * w
            p.addLine(to: CGPoint(x: x - w / 2, y: rect.maxY))
            p.addLine(to: CGPoint(x: x - w, y: rect.maxY - tooth / 2))
        }
        p.closeSubpath()
        return p
    }
}

/// 木の板の背景（木目の線を Canvas で 1 回だけ描く。押す範囲は持たない）
struct WoodBackground: View {
    var top = Theme.wood
    var grain = Theme.woodGrain
    var plank: CGFloat = 46

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(top))
            var rng = SeededRNG(seed: 11)
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                // 板の継ぎ目
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1.2)), with: .color(grain.opacity(0.55)))
                // 木目（ゆるい波線）
                for k in 0..<3 {
                    var path = Path()
                    let gy = y + plank * (0.25 + 0.25 * CGFloat(k)) + CGFloat(rng.range(-3, 3))
                    path.move(to: CGPoint(x: 0, y: gy))
                    var x: CGFloat = 0
                    while x < size.width {
                        x += 40
                        path.addQuadCurve(to: CGPoint(x: x, y: gy + CGFloat(rng.range(-2.5, 2.5))), control: CGPoint(x: x - 20, y: gy + CGFloat(rng.range(-4, 4))))
                    }
                    ctx.stroke(path, with: .color(grain.opacity(0.22)), lineWidth: 0.8)
                }
                // 縦の継ぎ目（段ごとにずらす）
                let off = CGFloat(row % 2) * 90 + 40
                var x = off
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: plank)), with: .color(grain.opacity(0.35)))
                    x += 180
                }
                y += plank
                row += 1
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
