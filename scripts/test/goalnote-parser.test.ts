import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import {
  enrichMatchesWithSchedule,
  parseGoalNoteGame,
  parseGoalNoteSchedule,
} from "../src/lib/goalnote-parser.js";

const scheduleFix = readFileSync(
  fileURLToPath(new URL("./fixtures/goalnote-schedule.html", import.meta.url)),
  "utf-8",
);
const gameFix = readFileSync(
  fileURLToPath(new URL("./fixtures/goalnote-game.html", import.meta.url)),
  "utf-8",
);

test("parseGoalNoteSchedule: 全試合行を抽出し会場が含まれる", () => {
  const rows = parseGoalNoteSchedule(scheduleFix);
  assert.ok(rows.length >= 40, `行数 ${rows.length}`);
  const anclas = rows.filter((r) => r.homeTeam.includes("アンクラス") || r.awayTeam.includes("アンクラス"));
  assert.ok(anclas.length >= 10, `アンクラス行 ${anclas.length}`);
  const withVenue = rows.filter((r) => r.venue);
  assert.ok(withVenue.length > rows.length * 0.5, "半数以上の行に会場がある");
  const withUrl = rows.filter((r) => r.gameUrl);
  assert.ok(withUrl.length > 0, "game URL がある行が存在する");
});

test("enrichMatchesWithSchedule: 日付+チーム名で会場を補完", () => {
  const rows = parseGoalNoteSchedule(scheduleFix);
  const matches = [
    { date: "2026-04-12", homeTeam: "福岡J・アンクラス", awayTeam: "ヴィアマテラス宮崎Alegrita", venue: null as string | null, goalnoteUrl: null as string | null },
  ];
  enrichMatchesWithSchedule(matches, rows);
  assert.ok(matches[0]!.venue, "会場が補完された");
  assert.ok(matches[0]!.goalnoteUrl, "game URL が補完された");
});

test("parseGoalNoteGame: 得点経過を抽出", () => {
  const data = parseGoalNoteGame(gameFix, "福岡J・アンクラス");
  assert.ok(data.goals.length >= 3, `ゴール数 ${data.goals.length}`);
  const og = data.goals.find((g) => g.playerName.includes("オウンゴール"));
  assert.ok(og, "オウンゴールが含まれる");
  assert.equal(og?.playerNumber, null);
  const kakazu = data.goals.find((g) => g.playerName.includes("嘉数"));
  assert.ok(kakazu, "嘉数 クレア姫麗のゴールが含まれる");
  assert.equal(kakazu?.playerNumber, 11);
});

test("parseGoalNoteGame: スタメン（ポジション付き）を抽出", () => {
  const data = parseGoalNoteGame(gameFix, "福岡J・アンクラス");
  assert.ok(data.starters.length >= 20, `スタメン ${data.starters.length}`);
  const homeStarters = data.starters.filter((p) => p.team === "home");
  assert.equal(homeStarters.length, 11, "ホームスタメン11人");
  const gk = homeStarters.find((p) => p.position === "GK");
  assert.ok(gk, "GK がいる");
  assert.equal(gk?.name, "釜坂 慧");
  const fw = homeStarters.filter((p) => p.position === "FW");
  assert.ok(fw.length >= 2, "FW が2人以上");
});
