/**
 * anclas.jp WordPress REST API クライアント。
 * reference/anclas-mcp-server/wordpress-client.ts を流用し、
 * 選手名鑑（TOP選手紹介カテゴリ）の動的検出と _embed 取得を追加した。
 */

import type { MatchReport } from "./types.js";

const BASE_URL = "https://anclas.jp/wp-json/wp/v2";

export interface WPMediaSize {
  source_url: string;
  width: number;
  height: number;
}

export interface WPMedia {
  source_url: string;
  media_details?: {
    sizes?: Record<string, WPMediaSize>;
  };
}

export interface WPPost {
  id: number;
  date: string;
  title: { rendered: string };
  content: { rendered: string };
  excerpt: { rendered: string };
  link: string;
  categories: number[];
  tags: number[];
  featured_media: number;
  _embedded?: {
    "wp:featuredmedia"?: WPMedia[];
  };
}

export interface WPCategory {
  id: number;
  name: string;
  slug: string;
  count: number;
}

const ALLOWED_PATHS = ["/posts", "/categories", "/tags"] as const;

async function wpFetch<T>(path: string, params: Record<string, string> = {}): Promise<T> {
  if (!ALLOWED_PATHS.some((p) => path === p)) {
    throw new Error(`Invalid API path: ${path}`);
  }
  const url = new URL(`${BASE_URL}${path}`);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }
  const res = await fetch(url.toString(), { signal: AbortSignal.timeout(15_000) });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`WordPress API error: ${res.status} ${res.statusText} - ${body}`);
  }
  return res.json() as Promise<T>;
}

export async function getPosts(params: {
  categories?: number[];
  tags?: number[];
  search?: string;
  perPage?: number;
  page?: number;
  orderby?: string;
  order?: "asc" | "desc";
  embed?: boolean;
} = {}): Promise<WPPost[]> {
  const query: Record<string, string> = {
    per_page: String(params.perPage ?? 10),
    page: String(params.page ?? 1),
    orderby: params.orderby ?? "date",
    order: params.order ?? "desc",
  };
  if (params.categories?.length) query.categories = params.categories.join(",");
  if (params.tags?.length) query.tags = params.tags.join(",");
  if (params.search) query.search = params.search;
  if (params.embed) query._embed = "1";
  return wpFetch<WPPost[]>("/posts", query);
}

export async function getCategories(): Promise<WPCategory[]> {
  return wpFetch<WPCategory[]>("/categories", { per_page: "100" });
}

/** カテゴリ名から年を抽出: "TOP選手紹介2026" → 2026 */
function extractYear(name: string): number | null {
  const m = name.match(/(\d{4})/);
  return m && m[1] ? Number(m[1]) : null;
}

/**
 * 選手名鑑（TOP選手紹介）カテゴリを動的に検出する。
 * 年度でカテゴリが変わるため（slug は top-players2025 でも name は TOP選手紹介2026 など
 * ずれがある）、name の年を信頼して count>0 の最新年カテゴリを返す。
 */
export async function getPlayerCategory(): Promise<{ id: number; name: string; season: string }> {
  const cats = await getCategories();
  const candidates = cats
    .filter((c) => /TOP選手紹介|top-?players/i.test(`${c.name} ${c.slug}`) && c.count > 0)
    .map((c) => ({ cat: c, year: extractYear(c.name) }))
    .filter((x): x is { cat: WPCategory; year: number } => x.year !== null)
    .sort((a, b) => b.year - a.year);

  const top = candidates[0];
  if (!top) {
    throw new Error("選手名鑑カテゴリ（TOP選手紹介）が見つかりませんでした");
  }
  return { id: top.cat.id, name: top.cat.name, season: String(top.year) };
}

/** 指定カテゴリの全選手投稿を _embed 付きで取得する（背番号順は呼び出し側で整列） */
export async function getPlayerPosts(categoryId: number): Promise<WPPost[]> {
  return getPosts({ categories: [categoryId], perPage: 100, embed: true, orderby: "date", order: "asc" });
}

/**
 * 「開催情報」投稿から試合告知ポスター画像URLを取得する。
 * タイトルに対戦相手名を含む最新投稿の featured_media を返す。
 */
/**
 * 次節の告知ポスターを探す。
 * 投稿日が試合日の30日前以内の「開催情報」投稿のみを対象にする。
 * 古い試合の告知ポスターを誤って返さないための日付ガード。
 */
export async function findMatchPoster(opponentName: string, matchDate: string): Promise<string | null> {
  try {
    const posts = await getPosts({ search: opponentName, perPage: 10, embed: true, order: "desc" });
    const shortName = opponentName.slice(0, 4);
    const matchMs = new Date(matchDate).getTime();
    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

    for (const p of posts) {
      const title = p.title.rendered;
      if (!/開催情報|試合情報/.test(title) || !title.includes(shortName)) continue;
      const postMs = new Date(p.date).getTime();
      if (postMs < matchMs - thirtyDaysMs || postMs > matchMs) continue;
      const media = p._embedded?.["wp:featuredmedia"]?.[0];
      if (media?.source_url) return media.source_url;
    }
  } catch {
    // WP API 失敗は無視
  }
  return null;
}

/** HTMLをプレーンテキストに変換 */
function htmlToPlainText(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n\n")
    .replace(/<\/?(div|li|tr|h[1-6])[^>]*>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** マッチレポート本文からコメントを抽出 */
function parseMatchReportContent(html: string, postUrl: string): MatchReport {
  const text = htmlToPlainText(html);

  // 記事冒頭は INDEX（目次リンク）と試合メタ情報。「公式記録」以降を本文領域とし、
  // 目次内の「マッチレポート」「#N…コメント」を誤って拾わないようにする。
  const officialIdx = text.indexOf("公式記録");
  const afterOfficial = officialIdx >= 0 ? text.slice(officialIdx) : text;

  // 本文の「マッチレポート」見出し以降（公式記録の登録メンバー・得点/交代は除外）
  const repStart = afterOfficial.search(/(?:^|\n)\s*マッチレポート\s*\n/);
  let reportText = repStart >= 0 ? afterOfficial.slice(repStart) : afterOfficial;

  // 終端「フォトギャラリー」以降を切り捨てる
  reportText = reportText.split(/\n\s*フォトギャラリー/)[0] ?? reportText;

  // コメントセクションを分割: 「監督 XXX コメント」「#N選手名 コメント」
  const commentPattern = /(?:監督\s+.+?\s*コメント|#\d+\s*.+?\s*コメント)/g;
  const commentHeaders: { index: number; header: string }[] = [];
  let m: RegExpExecArray | null;
  while ((m = commentPattern.exec(reportText)) !== null) {
    commentHeaders.push({ index: m.index, header: m[0] });
  }

  // レポート本文: マッチレポート見出しから最初のコメントまで
  const summaryEnd = commentHeaders.length > 0 ? commentHeaders[0]!.index : reportText.length;
  const summaryRaw = reportText.slice(0, summaryEnd);
  const summary = summaryRaw
    .replace(/^\s*マッチレポート\s*\n/, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();

  // 監督コメント
  let coachComment: MatchReport["coachComment"] = null;
  const playerComments: MatchReport["playerComments"] = [];

  for (let i = 0; i < commentHeaders.length; i++) {
    const header = commentHeaders[i]!;
    const start = header.index + header.header.length;
    const end = i + 1 < commentHeaders.length ? commentHeaders[i + 1]!.index : reportText.length;
    const body = reportText.slice(start, end).trim();

    const coachMatch = header.header.match(/監督\s+(.+?)\s*コメント/);
    if (coachMatch) {
      coachComment = { name: coachMatch[1]!.trim(), comment: body };
      continue;
    }

    const playerMatch = header.header.match(/#(\d+)\s*(.+?)\s*コメント/);
    if (playerMatch) {
      playerComments.push({
        name: playerMatch[2]!.trim(),
        number: Number(playerMatch[1]),
        comment: body,
      });
    }
  }

  return { summary, coachComment, playerComments, sourceUrl: postUrl };
}

/**
 * マッチレポート投稿を探してコメントを抽出する。
 * 投稿日が試合日の前後7日以内の「マッチレポート」投稿を対象にする。
 */
export async function findMatchReport(opponentName: string, matchDate: string): Promise<MatchReport | null> {
  try {
    const posts = await getPosts({ search: "マッチレポート " + opponentName.slice(0, 6), perPage: 5, order: "desc" });
    const matchMs = new Date(matchDate).getTime();
    const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;

    for (const p of posts) {
      const title = p.title.rendered;
      if (!/マッチレポート/.test(title)) continue;
      const postMs = new Date(p.date).getTime();
      if (Math.abs(postMs - matchMs) > sevenDaysMs) continue;
      return parseMatchReportContent(p.content.rendered, p.link);
    }
  } catch {
    // WP API 失敗は無視
  }
  return null;
}
