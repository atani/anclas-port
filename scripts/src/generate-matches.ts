import { mkdirSync, writeFileSync } from "node:fs";
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
  if (!res.ok) throw new Error(`q-league fetch failed: ${res.status} ${res.statusText}`);
  return res.text();
}

/** 試合日付の最頻年をシーズンとする */
function inferSeason(matches: Match[]): string {
  const counts = new Map<string, number>();
  for (const m of matches) {
    const year = m.date.slice(0, 4);
    counts.set(year, (counts.get(year) ?? 0) + 1);
  }
  let best = "";
  let max = -1;
  for (const [year, n] of counts) {
    if (n > max) {
      max = n;
      best = year;
    }
  }
  return best;
}

function pickNextMatch(matches: Match[], nowMs: number): Match | null {
  const upcoming = matches
    .filter((m) => m.isAnclas && m.status === "scheduled" && Date.parse(m.datetime) >= nowMs)
    .sort((a, b) => Date.parse(a.datetime) - Date.parse(b.datetime));
  return upcoming[0] ?? null;
}

function pickLatestResult(matches: Match[]): Match | null {
  const past = matches
    .filter((m) => m.isAnclas && m.status === "finished")
    .sort((a, b) => Date.parse(b.datetime) - Date.parse(a.datetime));
  return past[0] ?? null;
}

function writeJson(name: string, data: unknown): void {
  mkdirSync(DATA_DIR, { recursive: true });
  const url = new URL(name, DATA_DIR);
  writeFileSync(url, `${JSON.stringify(data, null, 2)}\n`, "utf-8");
  console.log(`wrote ${name}`);
}

async function main(): Promise<void> {
  const html = await fetchHtml(Q_LEAGUE_URL);
  const matches = parseQLeagueMatches(html, { competition: COMPETITION });
  if (matches.length === 0) {
    throw new Error("試合を1件も抽出できませんでした（HTML構造変化の可能性）");
  }
  if (!matches.some((m) => m.isAnclas)) {
    throw new Error(`${ANCLAS_TEAM_NAME} の試合が見つかりませんでした（リーグ構造変化の可能性）`);
  }

  const generatedAt = new Date().toISOString();
  const season = inferSeason(matches);
  const nowMs = Date.now();

  const matchesData: MatchesData = {
    generatedAt,
    season,
    anclas: {
      nextMatch: pickNextMatch(matches, nowMs),
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
  console.log(
    `done: ${matches.length}試合 / アンクラス${anclas.length}試合 / 順位表${standingsData.table.length}チーム / season=${season}`,
  );
}

main().catch((err) => {
  console.error("[generate-matches] 失敗:", err);
  process.exit(1);
});
