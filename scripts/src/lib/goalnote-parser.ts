import { ANCLAS_TEAM_NAME, type GoalEvent, type Position } from "./types.js";

/**
 * GoalNote (goalnote.net) パーサー。
 *
 * schedule page (detail-schedule.php?tid=18626):
 *   全試合一覧。各行に 日付/時刻/ホーム/スコア/アウェイ/会場/詳細リンク。
 *
 * game page (detail-schedule-game.php?tid=18626&sid=XXXXX):
 *   試合詳細。得点経過・スタメン（背番号+ポジション+名前）・交代・警告・
 *   審判団・観客数・天候など。
 */

const BASE_URL = "https://www.goalnote.net/";
const TOURNAMENT_ID = "18626";

function strip(html: string): string {
  return html
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

export interface GoalNoteScheduleRow {
  date: string;
  kickoff: string | null;
  homeTeam: string;
  awayTeam: string;
  score: { home: number; away: number } | null;
  venue: string | null;
  gameUrl: string | null;
}

/** schedule page から全試合の会場・game URL を抽出 */
export function parseGoalNoteSchedule(html: string): GoalNoteScheduleRow[] {
  const rows: GoalNoteScheduleRow[] = [];
  const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let tr: RegExpExecArray | null;
  while ((tr = trRe.exec(html)) !== null) {
    const tdRe = /<td[^>]*>([\s\S]*?)<\/td>/gi;
    const cells: string[] = [];
    let td: RegExpExecArray | null;
    while ((td = tdRe.exec(tr[1] ?? "")) !== null) {
      cells.push(strip(td[1] ?? ""));
    }
    // 典型行: ["", "2026/04/12", "12:00", "福岡J・アンクラス", "2-2 [試合終了]", "ヴィアマテラス...", "宇美町...", "詳細"]
    const dateCell = cells.find((c) => /^\d{4}\/\d{1,2}\/\d{1,2}$/.test(c));
    if (!dateCell) continue;
    const dateIdx = cells.indexOf(dateCell);
    const kickoffCell = cells[dateIdx + 1];
    const homeCell = cells[dateIdx + 2];
    const scoreCell = cells[dateIdx + 3];
    const awayCell = cells[dateIdx + 4];
    const venueCell = cells[dateIdx + 5];
    if (!homeCell || !awayCell) continue;

    const [y, mo, d] = dateCell.split("/");
    const date = `${y}-${String(Number(mo)).padStart(2, "0")}-${String(Number(d)).padStart(2, "0")}`;
    const kickoff = kickoffCell && /^\d{1,2}:\d{2}$/.test(kickoffCell) ? kickoffCell : null;

    let score: { home: number; away: number } | null = null;
    if (scoreCell) {
      const sm = scoreCell.match(/^(\d+)\s*-\s*(\d+)/);
      if (sm) score = { home: Number(sm[1]), away: Number(sm[2]) };
    }

    const linkMatch = (tr[1] ?? "").match(/href="(detail-schedule-game\.php\?[^"]+)"/);
    const gameUrl = linkMatch ? `${BASE_URL}${linkMatch[1]}` : null;

    rows.push({
      date,
      kickoff,
      homeTeam: homeCell,
      awayTeam: awayCell,
      score,
      venue: venueCell || null,
      gameUrl,
    });
  }
  return rows;
}

/** schedule page の行と matches を日付+チーム名でマッチングし、会場とgame URLを補完 */
export function enrichMatchesWithSchedule(
  matches: { date: string; homeTeam: string; awayTeam: string; venue: string | null; goalnoteUrl: string | null }[],
  scheduleRows: GoalNoteScheduleRow[],
): void {
  const index = new Map<string, GoalNoteScheduleRow>();
  for (const r of scheduleRows) {
    index.set(`${r.date}|${r.homeTeam}`, r);
  }
  for (const m of matches) {
    const key = `${m.date}|${m.homeTeam}`;
    const row = index.get(key);
    if (row) {
      if (row.venue) m.venue = row.venue;
      if (row.gameUrl) m.goalnoteUrl = row.gameUrl;
    }
  }
}

// --- game page パーサー ---

export interface GoalNoteGameData {
  goals: GoalEvent[];
  starters: GoalNotePlayer[];
  subs: GoalNotePlayer[];
}

export interface GoalNotePlayer {
  number: number;
  position: Position;
  name: string;
  team: "home" | "away";
}

/** game page から得点経過を抽出 */
function parseGoals(html: string): GoalEvent[] {
  const goals: GoalEvent[] = [];
  // 「得点経過」セクション以降の行: ["30分", "福岡J・アンクラス", "11", "嘉数 クレア姫麗", "22→11S"]
  const section = html.split(/得点経過/i)[1];
  if (!section) return goals;

  const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let tr: RegExpExecArray | null;
  while ((tr = trRe.exec(section)) !== null) {
    const tdRe = /<td[^>]*>([\s\S]*?)<\/td>/gi;
    const cells: string[] = [];
    let td: RegExpExecArray | null;
    while ((td = tdRe.exec(tr[1] ?? "")) !== null) {
      cells.push(strip(td[1] ?? ""));
    }
    // 最低 ["分", "チーム名"] の2セル
    if (cells.length < 2) continue;
    const minute = cells[0] ?? "";
    const team = cells[1] ?? "";
    if (!/\d+分/.test(minute) || !team) continue;

    // OG: cells = ["30分", "福岡J...", "", "オウンゴール", ""]
    // 通常: cells = ["55分", "福岡J...", "11", "嘉数 クレア姫麗", "22→11S"]
    const numStr = cells[2] ?? "";
    const playerNumber = /^\d+$/.test(numStr) ? Number(numStr) : null;
    const playerName = cells[3] ?? cells[2] ?? "";
    const assist = cells[4] || null;

    if (!playerName) continue;
    goals.push({ minute, team, playerNumber, playerName, assist });
  }
  return goals;
}

const VALID_POSITIONS = new Set<string>(["GK", "DF", "MF", "FW", "FP"]);

/** game page からスタメン・交代メンバーを抽出（ホーム/アウェイ両チーム） */
function parseLineups(html: string, homeTeam: string): { starters: GoalNotePlayer[]; subs: GoalNotePlayer[] } {
  const starters: GoalNotePlayer[] = [];
  const subs: GoalNotePlayer[] = [];

  // メンバー表は <tr> の [背番号, ポジション, 名前] 形式
  const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  const tdRe = /<td[^>]*>([\s\S]*?)<\/td>/gi;

  let inHome = true;
  let isStarterSection = true;
  let homeStarterCount = 0;
  let awayStarterCount = 0;

  let tr: RegExpExecArray | null;
  while ((tr = trRe.exec(html)) !== null) {
    const cells: string[] = [];
    tdRe.lastIndex = 0;
    let td: RegExpExecArray | null;
    while ((td = tdRe.exec(tr[1] ?? "")) !== null) {
      cells.push(strip(td[1] ?? ""));
    }
    if (cells.length < 3) continue;
    const numStr = cells[0] ?? "";
    const posStr = (cells[1] ?? "").toUpperCase();
    const name = cells[2] ?? "";
    if (!/^\d+$/.test(numStr)) continue;
    if (!VALID_POSITIONS.has(posStr)) continue;
    if (!name) continue;

    const player: GoalNotePlayer = {
      number: Number(numStr),
      position: posStr as Position,
      name: name.replace(/\s*\(Cap\.\)/i, ""),
      team: "home",
    };

    // ホーム側のスタメンが11人揃ったら次はアウェイ側
    if (inHome) {
      homeStarterCount++;
      player.team = "home";
      if (isStarterSection) {
        starters.push(player);
      } else {
        subs.push(player);
      }
      if (homeStarterCount === 11) {
        inHome = false;
        isStarterSection = true;
      }
    } else {
      awayStarterCount++;
      player.team = "away";
      if (isStarterSection) {
        starters.push(player);
      } else {
        subs.push(player);
      }
      if (awayStarterCount === 11) {
        isStarterSection = false;
        inHome = true;
        homeStarterCount = 0;
      }
    }
  }
  return { starters, subs };
}

/** game page から試合詳細を抽出 */
export function parseGoalNoteGame(html: string, homeTeam: string): GoalNoteGameData {
  return {
    goals: parseGoals(html),
    ...parseLineups(html, homeTeam),
  };
}

/** GoalNote の schedule page を取得 */
export async function fetchGoalNoteSchedule(tid: string = TOURNAMENT_ID): Promise<string> {
  const url = `${BASE_URL}detail-schedule.php?tid=${tid}`;
  const res = await fetch(url, {
    signal: AbortSignal.timeout(15_000),
    headers: { "User-Agent": "anclas-port-pipeline (+https://github.com/atani/anclas-port)" },
  });
  if (!res.ok) throw new Error(`GoalNote schedule fetch failed: ${res.status}`);
  return res.text();
}

/** GoalNote の game page を取得 */
export async function fetchGoalNoteGame(gameUrl: string): Promise<string> {
  const res = await fetch(gameUrl, {
    signal: AbortSignal.timeout(15_000),
    headers: { "User-Agent": "anclas-port-pipeline (+https://github.com/atani/anclas-port)" },
  });
  if (!res.ok) throw new Error(`GoalNote game fetch failed: ${res.status} ${gameUrl}`);
  return res.text();
}

/** アンクラス選手のポジションを GoalNote の最新スタメン情報から逆引きする */
export function buildPositionMap(
  allStarters: GoalNotePlayer[],
): Map<number, Position> {
  const map = new Map<number, Position>();
  for (const p of allStarters) {
    if (p.team === "home" || p.team === "away") {
      // 最新の出場が優先されるよう上書き
      map.set(p.number, p.position);
    }
  }
  return map;
}
