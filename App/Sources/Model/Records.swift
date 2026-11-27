import Foundation

/// 日付の鍵（yyyy-MM-dd）と、日をずらす計算
enum Days {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    static func offset(_ date: Date, days: Int, calendar: Calendar = .current) -> String {
        key(calendar.date(byAdding: .day, value: days, to: date) ?? date, calendar: calendar)
    }

    /// 日付から決まる数（だれでも同じ日には同じ献立）
    static func seed(_ key: String) -> UInt64 {
        var h: UInt64 = 1_469_598_103_934_665_603
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 1_099_511_628_211 }
        return h
    }
}

/// 毎日の献立：日付で台（無料の 3 台から）と注文の順が決まる
struct DailyMenu: Equatable, Sendable {
    let day: String

    var seed: UInt64 { Days.seed("menu-" + day) }
    var stall: Stall {
        let free = Kitchen.freeStalls
        return free[Int(seed % UInt64(free.count))]
    }
}

/// 1 回の営業の結果
struct ShiftResult: Equatable, Sendable {
    let stallID: String
    let day: String?
    let score: Int
    let served: [String]
    let left: Int
    let bestCombo: Int
    var newDishes: [String] = []
    var isBest = false

    init(stallID: String, day: String?, score: Int, served: [String], left: Int, bestCombo: Int) {
        self.stallID = stallID
        self.day = day
        self.score = score
        self.served = served
        self.left = left
        self.bestCombo = bestCombo
    }

    init(_ shift: Shift, day: String?) {
        self.init(stallID: shift.stall.id, day: day, score: shift.score, served: shift.served, left: shift.leftCount, bestCombo: shift.bestCombo)
    }

    /// 星（0〜3）：出した料理の数で決める
    var stars: Int { served.count >= 12 ? 3 : (served.count >= 7 ? 2 : (served.count >= 3 ? 1 : 0)) }

    /// 共有の一行（絵文字：🍽 出した・💨 帰った）
    func shareText(stallName: String) -> String {
        let plates = String(repeating: "🍽", count: min(served.count, 15))
        let gone = String(repeating: "💨", count: min(left, 6))
        return trf("まんぷくピンボール %@ %d 点\n%@%@", "Diner Pinball %@ %d pts\n%@%@", stallName, score, plates, gone)
    }
}

/// 端末の中にだけ残す記録（1 回の営業の終わりにだけ保存する）
struct SaveData: Codable, Equatable, Sendable {
    var best: [String: Int] = [:]
    var cooked: [String: Int] = [:]
    var daily: [String: Int] = [:]
    var streak = 0
    var bestStreak = 0
    var lastDaily: String?
    var shifts = 0
    var totalServed = 0
    var paywallDay: String?
    var tutorialDone = false
    /// Pro の台を 1 日 1 回だけ試した日
    var trialDay: String?

    var discovered: Set<String> { Set(cooked.keys) }

    /// 結果を記録に入れる（新しく図鑑に入った料理・自己ベストを返す）
    mutating func record(_ result: ShiftResult, today: String, yesterday: String) -> ShiftResult {
        var r = result
        shifts += 1
        totalServed += result.served.count
        var fresh: [String] = []
        for id in result.served {
            if cooked[id] == nil && !fresh.contains(id) { fresh.append(id) }
            cooked[id, default: 0] += 1
        }
        r.newDishes = fresh
        let old = best[result.stallID] ?? 0
        r.isBest = result.score > old && result.score > 0
        best[result.stallID] = max(old, result.score)
        if let day = result.day {
            daily[day] = max(daily[day] ?? 0, result.score)
            if day == today {
                if lastDaily == yesterday {
                    streak += 1
                } else if lastDaily != today {
                    streak = 1
                }
                lastDaily = today
                bestStreak = max(bestStreak, streak)
            }
        }
        return r
    }

    /// 開いたとき：昨日も今日も遊んでいなければ、続けた日数は 0 に戻す（いちばん長い記録は残す）
    mutating func refreshStreak(today: String, yesterday: String) {
        if lastDaily != today && lastDaily != yesterday { streak = 0 }
    }

    func playedToday(_ today: String) -> Bool { daily[today] != nil }
}

/// 保存（UserDefaults に JSON で。PrivacyInfo.xcprivacy に CA92.1 で申告済み）
enum SaveStore {
    static let key = "diner.save.v1"

    static func load(_ defaults: UserDefaults = .standard) -> SaveData {
        guard let data = defaults.data(forKey: key), let save = try? JSONDecoder().decode(SaveData.self, from: data) else { return SaveData() }
        return save
    }

    static func write(_ save: SaveData, _ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(save) { defaults.set(data, forKey: key) }
    }
}
