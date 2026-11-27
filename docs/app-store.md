# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.020 |
| アプリ名 | まんぷくピンボール：注文をはじけ / Diner Pinball: Flip & Cook |
| サポート URL | https://github.com/enludus-daily/app-20261127-diner-pinball/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261127-diner-pinball/blob/main/PRIVACY.md |
| 年齢区分の答え | 暴力・ギャンブル・Web 閲覧・生成 AI・ユーザー同士のやりとり：すべてなし（4+ の見込み）。シミュレートされたギャンブルもなし（ピンボールに賭けはない） |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ） |
| App 内課金 | `com.enludus.daily.020.pro`（非消耗型・¥480）。審査用の画像は `docs/iap/paywall.png`（CI の撮影 paywall_ja から） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・効果音・占いなどではないゲーム。ピンボールの物理に「注文の材料をそろえて鍋に落とす」決まりと、お店 9・料理 60 の中身がある。
- 既存のアプリとの意味のある違い：ピンボールで材料を集めて注文の料理を作るアプリは見当たらない（Salad Pinball は料理なし、料理ゲームはタップで作る）。
- 長く使える価値（4.2）：日付で決まる今日の献立・続けた日数・料理図鑑 60 品・お店ごとに違う並べ方。
- 他社の名前・商標・見た目を使っていないか：使っていない（料理名は一般名、絵はすべて自作の Canvas、ピンボールの台の形もオリジナル）。
- Apple Intelligence：使わない。

## 収益の道筋

- 買い切り（StoreKit 2）の Pro ¥480。理由と勝算の表は README の「課金」。

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。日本語と英語。

## 本人がすること

- [ ] 枠 020 の App を App Store Connect に足す（足したら次のセッションが products → TestFlight → metadata を出す）
- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
