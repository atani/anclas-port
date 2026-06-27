import { ANCLAS_TEAM_NAME, type GoalEvent, type Position, type Substitution } from "./types.js";

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

export interface MatchStats {
  attendance: string | null;
  weather: string | null;
  temperature: string | null;
  pitch: string | null;
}

export interface GoalNoteGameData {
  goals: GoalEvent[];
  starters: GoalNotePlayer[];
  subs: GoalNotePlayer[];
  substitutions: Substitution[];
  stats: MatchStats;
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

/**
 * game page からスタメン・控えを抽出。
 * GoalNote は score-team1（KICK OFF 側）→ score-team2 の順でメンバーを列挙する。
 * team1 がホームとは限らないため、ヘッダーから team1 のチーム名を取得し、
 * homeTeam と突き合わせてホーム/アウェイを判定する。
 */
function parseLineups(html: string, homeTeam: string): { starters: GoalNotePlayer[]; subs: GoalNotePlayer[] } {
  const starters: GoalNotePlayer[] = [];
  const subs: GoalNotePlayer[] = [];

  // score-team1 のチーム名を取得して team1 がホームかを判定
  const team1Match = html.match(/class="score-team1"[^>]*>\s*([\s\S]*?)<(?:div|\/th)/i);
  const team1Name = team1Match ? strip(team1Match[1] ?? "") : "";
  const team1IsHome = team1Name.includes(homeTeam.slice(0, 4));

  const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  const tdRe = /<td[^>]*>([\s\S]*?)<\/td>/gi;
  let playerCount = 0;
  let currentSubTeam: "team1" | "team2" = "team1";

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

    playerCount++;
    const isStarter = playerCount <= 22;
    // スタメン: 1-11 = team1, 12-22 = team2
    // 控え: GK がチーム切り替わりの目印（各チームの控えは GK から始まることが多い）
    let isTeam1: boolean;
    if (isStarter) {
      isTeam1 = playerCount <= 11;
    } else {
      // 控えの23人目以降: 最初は team1 の控え、途中で team2 に切り替わる
      // team2 の控えは GK で始まるパターンを利用
      if (playerCount === 23) {
        currentSubTeam = "team1";
      }
      if (currentSubTeam === "team1" && posStr === "GK" && playerCount > 23) {
        // 2番目の GK が出たら team2 に切り替え
        currentSubTeam = "team2";
      }
      isTeam1 = currentSubTeam === "team1";
    }
    const team: "home" | "away" = (isTeam1 ? team1IsHome : !team1IsHome) ? "home" : "away";

    const player: GoalNotePlayer = {
      number: Number(numStr),
      position: posStr as Position,
      name: name.replace(/\s*\(Cap\.\)/i, ""),
      team,
    };

    if (isStarter) starters.push(player);
    else subs.push(player);
  }
  return { starters, subs };
}

/** game page から選手交代を抽出 */
function parseSubstitutions(html: string, homeTeam: string): Substitution[] {
  const subs: Substitution[] = [];
  // 交代セクション: 時間行(1セル) + 交代行(4セル: OUT#, OUT名, IN#, IN名)
  const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  const tdRe = /<td[^>]*>([\s\S]*?)<\/td>/gi;

  // 得点経過と先発メンバーの後ろに交代セクションがある
  // 「監督」行より前、「スタメン控え」の後を探す
  let currentMinute = "";
  let inHomeSubs = true;
  let homeSubCount = 0;

  // 交代行は lineups セクションの後に出現する
  // 簡易判定: 4セルで [数字, 名前, 数字, 名前] のパターン
  let tr: RegExpExecArray | null;
  let pastLineups = false;
  while ((tr = trRe.exec(html)) !== null) {
    const cells: string[] = [];
    tdRe.lastIndex = 0;
    let td: RegExpExecArray | null;
    while ((td = tdRe.exec(tr[1] ?? "")) !== null) {
      cells.push(strip(td[1] ?? ""));
    }

    // 監督行で終了
    if (cells.length >= 1 && /^監督$/.test(cells[0] ?? "")) {
      pastLineups = true;
    }

    if (!pastLineups) continue;

    // 時間行（1セル）
    if (cells.length === 1 && /\d+分|ＨＴ|HT/.test(cells[0] ?? "")) {
      currentMinute = cells[0] ?? "";
      continue;
    }

    // 交代行（4セル: OUT#, OUT名, IN#, IN名）
    if (cells.length >= 4 && /^\d+$/.test(cells[0] ?? "") && /^\d+$/.test(cells[2] ?? "")) {
      // ホーム/アウェイ判定: 最初のチームの交代がまとまって出た後にアウェイ
      subs.push({
        minute: currentMinute,
        team: inHomeSubs ? "home" : "away",
        outNumber: Number(cells[0]),
        outName: (cells[1] ?? "").replace(/\s*\(Cap\.\)/i, ""),
        inNumber: Number(cells[2]),
        inName: (cells[3] ?? "").replace(/\s*\(Cap\.\)/i, ""),
      });
      if (inHomeSubs) homeSubCount++;
    }

    // 得点経過セクションに入ったらホーム交代は終了
    if (cells.length >= 2 && /得点経過/.test(cells[0] ?? "")) {
      if (homeSubCount > 0) inHomeSubs = false;
    }
  }
  return subs;
}

/** game page から試合情報（観客数・天候・気温・ピッチ状態）を抽出 */
function parseStats(html: string): MatchStats {
  const stats: MatchStats = { attendance: null, weather: null, temperature: null, pitch: null };
  const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  const tdRe = /<td[^>]*>([\s\S]*?)<\/td>/gi;
  let tr: RegExpExecArray | null;
  while ((tr = trRe.exec(html)) !== null) {
    const cells: string[] = [];
    tdRe.lastIndex = 0;
    let td: RegExpExecArray | null;
    while ((td = tdRe.exec(tr[1] ?? "")) !== null) {
      cells.push(strip(td[1] ?? ""));
    }
    if (cells.length < 2) continue;
    const label = cells[0] ?? "";
    const value = cells[1] ?? "";
    if (/^観客$/.test(label)) stats.attendance = value;
    else if (/^天候$/.test(label)) stats.weather = value;
    else if (/^気温$/.test(label)) stats.temperature = value;
    else if (/^ピッチ状態$/.test(label)) stats.pitch = value;
  }
  return stats;
}

/** game page から試合詳細を抽出 */
export function parseGoalNoteGame(html: string, homeTeam: string): GoalNoteGameData {
  return {
    goals: parseGoals(html),
    ...parseLineups(html, homeTeam),
    substitutions: parseSubstitutions(html, homeTeam),
    stats: parseStats(html),
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
