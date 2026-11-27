import Foundation

/// 画面の言葉（日本語と英語）。撮影では日本語を強制できる（CI のシミュレータは英語のため）。
/// 英語は Localizable.xcstrings（scripts/gen-strings.py がコードの tr から作る）にも入る。
enum Lang {
    nonisolated(unsafe) static var forcedJapanese = false

    static var isJapanese: Bool {
        forcedJapanese || (Bundle.main.preferredLocalizations.first ?? "ja").hasPrefix("ja")
    }

    static var locale: Locale { Locale(identifier: isJapanese ? "ja_JP" : "en_US") }

    static let english: Bundle? = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
}

/// 言葉を選ぶ（日本語, 英語）
func tr(_ ja: String, _ en: String) -> String {
    if Lang.isJapanese { return ja }
    guard let bundle = Lang.english else { return en }
    let found = bundle.localizedString(forKey: ja, value: nil, table: "Localizable")
    return found == ja ? en : found
}

/// 数などを差し込む言葉（%d・%@）
func trf(_ ja: String, _ en: String, _ args: CVarArg...) -> String {
    String(format: tr(ja, en), locale: Lang.locale, arguments: args)
}
