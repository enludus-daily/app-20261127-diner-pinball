import Foundation

/// 食材（台の上のバンパーになる）。色と模様は Views/IngredientArt.swift で描く
enum Ingredient: String, CaseIterable, Codable, Sendable, Hashable {
    case egg, tomato, rice, meat, onion
    case bread, cheese, ham, strawberry
    case scallion, shrimp
    case noodles, seaweed, flour, butter, chocolate, corn, sausage, potato, mushroom, carrot, fish, lemon

    var name: String {
        switch self {
        case .egg: tr("卵", "Egg")
        case .tomato: tr("トマト", "Tomato")
        case .rice: tr("ごはん", "Rice")
        case .meat: tr("お肉", "Meat")
        case .onion: tr("玉ねぎ", "Onion")
        case .bread: tr("パン", "Bread")
        case .cheese: tr("チーズ", "Cheese")
        case .ham: tr("ハム", "Ham")
        case .strawberry: tr("いちご", "Strawberry")
        case .scallion: tr("ねぎ", "Scallion")
        case .shrimp: tr("えび", "Shrimp")
        case .noodles: tr("めん", "Noodles")
        case .seaweed: tr("のり", "Nori")
        case .flour: tr("小麦粉", "Flour")
        case .butter: tr("バター", "Butter")
        case .chocolate: tr("チョコ", "Chocolate")
        case .corn: tr("とうもろこし", "Corn")
        case .sausage: tr("ソーセージ", "Sausage")
        case .potato: tr("じゃがいも", "Potato")
        case .mushroom: tr("きのこ", "Mushroom")
        case .carrot: tr("にんじん", "Carrot")
        case .fish: tr("お魚", "Fish")
        case .lemon: tr("レモン", "Lemon")
        }
    }

    /// 当たったときの音の高さ（ポン。食材ごとに違う）
    var pitch: Double {
        let i = Double(Ingredient.allCases.firstIndex(of: self) ?? 0)
        return 523.3 * pow(2, (i.truncatingRemainder(dividingBy: 8)) / 12 * 2)
    }
}

/// 料理（注文の伝票と図鑑に出る）
struct Dish: Identifiable, Hashable, Sendable {
    let id: String
    let ja: String
    let en: String
    let recipe: [Ingredient: Int]
    let noteJa: String
    let noteEn: String

    var name: String { tr(ja, en) }
    var note: String { tr(noteJa, noteEn) }
    var size: Int { recipe.values.reduce(0, +) }
    /// 出したときの点（材料 1 つ 10 点）
    var points: Int { size * 10 }

    /// 伝票に並べる順（多い材料から）
    var lines: [(Ingredient, Int)] {
        recipe.sorted { a, b in a.value != b.value ? a.value > b.value : a.key.rawValue < b.key.rawValue }.map { ($0.key, $0.value) }
    }

    func isSatisfied(by board: [Ingredient]) -> Bool {
        recipe.allSatisfy { kind, n in board.filter { $0 == kind }.count >= n }
    }

    /// まだ足りない材料の数
    func missing(from board: [Ingredient]) -> Int {
        recipe.reduce(0) { sum, item in sum + max(0, item.value - board.filter { $0 == item.key }.count) }
    }
}

/// 台（お店）。台ごとに食材 5 つと料理と、食材の並べ方が違う
struct Stall: Identifiable, Hashable, Sendable {
    let id: String
    let ja: String
    let en: String
    let taglineJa: String
    let taglineEn: String
    let ingredients: [Ingredient]
    let dishes: [Dish]
    let layout: BumperLayout
    let isPro: Bool
    /// 台の木の色の段階（0 明るい木・1 赤みの木・2 濃い木）
    let wood: Int

    var name: String { tr(ja, en) }
    var tagline: String { tr(taglineJa, taglineEn) }

    static func == (a: Stall, b: Stall) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

/// 食材のバンパーの並べ方（5 つ）
enum BumperLayout: Int, Sendable {
    /// 2・1・2 の X
    case cross
    /// 上 3・下 2
    case arch
    /// 上 2・下 3
    case vee

    var positions: [Vec] {
        switch self {
        case .cross: [Vec(104, 168), Vec(256, 168), Vec(180, 228), Vec(100, 290), Vec(260, 290)]
        case .arch: [Vec(92, 190), Vec(180, 158), Vec(268, 190), Vec(118, 276), Vec(242, 276)]
        case .vee: [Vec(124, 160), Vec(236, 160), Vec(84, 248), Vec(276, 248), Vec(180, 268)]
        }
    }
}

private func makeDish(_ id: String, _ ja: String, _ en: String, _ recipe: [Ingredient: Int], _ noteJa: String, _ noteEn: String) -> Dish {
    Dish(id: id, ja: ja, en: en, recipe: recipe, noteJa: noteJa, noteEn: noteEn)
}

enum Kitchen {
    static let stalls: [Stall] = [
        Stall(id: "diner", ja: "ひだまり洋食", en: "Sunny Diner", taglineJa: "卵とトマトの昼ごはん", taglineEn: "Eggs, tomatoes and lunch rush", ingredients: [.egg, .tomato, .rice, .meat, .onion], dishes: [
            makeDish("omurice", "オムライス", "Omurice", [.egg: 2, .tomato: 1, .rice: 1], "ケチャップで名前を書く人もいる", "Some regulars ask for their name in ketchup"),
            makeDish("hamburg", "ハンバーグ", "Hamburg Steak", [.meat: 2, .onion: 1], "玉ねぎはあめ色まで炒める", "Onions fried until golden"),
            makeDish("eggrice", "目玉焼きごはん", "Egg over Rice", [.egg: 1, .rice: 1], "黄身はくずさずに運ぶ", "Carry it without breaking the yolk"),
            makeDish("tomatosoup", "トマトスープ", "Tomato Soup", [.tomato: 2, .onion: 1], "寒い日のいちばん人気", "The favorite on cold days"),
            makeDish("omelet", "オムレツ", "Plain Omelet", [.egg: 3], "フライパンを 3 回たたく", "Tap the pan three times"),
            makeDish("hayashi", "ハヤシライス", "Hashed Beef Rice", [.meat: 1, .onion: 1, .tomato: 1, .rice: 1], "店主のおばあちゃんの味", "Grandma's own recipe"),
            makeDish("tomatoegg", "トマたま炒め", "Tomato & Egg Stir-fry", [.tomato: 1, .egg: 1], "まかないから表のメニューへ", "Once a staff meal, now on the menu"),
            makeDish("steak", "ステーキ", "Steak", [.meat: 2], "ジュウと鳴るまで出さない", "Served only once it sizzles"),
            makeDish("onionsoup", "オニオンスープ", "Onion Soup", [.onion: 2], "泣きながら刻んだ", "Chopped with tears"),
            makeDish("locomoco", "ロコモコ", "Loco Moco", [.rice: 1, .meat: 1, .egg: 1], "南の島から来た常連の注文", "A regular from the islands orders it"),
        ], layout: .cross, isPro: false, wood: 0),
        Stall(id: "cafe", ja: "こもれび喫茶", en: "Corner Café", taglineJa: "パンとチーズの午後", taglineEn: "Bread, cheese and a slow afternoon", ingredients: [.bread, .egg, .cheese, .ham, .strawberry], dishes: [
            makeDish("eggsando", "たまごサンド", "Egg Sandwich", [.bread: 1, .egg: 2], "ふわふわを押しつぶさない", "Don't squash the fluff"),
            makeDish("hamcheese", "ハムチーズサンド", "Ham & Cheese Sandwich", [.bread: 1, .ham: 1, .cheese: 1], "いちばんよく出る", "The best seller"),
            makeDish("cheesetoast", "チーズトースト", "Cheese Toast", [.bread: 1, .cheese: 1], "のびるチーズが合図", "Ready when the cheese stretches"),
            makeDish("fruitsando", "フルーツサンド", "Fruit Sandwich", [.bread: 1, .strawberry: 2], "切り口を見せて出す", "Served cut-side up"),
            makeDish("frenchtoast", "フレンチトースト", "French Toast", [.bread: 1, .egg: 1], "ひと晩ひたしておく", "Soaked overnight"),
            makeDish("hamegg", "ハムエッグ", "Ham & Eggs", [.ham: 1, .egg: 2], "朝の顔ぶれの定番", "The morning crowd's usual"),
            makeDish("cheeseomelet", "チーズオムレツ", "Cheese Omelet", [.egg: 2, .cheese: 1], "中からとろり", "Melty in the middle"),
            makeDish("croque", "クロックマダム", "Croque Madame", [.bread: 1, .ham: 1, .cheese: 1, .egg: 1], "全部のせの日曜日", "The Sunday everything-sandwich"),
            makeDish("crepe", "いちごクレープ", "Strawberry Crêpe", [.egg: 1, .strawberry: 1], "くるっと三角に", "Folded into a triangle"),
            makeDish("cheesecake", "いちごチーズケーキ", "Strawberry Cheesecake", [.cheese: 1, .strawberry: 1, .egg: 1], "ショーケースの主役", "Star of the display case"),
        ], layout: .arch, isPro: false, wood: 1),
        Stall(id: "wok", ja: "まんぷく飯店", en: "Lucky Wok", taglineJa: "強火と鍋ふりの夜", taglineEn: "High heat and a busy wok", ingredients: [.rice, .egg, .meat, .scallion, .shrimp], dishes: [
            makeDish("friedrice", "チャーハン", "Fried Rice", [.rice: 1, .egg: 1, .scallion: 1], "鍋をあおって米を舞わせる", "Toss until the rice flies"),
            makeDish("eggrice2", "かに玉ごはん", "Egg Foo Young Rice", [.egg: 2, .rice: 1], "あんはたっぷり", "Extra sauce, always"),
            makeDish("chilishrimp", "エビチリ", "Chili Shrimp", [.shrimp: 2, .scallion: 1], "辛さは 3 段階", "Three levels of heat"),
            makeDish("sweetsour", "酢豚", "Sweet & Sour Pork", [.meat: 2], "甘くてすっぱい", "Sweet, then sour"),
            makeDish("shrimprice", "エビチャーハン", "Shrimp Fried Rice", [.rice: 1, .shrimp: 1, .egg: 1], "ぷりっと大きいえび", "Big, bouncy shrimp"),
            makeDish("eggsoup", "たまごスープ", "Egg Drop Soup", [.egg: 1, .scallion: 1], "ふわっと流し入れる", "Poured in a gentle swirl"),
            makeDish("negipork", "ねぎ塩豚", "Scallion Salt Pork", [.meat: 1, .scallion: 2], "ねぎは山もり", "A mountain of scallions"),
            makeDish("shrimpegg", "エビ玉", "Shrimp & Egg", [.shrimp: 1, .egg: 2], "黄色とピンク", "Yellow and pink"),
            makeDish("chopsuey", "中華丼", "Chop Suey Rice", [.rice: 1, .meat: 1, .shrimp: 1, .scallion: 1], "具がごろごろ", "Loaded to the brim"),
            makeDish("porkrice", "肉チャーハン", "Pork Fried Rice", [.rice: 1, .meat: 1, .egg: 1], "まかないの大盛り", "The staff's big bowl"),
        ], layout: .vee, isPro: false, wood: 2),
        Stall(id: "ramen", ja: "湯気ラーメン", en: "Steam Noodle Bar", taglineJa: "カウンター 8 席", taglineEn: "Eight seats at the counter", ingredients: [.noodles, .meat, .egg, .scallion, .seaweed], dishes: [
            makeDish("shoyu", "しょうゆラーメン", "Shoyu Ramen", [.noodles: 1, .meat: 1, .scallion: 1], "スープは毎朝 6 時間", "Six hours of broth every morning"),
            makeDish("ajitama", "味玉ラーメン", "Ramen with Egg", [.noodles: 1, .egg: 1, .meat: 1], "黄身は半熟", "Jammy yolk"),
            makeDish("negiramen", "ねぎラーメン", "Scallion Ramen", [.noodles: 1, .scallion: 2], "麺が見えないほど", "You can't see the noodles"),
            makeDish("noriramen", "のりラーメン", "Nori Ramen", [.noodles: 1, .seaweed: 2], "のりを丼のふちに立てる", "Nori stands along the rim"),
            makeDish("zenbu", "全部のせ", "Everything Ramen", [.noodles: 1, .meat: 1, .egg: 1, .scallion: 1, .seaweed: 1], "常連だけが知る呼び名", "Only regulars know the name"),
        ], layout: .arch, isPro: true, wood: 2),
        Stall(id: "bakery", ja: "こむぎ工房", en: "Wheat & Oven Bakery", taglineJa: "朝 6 時の焼きたて", taglineEn: "Fresh out of the oven at 6 a.m.", ingredients: [.flour, .butter, .egg, .chocolate, .strawberry], dishes: [
            makeDish("croissant", "クロワッサン", "Croissant", [.flour: 1, .butter: 2], "バターを 27 層", "Twenty-seven layers of butter"),
            makeDish("chocobun", "チョコパン", "Chocolate Bun", [.flour: 1, .chocolate: 1], "子どもの列ができる", "Kids line up for it"),
            makeDish("sweetbun", "あまいパン", "Sweet Bun", [.flour: 1, .butter: 1, .egg: 1], "外はさくさく", "Crisp outside"),
            makeDish("danish", "いちごデニッシュ", "Strawberry Danish", [.flour: 1, .butter: 1, .strawberry: 1], "宝石みたいなつや", "Shiny like a jewel"),
            makeDish("brownie", "ブラウニー", "Brownie", [.chocolate: 2, .egg: 1, .butter: 1], "まんなかはしっとり", "Fudgy in the center"),
        ], layout: .cross, isPro: true, wood: 0),
        Stall(id: "stall", ja: "おまつり屋台", en: "Fair Food Stand", taglineJa: "ちょうちんと鉄板", taglineEn: "Lanterns and a hot griddle", ingredients: [.corn, .sausage, .potato, .cheese, .flour], dishes: [
            makeDish("grilledcorn", "焼きとうもろこし", "Grilled Corn", [.corn: 2], "こげ目がごちそう", "The char is the best part"),
            makeDish("sausagestick", "ソーセージ串", "Sausage Skewer", [.sausage: 2], "パリッと音がする", "It snaps when you bite"),
            makeDish("fries", "フライドポテト", "Fries", [.potato: 2], "塩はひとつまみ", "A pinch of salt"),
            makeDish("cheesefries", "チーズポテト", "Cheesy Fries", [.potato: 1, .cheese: 1], "とろけるのを待てない", "Can't wait for the melt"),
            makeDish("corndog", "アメリカンドッグ", "Corn Dog", [.sausage: 1, .flour: 1], "ケチャップとマスタード", "Ketchup and mustard"),
        ], layout: .vee, isPro: true, wood: 1),
        Stall(id: "pizza", ja: "かまど石窯ピザ", en: "Stone Oven Pizza", taglineJa: "450 度で 90 秒", taglineEn: "90 seconds at 450 degrees", ingredients: [.flour, .tomato, .cheese, .mushroom, .sausage], dishes: [
            makeDish("margherita", "マルゲリータ", "Margherita", [.flour: 1, .tomato: 1, .cheese: 1], "赤と白と緑", "Red, white and green"),
            makeDish("funghi", "きのこピザ", "Mushroom Pizza", [.flour: 1, .mushroom: 1, .cheese: 1], "森の香り", "Smells like the forest"),
            makeDish("pepperoni", "ペパロニ", "Pepperoni", [.flour: 1, .sausage: 1, .cheese: 1], "ふちがくるんと丸まる", "The edges curl up"),
            makeDish("fourcheese", "4 種のチーズ", "Four Cheese", [.flour: 1, .cheese: 3], "はちみつをかけても", "Try it with honey"),
            makeDish("supreme", "なんでものせ", "Supreme", [.flour: 1, .tomato: 1, .cheese: 1, .mushroom: 1, .sausage: 1], "生地が見えない", "No crust in sight"),
        ], layout: .cross, isPro: true, wood: 2),
        Stall(id: "curry", ja: "スパイス亭", en: "Spice Curry House", taglineJa: "鍋で煮込んで 2 日目", taglineEn: "Better on day two", ingredients: [.rice, .potato, .carrot, .meat, .onion], dishes: [
            makeDish("porkcurry", "ポークカレー", "Pork Curry", [.rice: 1, .meat: 1, .onion: 1], "いちばん人気", "The house favorite"),
            makeDish("vegcurry", "野菜カレー", "Veggie Curry", [.rice: 1, .potato: 1, .carrot: 1], "ごろごろ野菜", "Chunky vegetables"),
            makeDish("katsucurry", "カツカレー", "Cutlet Curry", [.rice: 1, .meat: 2], "試合の前の日に", "Eaten the night before a big game"),
            makeDish("keema", "キーマカレー", "Keema Curry", [.rice: 1, .meat: 1, .carrot: 1], "ひき肉とにんじん", "Minced meat and carrots"),
            makeDish("loaded", "具だくさんカレー", "Loaded Curry", [.rice: 1, .potato: 1, .carrot: 1, .meat: 1, .onion: 1], "スプーンが立つ", "The spoon stands up"),
        ], layout: .arch, isPro: true, wood: 1),
        Stall(id: "seaside", ja: "なみうち食堂", en: "Seaside Grill", taglineJa: "潮風と炭火", taglineEn: "Sea breeze and charcoal", ingredients: [.fish, .shrimp, .corn, .rice, .lemon], dishes: [
            makeDish("grilledfish", "焼き魚", "Grilled Fish", [.fish: 1, .lemon: 1], "けさ揚がった魚", "Caught this morning"),
            makeDish("friedshrimp", "エビフライ", "Fried Shrimp", [.shrimp: 2, .lemon: 1], "しっぽまで食べられる", "Crunchy down to the tail"),
            makeDish("pilaf", "シーフードピラフ", "Seafood Pilaf", [.rice: 1, .shrimp: 1, .fish: 1], "フライパンごと出す", "Served in the pan"),
            makeDish("fishtaco", "魚のタコス", "Fish Tacos", [.fish: 1, .corn: 1, .lemon: 1], "レモンをぎゅっと", "Squeeze the lemon"),
            makeDish("cornsoup", "コーンスープ", "Corn Soup", [.corn: 2], "海の家の朝ごはん", "Breakfast by the beach"),
        ], layout: .vee, isPro: true, wood: 0),
    ]

    static var allDishes: [Dish] { stalls.flatMap(\.dishes) }
    static var freeStalls: [Stall] { stalls.filter { !$0.isPro } }

    static func stall(_ id: String) -> Stall { stalls.first { $0.id == id } ?? stalls[0] }
    static func dish(_ id: String) -> Dish? { allDishes.first { $0.id == id } }
    static func stall(of dish: Dish) -> Stall { stalls.first { $0.dishes.contains(dish) } ?? stalls[0] }
}
