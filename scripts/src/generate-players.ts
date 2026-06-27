import { mkdirSync, writeFileSync } from "node:fs";
import { parsePlayer, sortPlayers } from "./lib/player-parser.js";
import type { PlayersData } from "./lib/types.js";
import { getPlayerCategory, getPlayerPosts } from "./lib/wordpress-client.js";

const DATA_DIR = new URL("../../data/", import.meta.url);

function writeJson(name: string, data: unknown): void {
  mkdirSync(DATA_DIR, { recursive: true });
  writeFileSync(new URL(name, DATA_DIR), `${JSON.stringify(data, null, 2)}\n`, "utf-8");
  console.log(`wrote ${name}`);
}

async function main(): Promise<void> {
  const category = await getPlayerCategory();
  console.log(`選手カテゴリ: id=${category.id} name=${category.name} season=${category.season}`);

  const posts = await getPlayerPosts(category.id);
  if (posts.length === 0) {
    throw new Error("選手投稿が0件でした（カテゴリ変更の可能性）");
  }

  const players = sortPlayers(posts.map(parsePlayer));

  const data: PlayersData = {
    generatedAt: new Date().toISOString(),
    season: category.season,
    players,
  };
  writeJson("players.json", data);

  const missingNumber = players.filter((p) => p.number === null).length;
  console.log(`done: ${players.length}選手 / season=${category.season} / 背番号欠損${missingNumber}`);
}

main().catch((err) => {
  console.error("[generate-players] 失敗:", err instanceof Error ? err.message : err);
  console.error("選手データは前回の生成物を維持します（anclas.jp が一時的にアクセス不可の可能性）。");
  process.exit(1);
});
