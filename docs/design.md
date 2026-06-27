# アンクラスPort（Anclas Port）設計ドキュメント

福岡J・アンクラスの試合情報（次の試合・結果・順位表・選手・ニュース）を1アプリに集約する iPhone アプリ。

## アプリ名: アンクラスPort（Anclas Port）

- **コンセプト**: アンクラスのすべてが集まる「**母港**」。クラブ名 Anclas（スペイン語で「錨」）が下ろされる場所＝港（Port）。試合・選手・ニュースがここに停泊し、サポーターが帰ってくるホーム
- **由来の一貫性**: 錨（クラブ名）→ 港（停泊地）の連想で、クラブの世界観と直結。「ancla（錨）」は比喩で「拠り所・心の支え」の意味も持ち、アプリの立ち位置と響き合う
- **印象**: 落ち着いた大人なトーン。応援系より穏やか
- **表記**: アンクラスPort（日本語UI）/ Anclas Port（英字・App Store 表示名）
- **アイコン方針**: 錨 ⚓ モチーフ + クラブカラー
- **App Store**: 表示名に「アンクラス」を含み検索性を確保。subtitle で「福岡J・アンクラス 試合・選手・日程」等を補う。最終的な名称重複は申請時に App Store Connect で確認する

- 出自: アイデアストック S-21
- 判定履歴: `/idea-killer` → Build（Kill 0 / Wound 3）、`/apple-idea-screen` → Refine（趣味プロジェクトとして許容）
- 方針: **無料・広告なし**。収益度外視。サーバ運用コストゼロを維持する

---

## 1. 大前提（確定事項）

| 項目 | 決定 | 理由 |
|---|---|---|
| 収益 | 無料・広告なし | ユーザー方針。Apple Developer 年額 $99 は趣味として許容 |
| X(Twitter) 連携 | **やらない** | 2026年2月に X API 無料枠廃止。pay-per-use の月数ドルコストを許容しない方針 |
| データ配信 | **GitHub Actions 中継**（後述） | 元データが試合後更新でリアルタイム性を失わない。壊れてもアプリ審査なしで直せる |
| リアルタイム配信 | FCM トピック push（無料） | 結果確定から5〜15分で全端末に通知 |

---

## 2. データソースと役割分担

### 2.1 一次ソース: q-league.net（構造化データ）

九州女子サッカーリーグ公式。**全チームの全試合**が完全統一フォーマットで掲載されている。

- URL: `https://q-league.net/match/`
- HTML 構造（実測済み）:
  ```html
  <li class="su-post"><a href="...">2026/04/12 12:00 福岡J・アンクラス【2-2】ヴィアマテラス宮崎Alegrita</a></li>
  ```
- パースルール:
  - `YYYY/MM/DD HH:MM ホーム【スコア or vs】アウェイ` の固定形式
  - `【数字-数字】` → 確定結果 / `【vs】` → 未消化
  - アンクラスの試合 = ホーム or アウェイに「福岡J・アンクラス」を含む行
- ここから取れるもの: **次の試合・試合結果・順位表（全試合の勝敗から自前計算）**

### 2.2 二次ソース: anclas.jp WP REST API（リッチコンテンツ）

クラブ公式サイト。WordPress REST API が認証不要で使える。

- ベース: `https://anclas.jp/wp-json/wp/v2/`
- 取れるもの: マッチレポート・**選手名鑑**・選手ブログ・クラブニュース
- 既存資産: `anclas-mcp-server/src/parser.ts` にパースロジックが実装済み（試合情報・得点者・会場・日時抽出）
- 注意: **試合ごとの記事は不完全**（2026 Qリーグカテゴリの記事数が少ない）。日程・結果の一次ソースにはしない。あくまでレポート・ニュースのリッチ表示用

#### 選手名鑑（`/category/top-players{年}/` カテゴリ・実測済み）

選手プロフィールは「TOP選手紹介」カテゴリの投稿として構造化されている（2026は categoryID=46、slug `top-players2025` 系。**年度でカテゴリが変わるため Actions で動的検出**＝試合カテゴリと同じ手法）。

- 1選手 = 1投稿。取れる項目:
  - **背番号**: タイトルの `#3` 等
  - **名前**: 漢字 + ローマ字（タイトル `#3澁澤光-shibusawa hikaru-`）
  - **顔写真**: featured_media（thumbnail〜full の複数サイズ）
  - **基本**（本文 `<p>` 内、全角スペース区切り）: 生年月日・出身・身長・血液型・ニックネーム・経歴
  - **詳細**（本文 `<table>` 2列）: サッカー歴・始めたきっかけ・MBTI・趣味・好きな食べ物・好きなキャラ・オフの過ごし方・プレー特長・ルーティン 等
- パース: `<p>`（全角スペース）と `<table>`（td 2列）の2構造を Actions 側で吸収して正規化 JSON 化
- **ポジション（GK/DF/MF/FW）は明示項目に無い** → 背番号順表示を基本とする。将来 GoalNote 等で補完可能なら検討
- 選手ブログとの紐付け: ブログは「○○ブログ」タグで管理。名鑑の選手名とタグ名でマッチング

### 2.3 順位表

q-league.net に順位表の構造化データは無い（画像 or GoalNote へのリンク）。
→ **全試合の確定結果から自前計算**する（勝点・得失点差・総得点）。外部依存を増やさず最も堅牢。

### 2.4 三次ソース: Spotify ポッドキャスト「アンクラスのロッカールーム」

クラブ公式ポッドキャスト（福岡J・アンクラス公式）。新着エピソード情報をアプリに出す。

- show URL: `https://open.spotify.com/show/3RnkWRyIMYe9IdtMmK7KFK`
- **Apple Podcasts に無い = Spotify 独占配信**（Spotify for Creators ホスティング、RSS非公開）。実測で Apple Podcasts / anchor.fm の RSS は見つからず
- 取得手段:
  - **主軸: Spotify Web API**（`GET /v1/shows/{id}/episodes?market=JP`）。**Client Credentials flow（無料・ユーザー認証不要）**。Spotify Developer Dashboard で client_id/secret を取得（無料）し、Actions が token を取得してエピソード一覧を取る
  - フォールバック: `open.spotify.com/oembed?url=...`（認証不要だが最新1件のタイトルのみ。新着検知の簡易用途には使える）
- **重要な制約**: アプリ内でエピソードを再生はしない（Spotify SDK/規約）。アプリの役割は **新着エピソードの一覧表示 + タップで Spotify アプリ/Web を開く**（`https://open.spotify.com/episode/{id}`）まで
- credentials は GitHub Secrets に格納。アプリ側には Spotify の鍵を一切持たせない（中継アーキテクチャの利点）

---

## 3. アーキテクチャ: GitHub Actions 中継

```
GitHub Actions (cron 5分間隔)
  1. q-league.net/match/ を取得 → HTMLパース → アンクラス試合 + 全試合
  2. anclas.jp WP API を取得 → ニュース・レポート・選手ブログ
  3. 順位表を全試合結果から計算
  4. 正規化JSON を生成（matches.json / standings.json / news.json）
  5. 前回commitとのdiff → 「新しい確定結果」「日程変更」を検知
  6. 差分あり →
       (a) JSON を commit（GitHub Pages で CDN 配信）
       (b) FCM トピック「anclas」へ push
        ↓
[iOS App]
  - 起動時 / Pull-to-refresh で GitHub Pages の JSON を取得して表示
  - FCMトピック「anclas」を購読して結果通知を受信
  - 試合日時からローカル通知を端末内スケジュール
```

### なぜ中継か（アプリ直接パースとの比較）

| 観点 | Actions 中継（採用） | アプリ直接パース |
|---|---|---|
| HTML構造変化時 | Actions スクリプト修正だけで全ユーザーに即反映 | アプリ修正 → 審査（数日）→ それまで全ユーザー壊れる |
| 既存資産 | parser.ts(TS) をほぼ流用 | Swift に移植し直し |
| アプリの複雑度 | JSON を読むだけ（堅牢） | 壊れやすいHTMLパースを端末に持つ |
| 差分検知 / push | git diff で無料で実現 | 別途仕組みが必要 |
| コスト | Actions/Pages/FCM すべて無料 | 同左 |

### コスト（すべて無料枠内）

- GitHub Actions: cron 5分 = 月約8,640分。public リポジトリなら無制限、private でも無料枠2,000分/月 → public 運用で回避
- GitHub Pages: CDN 配信無料
- FCM: 無料
- APNs: Apple Developer Program（$99/年）に含まれる

---

## 4. リアルタイム配信の3階層

| 階層 | 内容 | 手段 | コスト | 精度 | フェーズ |
|---|---|---|---|---|---|
| ① | 試合リマインド | ローカル通知（端末内スケジュール） | 無料・サーバ不要 | 時刻正確 | Phase 1 |
| ② | 結果が出たら通知 / **新着エピソード通知** | Actions監視 → FCMトピックpush | 無料 | 5〜15分遅延 | Phase 2 |
| ③ | 試合中ライブスコア | 元データ無し → 手入力の仕組み要 | 要バックエンド | — | 見送り |

②の「新着」は試合結果だけでなく、Spotify ポッドキャストの新エピソード公開も同じ FCM 仕組みで流せる（Actions が episodes の diff を検知）。

③は元データ（q-league/anclas）に存在しないため、やるなら自分が会場から入力する別アーキテクチャが必要。当面やらない。

---

## 5. 画面構成

| 画面 | 内容 | データ |
|---|---|---|
| **ホーム / 次の試合** | 直近の未消化試合（日時・対戦相手・会場）。起動直後に表示 | q-league + anclas(会場補完) |
| **日程（今後の試合）** | 全節のスケジュールをタイムライン表示。ホーム/アウェイ区別 | q-league |
| **試合結果** | アンクラスの確定結果一覧（スコア・得点者） | q-league + anclas(得点者補完) |
| **順位表** | Qリーグ1部の順位表（勝点・得失点） | q-league から計算 |
| **選手名鑑** | 背番号順グリッド → 選手詳細（写真・プロフィール・ブログ導線） | anclas.jp top-players カテゴリ |
| **ニュース** | クラブニュース・マッチレポート・選手ブログ | anclas.jp WP API |
| **ポッドキャスト** | 「アンクラスのロッカールーム」新着エピソード一覧。タップで Spotify を開く | Spotify Web API |
| **Widget** | 次の試合 / 直近結果（ホーム画面） | JSON |

詳細な情報設計・ワイヤーフレーム・UX 原則は `ux-design.md` を参照。

### 初回体験（idea-killer Q6 対応）

- ログイン不要・設定不要。開いた瞬間に「次の試合」が出る
- データは起動時に JSON を1回取得するだけ

---

## 6. 技術スタック

| 領域 | 選定 | 備考 |
|---|---|---|
| アプリ | SwiftUI | iOS ネイティブ。Widget(WidgetKit)・通知と統合しやすい |
| Widget | WidgetKit | 次の試合 / 直近結果 |
| 通知 | UserNotifications(ローカル) + FCM(リモート) | Phase 1 はローカルのみ |
| データ取得層 | GitHub Actions (TypeScript) | parser.ts を流用 |
| データ配信 | GitHub Pages (静的JSON) | CDN |
| push | Firebase Cloud Messaging | トピック購読モデル |

---

## 7. フェーズ計画

### Phase 1（MVP・完全無料・サーバレス）
- [ ] GitHub Actions: q-league パース → matches.json / standings.json 生成 → Pages 配信
- [ ] GitHub Actions: anclas top-players パース → players.json 生成
- [ ] SwiftUI: ホーム（次の試合）/ 日程 / 試合結果 / 順位表 / 選手名鑑 の5画面
- [ ] WidgetKit: 次の試合 Widget
- [ ] ローカル通知: 試合リマインド（キックオフ前）

### Phase 2（ニュース + ポッドキャスト + リモート push）
- [ ] anclas.jp WP API 連携: ニュース・マッチレポート・選手ブログ
- [ ] Spotify Web API 連携: 「アンクラスのロッカールーム」新着エピソード一覧（表示 + ディープリンク）
- [ ] Actions の差分検知 → FCM トピック push（結果通知 / 新着エピソード通知）
- [ ] アプリ: FCM 購読

### Phase 3（見送り・将来検討）
- 試合中ライブスコア（要・手入力アーキテクチャ）
- Live Activity（試合中のスコア常時表示）

---

## 8. リスクと対策（idea-killer の Wound）

| リスク | 対策 |
|---|---|
| Q2: Player! が復活したら差別化が要る | 1クラブ特化の軽さ・Widget・通知で差別化。汎用アプリにない速さ |
| Q3: q-league/anclas のHTML構造変化 | Actions 中継により、スクリプト修正だけで全ユーザーに即反映（アプリ審査不要） |
| Q4: サポーター母数が小さい | 自分がコミュニティ内にいる。最初の数十人に直接届ける |
| Spotify API 仕様変更 | 取得は Actions 側に隔離。エンドポイント変更時もスクリプト修正だけで対応。アプリには鍵を持たせない |
| 商標・ロゴ | 非公式アプリとして出す場合はクラブ名・ロゴの扱いに注意。公式承認を打診する選択肢も |

---

## 9. 既存資産

- `anclas-mcp-server/src/parser.ts`: 試合情報・得点者・会場・日時のパースロジック（TypeScript）。Actions にほぼ流用可能
- `anclas-mcp-server/src/wordpress-client.ts`: anclas.jp WP API クライアント・カテゴリ動的検出
