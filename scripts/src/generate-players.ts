import { mkdirSync, writeFileSync } from "node:fs";
import { logger } from "./lib/logger.js";
import { parsePlayer, sortPlayers } from "./lib/player-parser.js";
import type { PlayersData } from "./lib/types.js";
import { fetchPlayerBlogPosts, getPlayerCategory, getPlayerPosts } from "./lib/wordpress-client.js";

const DATA_DIR = new URL("../../data/", import.meta.url);

function writeJson(name: string, data: unknown): void {
  mkdirSync(DATA_DIR, { recursive: true });
  writeFileSync(new URL(name, DATA_DIR), `${JSON.stringify(data, null, 2)}\n`, "utf-8");
  logger.info(`wrote ${name}`);
}

async function main(): Promise<void> {
  const category = await getPlayerCategory();
  logger.info(`選手カテゴリ: id=${category.id} name=${category.name} season=${category.season}`);

  const posts = await getPlayerPosts(category.id);
  if (posts.length === 0) {
    throw new Error("選手投稿が0件でした（カテゴリ変更の可能性）");
  }

  const players = sortPlayers(posts.map(parsePlayer));

  const blogEntries = await fetchPlayerBlogPosts();
  const norm = (s: string) => s.replace(/[\s　]/g, "");
  let blogCount = 0;
  for (const p of players) {
    // 背番号一致 + 名前照合（背番号変更対策: 名前が含まれない場合は番号のみ）
    const matched = blogEntries.filter((e) => {
      if (e.number !== p.number) return false;
      if (e.name && p.nameJa) {
        return norm(e.name) === norm(p.nameJa) || norm(p.nameJa).includes(norm(e.name)) || norm(e.name).includes(norm(p.nameJa));
      }
      return true;
    });
    if (matched.length > 0) {
      p.blogPosts = matched.map((e) => e.post);
      blogCount += p.blogPosts.length;
    }
  }
  const playersWithBlog = players.filter((p) => p.blogPosts.length > 0).length;
  logger.info(`ブログ: ${blogCount}記事を${playersWithBlog}選手に紐付け`);

  const data: PlayersData = {
    generatedAt: new Date().toISOString(),
    season: category.season,
    players,
  };
  writeJson("players.json", data);

  const missingNumber = players.filter((p) => p.number === null).length;
  logger.info(`done: ${players.length}選手 / season=${category.season} / 背番号欠損${missingNumber}`);
}

main().catch((err) => {
  logger.error(`失敗: ${err instanceof Error ? err.message : err}`);
  logger.warn("選手データは前回の生成物を維持します（anclas.jp が一時的にアクセス不可の可能性）");
  process.exit(1);
});
