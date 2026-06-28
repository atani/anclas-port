import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import {
  enrichMatchesWithSchedule,
  fetchGoalNoteGame,
  fetchGoalNoteRanking,
  fetchGoalNoteSchedule,
  parseGoalNoteGame,
  parseGoalNoteSchedule,
  parseScorerRanking,
} from "./lib/goalnote-parser.js";
import { parseQLeagueMatches } from "./lib/qleague-parser.js";
import { fetchShopItems } from "./lib/shop.js";
import { fetchLatestPodcast } from "./lib/spotify.js";
import { calculateStandings } from "./lib/standings.js";
import { findMatchPoster, findMatchReport } from "./lib/wordpress-client.js";
import { logger } from "./lib/logger.js";
import {
  ANCLAS_TEAM_NAME,
  type Match,
  type MatchesData,
  type ScorerRank,
  type StandingsData,
} from "./lib/types.js";

const Q_LEAGUE_URL = "https://q-league.net/match/";
const COMPETITION = "Qリーグ";
const DATA_DIR = new URL("../../data/", import.meta.url);

async function fetchHtml(url: string): Promise<string> {
  const res = await fetch(url, {
    signal: AbortSignal.timeout(20_000),
    headers: { "User-Agent": "anclas-port-pipeline (+https://github.com/atani/anclas-port)" },
  });
  if (!res.ok) throw new Error(`fetch failed: ${res.status} ${res.statusText} ${url}`);
  return res.text();
}

/** players.json から「名前(空白除去) → 背番号」マップを作る（得点ランキングの番号補完用） */
function loadPlayerNumberByName(): Map<string, number> {
  const map = new Map<string, number>();
  const url = new URL("players.json", DATA_DIR);
  if (!existsSync(url)) return map;
  try {
    const data = JSON.parse(readFileSync(url, "utf-8")) as {
      players: { number: number | null; nameJa: string }[];
    };
    for (const p of data.players) {
      if (p.number !== null) map.set(p.nameJa.replace(/[\s　]/g, ""), p.number);
    }
  } catch {
    /* ignore */
  }
  return map;
}

function inferSeason(matches: Match[]): string {
  const counts = new Map<string, number>();
  for (const m of matches) {
    const year = m.date.slice(0, 4);
    counts.set(year, (counts.get(year) ?? 0) + 1);
  }
  let best = "";
  let max = -1;
  for (const [year, n] of counts) {
    if (n > max) { max = n; best = year; }
  }
  return best;
}

function pickNextMatch(matches: Match[], nowMs: number): Match | null {
  return matches
    .filter((m) => m.isAnclas && m.status === "scheduled" && Date.parse(m.datetime) >= nowMs)
    .sort((a, b) => Date.parse(a.datetime) - Date.parse(b.datetime))[0] ?? null;
}

function pickLatestResult(matches: Match[]): Match | null {
  return matches
    .filter((m) => m.isAnclas && m.status === "finished")
    .sort((a, b) => Date.parse(b.datetime) - Date.parse(a.datetime))[0] ?? null;
}

function writeJson(name: string, data: unknown): void {
  mkdirSync(DATA_DIR, { recursive: true });
  writeFileSync(new URL(name, DATA_DIR), `${JSON.stringify(data, null, 2)}\n`, "utf-8");
  logger.info(`wrote ${name}`);
}

async function main(): Promise<void> {
  // 1. q-league → 試合一覧
  const qHtml = await fetchHtml(Q_LEAGUE_URL);
  const matches = parseQLeagueMatches(qHtml, { competition: COMPETITION });
  if (matches.length === 0) throw new Error("試合を1件も抽出できませんでした");
  if (!matches.some((m) => m.isAnclas)) throw new Error(`${ANCLAS_TEAM_NAME} の試合が見つかりませんでした`);

  // 2. GoalNote schedule → 会場・game URL を補完
  try {
    const gnHtml = await fetchGoalNoteSchedule();
    const gnRows = parseGoalNoteSchedule(gnHtml);
    enrichMatchesWithSchedule(matches, gnRows);
    logger.info(`GoalNote schedule: ${gnRows.length}行取得、会場を補完`);
  } catch (e) {
    logger.warn(`GoalNote schedule 取得失敗（会場なしで続行）: ${e}`);
  }

  // 3. GoalNote game → アンクラスの確定試合に得点経過を補完
  const anclasFinished = matches.filter((m) => m.isAnclas && m.status === "finished" && m.goalnoteUrl);
  let goalCount = 0;
  for (const m of anclasFinished) {
    try {
      const gameHtml = await fetchGoalNoteGame(m.goalnoteUrl!);
      const gameData = parseGoalNoteGame(gameHtml, m.homeTeam);
      m.goals = gameData.goals;
      m.starters = gameData.starters;
      m.subs = gameData.subs;
      m.substitutions = gameData.substitutions;
      m.cards = gameData.cards;
      m.stats = gameData.stats;
      goalCount += gameData.goals.length;
    } catch (e) {
      logger.warn(`GoalNote game 取得失敗 ${m.goalnoteUrl}: ${e}`);
    }
  }
  logger.info(`GoalNote game: ${anclasFinished.length}試合から${goalCount}ゴール取得`);

  // 4. anclas.jp マッチレポート → 監督・選手コメントを補完
  const allAnclasFinished = matches.filter((m) => m.isAnclas && m.status === "finished");
  let reportCount = 0;
  for (const m of allAnclasFinished) {
    try {
      const opponent = m.homeTeam === ANCLAS_TEAM_NAME ? m.awayTeam : m.homeTeam;
      const result = await findMatchReport(opponent, m.date);
      if (result) {
        m.matchReport = result.report;
        if (result.photoGallery.length > 0) m.photoGallery = result.photoGallery;
        reportCount++;
      }
    } catch {
      // 非致命
    }
  }
  if (reportCount > 0) logger.info(`マッチレポート: ${reportCount}件取得`);

  // 4.5 確定試合の不変データを前回 matches.json から引き継ぐ
  // CI 環境では anclas.jp が 403 を返しマッチレポート等を取得できないため、
  // 一度取得済みの確定試合データ（得点・メンバー・レポート）を前回値で補完する
  const prevPath = new URL("matches.json", DATA_DIR);
  if (existsSync(prevPath)) {
    try {
      const prev = JSON.parse(readFileSync(prevPath, "utf-8")) as MatchesData;
      const prevById = new Map(prev.matches.map((p) => [p.id, p]));
      let restoredReports = 0;
      for (const m of matches) {
        if (m.status !== "finished") continue;
        const p = prevById.get(m.id);
        if (!p) continue;
        if (m.goals.length === 0 && p.goals.length > 0) m.goals = p.goals;
        if (m.starters.length === 0 && p.starters.length > 0) m.starters = p.starters;
        if (m.subs.length === 0 && p.subs.length > 0) m.subs = p.subs;
        if (m.substitutions.length === 0 && p.substitutions.length > 0) m.substitutions = p.substitutions;
        if (m.cards.length === 0 && p.cards.length > 0) m.cards = p.cards;
        if (!m.stats && p.stats) m.stats = p.stats;
        if (!m.matchReport && p.matchReport) {
          m.matchReport = p.matchReport;
          restoredReports++;
        }
        if (m.photoGallery.length === 0 && p.photoGallery && p.photoGallery.length > 0) {
          m.photoGallery = p.photoGallery;
        }
      }
      if (restoredReports > 0) logger.info(`前回値から${restoredReports}件のマッチレポートを引き継ぎ`);
    } catch {
      // 非致命
    }
  }

  // 5. 次の試合のポスター画像を anclas.jp から取得
  // 該当する告知投稿が無ければ null のまま（古いポスターは出さない）
  const nextMatch = pickNextMatch(matches, Date.now());
  if (nextMatch) {
    try {
      const opponent = nextMatch.homeTeam === ANCLAS_TEAM_NAME ? nextMatch.awayTeam : nextMatch.homeTeam;
      const posterUrl = await findMatchPoster(opponent, nextMatch.date);
      if (posterUrl) {
        nextMatch.posterUrl = posterUrl;
        logger.info(`ポスター取得: ${posterUrl.slice(-40)}`);
      }
    } catch {
      logger.warn("ポスター取得失敗（WP API エラー）");
    }
  }

  // 5. ポッドキャスト最新エピソード（oembed, 認証不要）
  let latestPodcast = await fetchLatestPodcast();
  if (latestPodcast) {
    logger.info(`ポッドキャスト: ${latestPodcast.title.slice(0, 40)}`);
  } else {
    logger.warn("ポッドキャスト取得失敗");
  }

  // 6. オンラインショップ商品（取得失敗時は前回値を引き継ぐ）
  let shopItems = await fetchShopItems();
  if (shopItems.length === 0 && existsSync(prevPath)) {
    try {
      const prev = JSON.parse(readFileSync(prevPath, "utf-8")) as MatchesData;
      if (prev.anclas.shopItems?.length) {
        shopItems = prev.anclas.shopItems;
        logger.info(`ショップ: 前回値${shopItems.length}件を引き継ぎ`);
      }
    } catch { /* ignore */ }
  } else if (shopItems.length > 0) {
    logger.info(`ショップ: ${shopItems.length}商品取得`);
  }

  const generatedAt = new Date().toISOString();
  const season = inferSeason(matches);

  const matchesData: MatchesData = {
    generatedAt,
    season,
    anclas: {
      nextMatch,
      latestResult: pickLatestResult(matches),
      latestPodcast,
      shopItems,
    },
    matches,
  };

  // 6. 得点ランキング（GoalNote）→ アンクラス選手のみ
  let scorers: ScorerRank[] = [];
  try {
    const numberByName = loadPlayerNumberByName();
    const rankHtml = await fetchGoalNoteRanking();
    scorers = parseScorerRanking(rankHtml, numberByName);
    if (scorers.length > 0) logger.info(`得点ランキング: アンクラス${scorers.length}人`);
  } catch {
    logger.warn("得点ランキング取得失敗");
  }
  // 取得失敗時は前回 standings.json の scorers を引き継ぐ
  if (scorers.length === 0) {
    const prevStandings = new URL("standings.json", DATA_DIR);
    if (existsSync(prevStandings)) {
      try {
        const prev = JSON.parse(readFileSync(prevStandings, "utf-8")) as StandingsData;
        if (prev.scorers?.length) {
          scorers = prev.scorers;
          logger.info(`得点ランキング: 前回値${scorers.length}人を引き継ぎ`);
        }
      } catch {
        /* ignore */
      }
    }
  }

  const standingsData: StandingsData = {
    generatedAt,
    season,
    competition: COMPETITION,
    table: calculateStandings(matches),
    scorers,
  };

  writeJson("matches.json", matchesData);
  writeJson("standings.json", standingsData);

  const anclas = matches.filter((m) => m.isAnclas);
  const venued = matches.filter((m) => m.venue).length;
  logger.info(
    `done: ${matches.length}試合 / アンクラス${anclas.length}試合 / 会場あり${venued} / 順位表${standingsData.table.length}チーム / season=${season}`,
  );
}

main().catch((err) => {
  logger.error(`失敗: ${err instanceof Error ? err.message : err}`);
  process.exit(1);
});
