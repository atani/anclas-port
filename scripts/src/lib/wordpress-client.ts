/**
 * anclas.jp WordPress REST API クライアント。
 * reference/anclas-mcp-server/wordpress-client.ts を流用し、
 * 選手名鑑（TOP選手紹介カテゴリ）の動的検出と _embed 取得を追加した。
 */

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
export async function findMatchPoster(opponentName: string, matchDate: string): Promise<string | null> {
  try {
    const posts = await getPosts({ search: opponentName, perPage: 10, embed: true, order: "desc" });
    const shortName = opponentName.slice(0, 4);
    // 試合日の月を含む告知投稿を優先
    const matchMonth = matchDate.slice(5, 7).replace(/^0/, "");
    for (const p of posts) {
      const title = p.title.rendered;
      if (/開催情報|試合情報|GAME/.test(title) && title.includes(shortName)) {
        const media = p._embedded?.["wp:featuredmedia"]?.[0];
        if (!media?.source_url) continue;
        // ファイル名やタイトルに試合月の日付が含まれていれば最優先
        const url = media.source_url;
        if (url.includes(matchDate.slice(5, 7) + matchDate.slice(8, 10)) || title.includes(`${matchMonth}.`)) {
          return url;
        }
      }
    }
    // 月一致が無くても、最新の告知系投稿のポスターを返す
    for (const p of posts) {
      if (/開催情報|試合情報/.test(p.title.rendered) && p.title.rendered.includes(shortName)) {
        return p._embedded?.["wp:featuredmedia"]?.[0]?.source_url ?? null;
      }
    }
  } catch {
    // WP API 失敗は無視
  }
  return null;
}
