# アンクラスPort（Anclas Port）

福岡J・アンクラスの試合情報（次の試合・結果・順位表・選手・ニュース・ポッドキャスト）を集約する iPhone アプリ。

**コンセプト**: アンクラスのすべてが集まる「母港」。クラブ名 Anclas（スペイン語で「錨」）が下ろされる場所＝港（Port）。

## ドキュメント

- [docs/design.md](docs/design.md) — データソース / アーキテクチャ / リアルタイム配信 / フェーズ計画
- [docs/ux-design.md](docs/ux-design.md) — 情報設計 / 画面ワイヤーフレーム / UX 原則

## アーキテクチャ概要

```
GitHub Actions (cron)
  q-league.net / anclas.jp / Spotify を取得 → 正規化JSON生成
  → GitHub Pages (CDN, 無料) で配信  →  [iOS App] が JSON を読む
  → 差分検知 → FCM トピック push（結果・新着エピソード通知）
```

- **バックエンド不要**（GitHub Actions + Pages + FCM、すべて無料枠）
- **無料・広告なし**

## データソース

| ソース | 取得 | 内容 |
|---|---|---|
| q-league.net | HTMLパース | 日程・結果・順位表（全試合） |
| anclas.jp WP REST API | 認証不要 | 選手名鑑・ニュース・マッチレポート・選手ブログ |
| Spotify Web API | Client Credentials | ポッドキャスト「アンクラスのロッカールーム」新着 |

## 構成

- `docs/` — 設計ドキュメント
- `scripts/` — データパイプライン（TypeScript / Node 20）。q-league・anclas.jp を正規化JSON化
- `data/` — 生成された配信用JSON（`matches.json` / `standings.json` / `players.json`）。Actions が自動更新
- `.github/workflows/data-pipeline.yml` — cron で生成 → 差分があれば commit
- `reference/anclas-mcp-server/` — 流用元のパーサー資産（[atani/idea](https://github.com/atani/idea) の anclas-mcp-server）。データパイプラインで再利用

## データパイプライン（Phase 1）

```bash
cd scripts
npm install
npm run typecheck   # 型チェック
npm test            # パーサー単体テスト（実データ fixture 付き）
npm run generate    # q-league / anclas.jp を取得して data/*.json を生成
```

| 生成物 | 内容 |
|---|---|
| `data/matches.json` | アンクラスのリーグ全試合 + `anclas.nextMatch` / `anclas.latestResult` の派生情報 |
| `data/standings.json` | 確定結果から自前計算した順位表 |
| `data/players.json` | 選手名鑑（背番号順） |

## フェーズ

- Phase 1（MVP・サーバレス） — q-league と選手名鑑から JSON を生成し、5画面 + Widget + ローカル通知まで
- Phase 2 — ニュース・ポッドキャスト・FCM リモート push を追加
- Phase 3（見送り） — 試合中ライブスコア（元データに無い）
