import type { YouTubeVideo } from "./types.js";

const CHANNEL_ID = "UC1LJO-W5Q3q-HfcS4UM3GPQ";
const FEED_URL = `https://www.youtube.com/feeds/videos.xml?channel_id=${CHANNEL_ID}`;

/** YouTube チャンネルRSSから最新動画1件を取得（認証不要） */
export async function fetchLatestYouTubeVideo(): Promise<YouTubeVideo | null> {
  try {
    const res = await fetch(FEED_URL, {
      signal: AbortSignal.timeout(10_000),
      headers: { "User-Agent": "Mozilla/5.0 (compatible; anclas-port-pipeline)" },
    });
    if (!res.ok) return null;
    const xml = await res.text();
    // 最初の <entry> ブロックから videoId / title / published / thumbnail を抽出
    const entry = xml.match(/<entry>([\s\S]*?)<\/entry>/);
    if (!entry) return null;
    const block = entry[1] ?? "";
    const videoId = block.match(/<yt:videoId>([^<]+)<\/yt:videoId>/)?.[1];
    const title = block.match(/<title>([^<]+)<\/title>/)?.[1];
    const published = block.match(/<published>([^<]+)<\/published>/)?.[1];
    const thumb = block.match(/<media:thumbnail\s+url="([^"]+)"/)?.[1];
    if (!videoId || !title || !published) return null;
    return {
      videoId,
      title,
      thumbnailUrl: thumb ?? `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
      url: `https://www.youtube.com/watch?v=${videoId}`,
      publishedAt: published,
    };
  } catch {
    return null;
  }
}
