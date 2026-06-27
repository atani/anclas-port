import type { PodcastEpisode } from "./types.js";

const SHOW_URL = "https://open.spotify.com/show/3RnkWRyIMYe9IdtMmK7KFK";
const OEMBED_URL = `https://open.spotify.com/oembed?url=${encodeURIComponent(SHOW_URL)}`;

interface OEmbedResponse {
  title: string;
  thumbnail_url: string;
  iframe_url: string;
}

export async function fetchLatestPodcast(): Promise<PodcastEpisode | null> {
  const res = await fetch(OEMBED_URL, {
    signal: AbortSignal.timeout(10_000),
    headers: { "User-Agent": "anclas-port-pipeline (+https://github.com/atani/anclas-port)" },
  });
  if (!res.ok) return null;
  const data = (await res.json()) as OEmbedResponse;
  if (!data.title) return null;
  return {
    title: data.title,
    thumbnailUrl: data.thumbnail_url,
    showUrl: SHOW_URL,
    embedUrl: data.iframe_url,
  };
}
