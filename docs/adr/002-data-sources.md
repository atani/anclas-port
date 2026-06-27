# ADR-002: データソースの選定と役割分担

## ステータス

承認済み（2026-06-28）

## コンテキスト

アンクラスの試合・選手情報を取得するデータソースが複数ある。それぞれ網羅性・速報性・取得可能な項目が異なるため、役割分担を明確にする必要があった。

## 決定

3つのデータソースを以下の役割で併用する。

### 一次ソース: q-league.net（試合一覧の骨格）

- URL: `https://q-league.net/match/`
- 取得: HTMLパース（`<li class="su-post">` 行）
- 役割: **全試合の日程・スコア・対戦カードの一次情報**
- 取れるもの: 日付・時刻・ホーム/アウェイ・スコア・節番号
- 取れないもの: 会場名・得点者・メンバー・ポジション
- 更新頻度: 試合後数時間〜翌日

### 補完ソース: GoalNote（会場・得点者・スタメン）

- URL: `https://www.goalnote.net/detail-schedule.php?tid=18626`
- 取得: HTMLパース（schedule page + game page）
- 役割: **q-league では取れない会場名・得点者・時間・アシスト・スタメン（ポジション付き）を補完**
- schedule page で全試合の会場名と game page URL を取得
- game page でアンクラスの確定試合の得点経過・メンバー表を取得
- 更新頻度: 試合中〜直後（q-league より速い可能性あり）

### 二次ソース: anclas.jp WP REST API（選手名鑑・ニュース）

- URL: `https://anclas.jp/wp-json/wp/v2/`
- 取得: REST API（認証不要）
- 役割: **選手名鑑（写真・プロフィール・パーソナル情報）の一次情報**、ニュース・マッチレポートのリッチコンテンツ（Phase 2）
- 注意: CI 環境（GitHub Actions）から 403 を返すことがある。取得失敗を非致命にし、前回データを保持する

### データの流れ

```
q-league (一次) → 試合の骨格（日付/スコア/チーム名）
     ↓
GoalNote (補完) → 会場名・得点者・スタメンを付加
     ↓
anclas.jp (二次) → 選手名鑑を独立生成
     ↓
正規化 JSON（matches.json / standings.json / players.json）
     ↓
GitHub Pages → iOS アプリ
```

### なぜ GoalNote を一次にしないか

GoalNote は情報量が圧倒的に多いが、HTML構造が複雑でチーム名の表記揺れ（「ウイメン」vs「ウィメン」等）が q-league と異なる。試合一覧の骨格は構造が単純な q-league をマスターにし、GoalNote は日付+チーム名でマッチングして補完する設計の方が、どちらかの構造が変わっても壊れにくい。

## 影響

- `scripts/src/lib/qleague-parser.ts`: 一次ソースパーサー
- `scripts/src/lib/goalnote-parser.ts`: 補完ソースパーサー
- `scripts/src/lib/wordpress-client.ts` + `player-parser.ts`: 二次ソース
- `scripts/src/generate-matches.ts`: q-league → GoalNote 補完 → JSON 出力
- `scripts/src/generate-players.ts`: anclas.jp → JSON 出力（失敗時は前回保持）
