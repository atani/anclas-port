import { mkdirSync, writeFileSync } from "node:fs";
import {
  enrichMatchesWithSchedule,
  fetchGoalNoteGame,
  fetchGoalNoteSchedule,
  parseGoalNoteGame,
  parseGoalNoteSchedule,
} from "./lib/goalnote-parser.js";
import { parseQLeagueMatches } from "./lib/qleague-parser.js";
import { calculateStandings } from "./lib/standings.js";
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
  console.log(`wrote ${name}`);
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
    console.log(`GoalNote schedule: ${gnRows.length}行取得、会場を補完`);
  } catch (e) {
    console.warn(`GoalNote schedule 取得失敗（会場なしで続行）: ${e}`);
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
      console.warn(`GoalNote game 取得失敗 ${m.goalnoteUrl}: ${e}`);
    }
  }
  console.log(`GoalNote game: ${anclasFinished.length}試合から${goalCount}ゴール取得`);

  const generatedAt = new Date().toISOString();
  const season = inferSeason(matches);

  const matchesData: MatchesData = {
    generatedAt,
    season,
    anclas: {
      nextMatch: pickNextMatch(matches, Date.now()),
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
  console.log(
    `done: ${matches.length}試合 / アンクラス${anclas.length}試合 / 会場あり${venued} / 順位表${standingsData.table.length}チーム / season=${season}`,
  );
}

main().catch((err) => {
  console.error("[generate-matches] 失敗:", err);
  process.exit(1);
});
