import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import {
  enrichMatchesWithSchedule,
  fetchGoalNoteGame,
  fetchGoalNoteSchedule,
  parseGoalNoteGame,
  parseGoalNoteSchedule,
} from "./lib/goalnote-parser.js";
import { parseQLeagueMatches } from "./lib/qleague-parser.js";
import { calculateStandings } from "./lib/standings.js";
import { findMatchPoster } from "./lib/wordpress-client.js";
import { logger } from "./lib/logger.js";
import { ANCLAS_TEAM_NAME, type Match, type MatchesData, type StandingsData } from "./lib/types.js";

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
      goalCount += gameData.goals.length;
    } catch (e) {
      logger.warn(`GoalNote game 取得失敗 ${m.goalnoteUrl}: ${e}`);
    }
  }
  logger.info(`GoalNote game: ${anclasFinished.length}試合から${goalCount}ゴール取得`);

  // 4. 次の試合のポスター画像を anclas.jp から取得（失敗時は前回値を保持）
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
      // WP API 失敗時は前回生成した matches.json から posterUrl を引き継ぐ
    }
    if (!nextMatch.posterUrl) {
      const prevUrl = new URL("matches.json", DATA_DIR);
      if (existsSync(prevUrl)) {
        try {
          const prev = JSON.parse(readFileSync(prevUrl, "utf-8")) as MatchesData;
          if (prev.anclas.nextMatch?.posterUrl && prev.anclas.nextMatch.id === nextMatch.id) {
            nextMatch.posterUrl = prev.anclas.nextMatch.posterUrl;
            logger.info(`ポスター: 前回値を引き継ぎ`);
          }
        } catch { /* ignore */ }
      }
    }
  }

  const generatedAt = new Date().toISOString();
  const season = inferSeason(matches);

  const matchesData: MatchesData = {
    generatedAt,
    season,
    anclas: {
      nextMatch,
      latestResult: pickLatestResult(matches),
    },
    matches,
  };

  const standingsData: StandingsData = {
    generatedAt,
    season,
    competition: COMPETITION,
    table: calculateStandings(matches),
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
