import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.38/deno-dom-wasm.ts";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const NAVER_CLIENT_ID = Deno.env.get("NAVER_CLIENT_ID") ?? "";
const NAVER_CLIENT_SECRET = Deno.env.get("NAVER_CLIENT_SECRET") ?? "";
const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY") ?? "";
const CEREBRAS_API_KEY = Deno.env.get("CEREBRAS_API_KEY") ?? "";
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

const USER_AGENT = "KOK-Pipeline/2.0 (K-pop reaction curation; +https://kok.app)";

// ─── Artist alias normalization ───
const ARTIST_ALIASES: Record<string, string> = {
  "방탄": "BTS", "방탄소년단": "BTS", "bts": "BTS",
  "블핑": "BLACKPINK", "블랙핑크": "BLACKPINK", "blackpink": "BLACKPINK",
  "뉴진스": "NewJeans", "newjeans": "NewJeans",
  "에스파": "aespa", "aespa": "aespa",
  "르세라핌": "LE SSERAFIM", "르셒": "LE SSERAFIM", "le sserafim": "LE SSERAFIM",
  "아이브": "IVE", "ive": "IVE",
  "세븐틴": "SEVENTEEN", "seventeen": "SEVENTEEN", "세붕": "SEVENTEEN",
  "스트레이키즈": "Stray Kids", "스키즈": "Stray Kids", "stray kids": "Stray Kids",
  "라이즈": "RIIZE", "riize": "RIIZE",
  "투어스": "TWS", "tws": "TWS",
  "엔하이픈": "ENHYPEN", "enhypen": "ENHYPEN",
  "트와이스": "TWICE", "twice": "TWICE",
  "있지": "ITZY", "잇지": "ITZY", "itzy": "ITZY",
  "엔믹스": "NMIXX", "nmixx": "NMIXX",
  "아일릿": "ILLIT", "illit": "ILLIT",
  "투모로우바이투게더": "TXT", "투바투": "TXT", "txt": "TXT",
  "에이티즈": "ATEEZ", "ateez": "ATEEZ",
  "엔시티": "NCT", "nct": "NCT",
  "엑소": "EXO", "exo": "EXO",
  "보넥도": "BOYNEXTDOOR", "보이넥스트도어": "BOYNEXTDOOR",
  "베이비몬스터": "BABYMONSTER", "베몬": "BABYMONSTER",
  "트레저": "TREASURE", "treasure": "TREASURE",
  "키스오브라이프": "KISS OF LIFE",
  "제로베이스원": "ZEROBASEONE", "제베원": "ZEROBASEONE", "zb1": "ZEROBASEONE",
  "아이유": "IU", "iu": "IU",
  "지민": "Jimin", "정국": "Jung Kook", "뷔": "V", "슈가": "SUGA",
  "리사": "Lisa", "제니": "Jennie", "로제": "Rosé", "지수": "Jisoo",
  "레드벨벳": "Red Velvet", "아이들": "(G)I-DLE", "여자아이들": "(G)I-DLE",
  "케플러": "Kep1er", "이즈나": "izna",
  "캣츠아이": "KATSEYE", "하츠투하츠": "Hearts2Hearts", "미오브": "MEOVV",
  "몬스타엑스": "MONSTA X", "몬엑": "MONSTA X",
};

const AGENCY_ALIASES: Record<string, string> = {
  "하이브": "HYBE", "hybe": "HYBE",
  "에스엠": "SM", "sm": "SM", "SM엔터": "SM",
  "와이지": "YG", "yg": "YG", "YG엔터": "YG",
  "제이와이피": "JYP", "jyp": "JYP", "JYP엔터": "JYP",
  "어도어": "ADOR", "ador": "ADOR",
  "빌리프랩": "BELIFT LAB",
  "쏘스뮤직": "Source Music",
  "플레디스": "Pledis",
  "스타쉽": "Starship",
  "큐브": "Cube",
  "울림": "Woolim",
  "카카오": "Kakao Entertainment",
  "민희진": "Min Heejin",
};

// ─── Noise / PR patterns ───
const PR_PATTERNS = /팝업스토어|브랜드\s?캠페인|홍보대사|광고\s?모델|앰버서더|포토월|출국|입국|공항패션|화보\s?공개|콘셉트\s?포토|컨셉포토|트랙리스트|티저\s?공개|하이라이트\s?메들리|팬사인회|생일\s?카페|굿즈\s?출시|시즌그리팅|포토카드|챌린지\s?공개|메이킹\s?공개|비하인드\s?공개|스케줄\s?공개|단순\s?출연|인증샷|컬래버|콜라보/i;
const NOISE_PATTERNS = /컴투스|넷마블|넥슨|주가|정치|야구|축구|배구|골프|게임\s?이벤트|먹방|ASMR|언박싱|직캠|랜덤댄스|커버댄스|틱톡/i;
const LEGAL_RISK_PATTERNS = /열애설|사생활|학폭|마약|음주운전|성추행|성폭행|도박|자살|자해/i;

// ─── Utility ───

async function contentHash(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

function normalizeTitle(title: string): string {
  return title
    .replace(/<[^>]*>/g, "")
    .replace(/&[a-z]+;/gi, "")
    .replace(/[\[\]「」『』【】\(\)（）]/g, " ")
    .replace(/[!?！？…·~]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

function extractArtistTags(text: string): string[] {
  const tags: Set<string> = new Set();
  const lower = text.toLowerCase();
  for (const [alias, canonical] of Object.entries(ARTIST_ALIASES)) {
    if (lower.includes(alias.toLowerCase())) tags.add(canonical);
  }
  return [...tags];
}

function extractAgencyTags(text: string): string[] {
  const tags: Set<string> = new Set();
  const lower = text.toLowerCase();
  for (const [alias, canonical] of Object.entries(AGENCY_ALIASES)) {
    if (lower.includes(alias.toLowerCase())) tags.add(canonical);
  }
  return [...tags];
}

function calcPrScore(title: string): number {
  if (PR_PATTERNS.test(title)) return 75;
  return 10;
}

function calcNoiseScore(title: string): number {
  if (NOISE_PATTERNS.test(title)) return 80;
  return 10;
}

function calcLegalRisk(title: string): number {
  if (LEGAL_RISK_PATTERNS.test(title)) return 60;
  return 5;
}

function isHangul(ch: string): boolean {
  const code = ch.charCodeAt(0);
  return (code >= 0xAC00 && code <= 0xD7AF) || (code >= 0x3130 && code <= 0x318F);
}

function hangulRatio(text: string): number {
  if (!text) return 0;
  const chars = [...text].filter(c => c.trim());
  if (chars.length === 0) return 0;
  return chars.filter(c => isHangul(c)).length / chars.length;
}

// ─── Log pipeline run ───

async function logRun(runType: string, meta: Record<string, unknown>) {
  await sb.from("pipeline_runs").insert({
    run_type: runType,
    started_at: new Date().toISOString(),
    finished_at: new Date().toISOString(),
    status: meta.error ? "error" : "completed",
    items_collected: meta.items_collected ?? 0,
    clusters_created: meta.clusters_created ?? 0,
    clusters_rejected: meta.clusters_rejected ?? 0,
    cards_generated: meta.cards_generated ?? 0,
    error_message: meta.error ?? null,
    metadata: meta,
  });
}

// ═══════════════════════════════════
// STAGE 1: COLLECT SOURCES
// ═══════════════════════════════════

async function fetchHtml(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: { "User-Agent": USER_AGENT, "Accept-Language": "ko-KR,ko;q=0.9" },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return await res.text();
}

async function collectNatePann(): Promise<number> {
  try {
    const html = await fetchHtml("https://pann.nate.com/talk/c20028");
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!doc) return 0;

    const items: Array<Record<string, unknown>> = [];
    const posts = doc.querySelectorAll("ul.post_list li");

    for (const post of posts) {
      const titleEl = post.querySelector("h2 a");
      if (!titleEl) continue;

      const title = titleEl.textContent?.trim() ?? "";
      if (title.length < 3) continue;

      let href = titleEl.getAttribute("href") ?? "";
      if (href.startsWith("/")) href = `https://pann.nate.com${href}`;
      if (!href.startsWith("http")) continue;

      const hash = await contentHash(`pann:${title}`);
      const artists = extractArtistTags(title);
      const agencies = extractAgencyTags(title);

      const commentEl = post.querySelector("span.reple-num");
      const commentCount = parseInt(commentEl?.textContent?.replace(/[^0-9]/g, "") ?? "0");

      items.push({
        source_name: "nate_pann_enttalk",
        source_type: "community",
        url: href,
        title,
        normalized_title: normalizeTitle(title),
        raw_metrics: { comment_count: commentCount },
        content_hash: hash,
        artist_tags: artists,
        agency_tags: agencies,
        noise_flags: { pr_score: calcPrScore(title), noise_score: calcNoiseScore(title) },
      });
    }

    if (items.length === 0) return 0;
    const { error } = await sb.from("raw_source_items").upsert(items, { onConflict: "content_hash", ignoreDuplicates: true });
    if (error) console.error("[collect_pann] DB error:", error.message);
    return items.length;
  } catch (e) {
    console.error("[collect_pann]", e);
    return 0;
  }
}

async function collectTheqoo(path: string, sourceName: string): Promise<number> {
  try {
    const html = await fetchHtml(`https://theqoo.net/${path}`);
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!doc) return 0;

    const items: Array<Record<string, unknown>> = [];
    const rows = doc.querySelectorAll(".theqoo_post_list tr, .board_list tr, table.bd_lst tr, .theqoo_board_list li, li[class*='item']");

    for (const row of rows) {
      const linkEl = row.querySelector("a[href*='/']");
      const titleEl = row.querySelector(".title a, td.title a, .subject a, a.hx");
      if (!titleEl) continue;

      const title = titleEl.textContent?.trim() ?? "";
      if (title.length < 5) continue;

      let href = (titleEl as HTMLAnchorElement).getAttribute("href") ?? "";
      if (href.startsWith("/")) href = `https://theqoo.net${href}`;
      if (!href.startsWith("http")) continue;

      const hash = await contentHash(`theqoo_${path}:${title}`);
      const artists = extractArtistTags(title);
      const agencies = extractAgencyTags(title);

      const commentEl = row.querySelector(".comment_count, .replyNum, .cmt");

      items.push({
        source_name: sourceName,
        source_type: "community",
        url: href,
        title,
        normalized_title: normalizeTitle(title),
        raw_metrics: {
          comment_count: parseInt(commentEl?.textContent?.replace(/[^0-9]/g, "") ?? "0"),
        },
        content_hash: hash,
        artist_tags: artists,
        agency_tags: agencies,
        noise_flags: { pr_score: calcPrScore(title), noise_score: calcNoiseScore(title) },
      });
    }

    if (items.length === 0) return 0;
    const { error } = await sb.from("raw_source_items").upsert(items, { onConflict: "content_hash", ignoreDuplicates: true });
    if (error) console.error(`[collect_${path}] DB error:`, error.message);
    return items.length;
  } catch (e) {
    console.error(`[collect_${path}]`, e);
    return 0;
  }
}

async function collectNateEnt(): Promise<number> {
  try {
    const html = await fetchHtml("https://news.nate.com/ent/subsection?mid=e1100");
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!doc) return 0;

    const items: Array<Record<string, unknown>> = [];

    const mainArticles = doc.querySelectorAll("div.mlt01");
    for (const article of mainArticles) {
      const titleEl = article.querySelector("h2.tit");
      const linkEl = article.querySelector("a");
      if (!titleEl || !linkEl) continue;

      const title = titleEl.textContent?.trim() ?? "";
      if (title.length < 10) continue;

      let href = linkEl.getAttribute("href") ?? "";
      if (href.startsWith("//")) href = `https:${href}`;
      if (href.startsWith("/")) href = `https://news.nate.com${href}`;
      if (!href.startsWith("http")) continue;

      const mediaEl = article.querySelector("span.medium");
      const mediaName = mediaEl?.textContent?.trim() ?? "";

      const hash = await contentHash(`nate_ent:${href}`);
      const artists = extractArtistTags(title);

      items.push({
        source_name: "nate_ent",
        source_type: "news",
        url: href,
        title,
        normalized_title: normalizeTitle(title),
        raw_metrics: { media_name: mediaName },
        content_hash: hash,
        artist_tags: artists,
        agency_tags: extractAgencyTags(title),
        noise_flags: { pr_score: calcPrScore(title), noise_score: calcNoiseScore(title) },
      });
    }

    const listArticles = doc.querySelectorAll("ul.mduList1 li");
    for (const li of listArticles) {
      const linkEl = li.querySelector("h2 a");
      if (!linkEl) continue;

      const title = linkEl.textContent?.trim() ?? "";
      if (title.length < 10) continue;

      let href = linkEl.getAttribute("href") ?? "";
      if (href.startsWith("//")) href = `https:${href}`;
      if (href.startsWith("/")) href = `https://news.nate.com${href}`;
      if (!href.startsWith("http")) continue;

      const hash = await contentHash(`nate_ent:${href}`);
      const artists = extractArtistTags(title);

      items.push({
        source_name: "nate_ent",
        source_type: "news",
        url: href,
        title,
        normalized_title: normalizeTitle(title),
        content_hash: hash,
        artist_tags: artists,
        agency_tags: extractAgencyTags(title),
        noise_flags: { pr_score: calcPrScore(title), noise_score: calcNoiseScore(title) },
      });
    }

    if (items.length === 0) return 0;
    const { error } = await sb.from("raw_source_items").upsert(items, { onConflict: "content_hash", ignoreDuplicates: true });
    if (error) console.error("[collect_nate_ent] DB error:", error.message);
    return items.length;
  } catch (e) {
    console.error("[collect_nate_ent]", e);
    return 0;
  }
}

const YOUTUBE_CHANNELS: Record<string, string> = {
  "youtube_kbs_kpop": "UCwJfRJKsoksHo4RGfPCI6RA",
  "youtube_mnet": "UCbYkiSK4z8kYl7M80PU4BQg",
  "youtube_dispatch": "UCkxxFf4-_nIE5G-LFFbQ2gg",
};

async function collectYoutube(): Promise<number> {
  if (!YOUTUBE_API_KEY) return 0;
  let total = 0;

  for (const [sourceName, channelId] of Object.entries(YOUTUBE_CHANNELS)) {
    try {
      const twoWeeksAgo = new Date(Date.now() - 14 * 86400000).toISOString();
      const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${channelId}&order=date&type=video&maxResults=10&publishedAfter=${twoWeeksAgo}&key=${YOUTUBE_API_KEY}`;
      const res = await fetch(url);
      if (!res.ok) continue;
      const data = await res.json();

      for (const item of data.items ?? []) {
        const videoId = item.id?.videoId;
        if (!videoId) continue;
        const title = item.snippet?.title ?? "";
        const hash = await contentHash(`yt:${videoId}`);
        const artists = extractArtistTags(title);

        const statsRes = await fetch(`https://www.googleapis.com/youtube/v3/videos?part=statistics&id=${videoId}&key=${YOUTUBE_API_KEY}`);
        const statsData = await statsRes.json();
        const stats = statsData.items?.[0]?.statistics ?? {};

        await sb.from("raw_source_items").upsert({
          source_name: sourceName,
          source_type: "youtube",
          url: `https://www.youtube.com/watch?v=${videoId}`,
          external_id: videoId,
          title,
          normalized_title: normalizeTitle(title),
          raw_metrics: {
            view_count: parseInt(stats.viewCount ?? "0"),
            like_count: parseInt(stats.likeCount ?? "0"),
            comment_count: parseInt(stats.commentCount ?? "0"),
          },
          content_hash: hash,
          artist_tags: artists,
          agency_tags: extractAgencyTags(title),
          published_at: item.snippet?.publishedAt,
        }, { onConflict: "content_hash", ignoreDuplicates: true });
        total++;
      }
    } catch (e) {
      console.error(`[collect_youtube] ${sourceName}:`, e);
    }
  }
  return total;
}

async function collectYoutubeComments(videoId: string, clusterId: string): Promise<number> {
  if (!YOUTUBE_API_KEY) return 0;
  try {
    const url = `https://www.googleapis.com/youtube/v3/commentThreads?part=snippet&videoId=${videoId}&order=relevance&maxResults=50&textFormat=plainText&key=${YOUTUBE_API_KEY}`;
    const res = await fetch(url);
    if (!res.ok) return 0;
    const data = await res.json();
    let count = 0;

    for (const item of (data.items ?? []).slice(0, 50)) {
      const snippet = item.snippet?.topLevelComment?.snippet;
      if (!snippet) continue;
      const text = (snippet.textDisplay ?? "").slice(0, 300);
      const likes = snippet.likeCount ?? 0;

      const ratio = hangulRatio(text);
      if (ratio < 0.6) continue;
      if ([...text].filter(c => isHangul(c)).length < 15) continue;

      const hash = await contentHash(`ytc:${text.slice(0, 100)}`);

      await sb.from("raw_reaction_items").upsert({
        source_name: "youtube",
        source_type: "youtube_comment",
        source_url: `https://www.youtube.com/watch?v=${videoId}`,
        cluster_id: clusterId,
        original_text_ko: text.slice(0, 120),
        like_count: likes,
        korean_ratio: ratio,
        content_hash: hash,
      }, { onConflict: "content_hash", ignoreDuplicates: true });
      count++;
      if (count >= 20) break;
    }
    return count;
  } catch (e) {
    console.error("[collect_yt_comments]", e);
    return 0;
  }
}

// ═══════════════════════════════════
// STAGE 1.5: COLLECT REACTIONS
// ═══════════════════════════════════

async function collectReactionsForClusters(): Promise<number> {
  const { data: clusters } = await sb.from("issue_clusters")
    .select("*")
    .in("status", ["candidate", "keep", "pending_more_signals", "manual_review", "new"])
    .not("status", "eq", "published")
    .order("trend_score", { ascending: false })
    .limit(10);

  let totalReactions = 0;

  if (clusters && clusters.length > 0) {
    for (const c of clusters) {
      const sourceIds = (c.source_item_ids ?? []) as string[];
      if (sourceIds.length === 0) continue;

      const { data: sources } = await sb.from("raw_source_items")
        .select("*")
        .in("id", sourceIds);

      if (!sources) continue;

      for (const src of sources) {
        if (src.source_name === "nate_pann_enttalk") {
          totalReactions += await collectPannComments(src.url, c.id);
          await new Promise(r => setTimeout(r, 1500));
        } else if (src.source_name === "theqoo_square" || src.source_name === "theqoo_ktalk") {
          totalReactions += await collectTheqooComments(src.url, c.id);
          await new Promise(r => setTimeout(r, 1500));
        } else if (src.source_type === "youtube" && src.external_id) {
          totalReactions += await collectYoutubeComments(src.external_id, c.id);
          await new Promise(r => setTimeout(r, 500));
        }
      }
    }
  }

  totalReactions += await collectTopTheqooReactions();
  return totalReactions;
}

async function collectTopTheqooReactions(): Promise<number> {
  const since = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
  const { data: recentItems } = await sb.from("raw_source_items")
    .select("id, url, source_name, raw_metrics, collected_at")
    .in("source_name", ["theqoo_square", "theqoo_ktalk"])
    .gte("collected_at", since)
    .order("collected_at", { ascending: false })
    .limit(50);

  if (!recentItems || recentItems.length === 0) return 0;

  const topItems = recentItems
    .filter(it => {
      if (it.url.includes("/event/")) return false;
      const srl = it.url.match(/\/(\d+)$/)?.[1] ?? "";
      if (parseInt(srl) < 4000000000) return false;
      return true;
    })
    .map(it => ({
      ...it,
      commentCount: (it.raw_metrics as Record<string, number>)?.comment_count ?? 0,
    }))
    .filter(it => it.commentCount >= 3)
    .sort((a, b) => b.commentCount - a.commentCount)
    .slice(0, 10);

  if (topItems.length === 0) return 0;

  let total = 0;
  for (const item of topItems) {
    const { data: existing } = await sb.from("raw_reaction_items")
      .select("id")
      .eq("source_url", item.url)
      .limit(1);
    if (existing && existing.length > 0) continue;

    total += await collectTheqooComments(item.url, item.id);
    await new Promise(r => setTimeout(r, 2000));
  }
  return total;
}

async function collectPannComments(postUrl: string, clusterId: string): Promise<number> {
  try {
    const html = await fetchHtml(postUrl);
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!doc) return 0;

    const comments = doc.querySelectorAll("dl.cmt_item");
    let count = 0;

    for (const cmt of comments) {
      const textEl = cmt.querySelector("dd.usertxt span");
      if (!textEl) continue;

      const text = (textEl.textContent?.trim() ?? "").slice(0, 300);
      if (text.length < 10) continue;

      const ratio = hangulRatio(text);
      if (ratio < 0.4) continue;

      const likeEl = cmt.querySelector("dd.n_good");
      const likes = parseInt(likeEl?.textContent?.replace(/[^0-9]/g, "") ?? "0");

      const hash = await contentHash(`pann_cmt:${text.slice(0, 80)}`);

      await sb.from("raw_reaction_items").upsert({
        source_name: "nate_pann_enttalk",
        source_type: "community_comment",
        source_url: postUrl,
        cluster_id: clusterId,
        original_text_ko: text.slice(0, 120),
        like_count: likes,
        korean_ratio: ratio,
        is_selected: likes >= 5,
        content_hash: hash,
      }, { onConflict: "content_hash", ignoreDuplicates: true });

      count++;
      if (count >= 15) break;
    }
    return count;
  } catch (e) {
    console.error("[pann_comments]", e);
    return 0;
  }
}

async function collectTheqooComments(postUrl: string, clusterId: string): Promise<number> {
  try {
    const docMatch = postUrl.match(/\/(\d+)$/);
    if (!docMatch) return 0;
    const docSrl = docMatch[1];
    const sourceName = postUrl.includes("ktalk") ? "theqoo_ktalk" : "theqoo_square";

    const body = JSON.stringify({
      act: "dispTheqooContentCommentListTheqoo",
      document_srl: docSrl,
      cpage: 1,
    });

    let commentList: Array<{ ct?: string }> | null = null;

    for (const attempt of [1, 2]) {
      const apiHeaders: Record<string, string> = {
        "User-Agent": USER_AGENT,
        "Content-Type": "application/json; charset=utf-8",
        "X-Requested-With": "XMLHttpRequest",
        "Referer": postUrl,
      };

      if (attempt === 2) {
        const pageRes = await fetch(postUrl, {
          headers: { "User-Agent": USER_AGENT, "Accept-Language": "ko-KR,ko;q=0.9" },
        });
        if (pageRes.ok) {
          const pageHtml = await pageRes.text();
          const csrfMatch = pageHtml.match(/csrf-token"\s+content="([^"]+)"/);
          if (csrfMatch) apiHeaders["X-CSRF-Token"] = csrfMatch[1];
          const setCookie = pageRes.headers.get("set-cookie");
          if (setCookie) apiHeaders["Cookie"] = setCookie;
        }
      }

      const apiRes = await fetch("https://theqoo.net/index.php", {
        method: "POST",
        headers: apiHeaders,
        body,
      });

      if (!apiRes.ok) { console.error(`[theqoo_cmt] HTTP ${apiRes.status} for ${docSrl}`); continue; }

      let json: Record<string, unknown>;
      try {
        json = await apiRes.json() as Record<string, unknown>;
      } catch {
        continue;
      }

      if (json.error) { console.error(`[theqoo_cmt] error: ${json.message}`); continue; }

      commentList = json.comment_list as Array<{ ct?: string }>;
      if (Array.isArray(commentList) && commentList.length > 0) break;
    }

    if (!Array.isArray(commentList) || commentList.length === 0) return 0;

    const SKIP_PATTERNS = /비회원은 작성한 지|삭제된 댓글입니다|commentWarningMessage|로그인 후에|작성자에 의해 삭제/;

    let count = 0;
    for (const cmt of commentList) {
      const rawText = (cmt.ct ?? "").replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
      if (rawText.length < 5) continue;
      if (SKIP_PATTERNS.test(rawText)) continue;

      const text = rawText.slice(0, 300);
      const ratio = hangulRatio(text);
      if (ratio < 0.3) continue;

      const hash = await contentHash(`theqoo_cmt:${text.slice(0, 80)}`);

      await sb.from("raw_reaction_items").upsert({
        source_name: sourceName,
        source_type: "community_comment",
        source_url: postUrl,
        cluster_id: clusterId,
        original_text_ko: text.slice(0, 120),
        like_count: 0,
        korean_ratio: ratio,
        is_selected: true,
        content_hash: hash,
      }, { onConflict: "content_hash", ignoreDuplicates: true });

      count++;
      if (count >= 30) break;
    }
    return count;
  } catch (e) {
    console.error("[theqoo_comments]", e);
    return 0;
  }
}

// ═══════════════════════════════════
// STAGE 2: KEYWORD EXTRACTION
// ═══════════════════════════════════

async function extractKeywords(): Promise<number> {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { data: items } = await sb.from("raw_source_items")
    .select("*")
    .gte("collected_at", since)
    .order("collected_at", { ascending: false });

  if (!items || items.length === 0) return 0;

  const keywordMap: Record<string, { count: number; sources: Set<string> }> = {};

  for (const item of items) {
    const artists = (item.artist_tags ?? []) as string[];
    const agencies = (item.agency_tags ?? []) as string[];

    for (const a of artists) {
      if (!keywordMap[a]) keywordMap[a] = { count: 0, sources: new Set() };
      keywordMap[a].count++;
      keywordMap[a].sources.add(item.source_name);
    }
    for (const a of agencies) {
      if (!keywordMap[a]) keywordMap[a] = { count: 0, sources: new Set() };
      keywordMap[a].count++;
      keywordMap[a].sources.add(item.source_name);
    }
  }

  let inserted = 0;
  for (const [kw, info] of Object.entries(keywordMap)) {
    if (info.count < 2) continue;
    await sb.from("keyword_candidates").upsert({
      keyword: kw,
      normalized_keyword: kw,
      keyword_type: ARTIST_ALIASES[kw.toLowerCase()] ? "artist" : "agency",
      source_count: info.sources.size,
      source_names: [...info.sources],
      mention_count: info.count,
      last_seen_at: new Date().toISOString(),
      trend_score: Math.min(100, info.count * 10 + info.sources.size * 15),
    }, { onConflict: "normalized_keyword" });
    inserted++;
  }
  return inserted;
}

// ═══════════════════════════════════
// STAGE 3: ISSUE CLUSTERING
// ═══════════════════════════════════

async function buildClusters(): Promise<number> {
  const since = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
  const { data: items } = await sb.from("raw_source_items")
    .select("*")
    .gte("collected_at", since)
    .order("collected_at", { ascending: false });

  if (!items || items.length === 0) return 0;

  const clusters: Record<string, Array<typeof items[0]>> = {};

  for (const item of items) {
    const noiseFlags = item.noise_flags as Record<string, number> ?? {};
    if ((noiseFlags.noise_score ?? 0) >= 70) continue;
    if ((noiseFlags.pr_score ?? 0) >= 85) continue;

    const artists = (item.artist_tags ?? []) as string[];
    let groupKey: string;

    if (artists.length > 0) {
      groupKey = artists.sort().join("+");
    } else {
      const title = (item.title ?? "") as string;
      const words = title
        .replace(/[^\uAC00-\uD7AFa-zA-Z0-9\s]/g, "")
        .split(/\s+/)
        .filter((w: string) => w.length >= 2);
      if (words.length < 2) continue;
      groupKey = `_title:${words.slice(0, 3).join("+")}`;
    }

    let matched = false;
    for (const existingKey of Object.keys(clusters)) {
      const existingGroup = existingKey.split(":")[0];
      if (existingGroup === groupKey || existingGroup === groupKey.split(":")[0]) {
        clusters[existingKey].push(item);
        matched = true;
        break;
      }
    }
    if (!matched) clusters[groupKey + ":" + item.id] = [item];
  }

  let created = 0;
  for (const [key, clusterItems] of Object.entries(clusters)) {
    if (clusterItems.length < 2) continue;

    const allArtists = new Set<string>();
    const allAgencies = new Set<string>();
    const sourceTypes = new Set<string>();
    let pannCount = 0, sqCount = 0, ktCount = 0, nateCount = 0, ytCount = 0;

    for (const ci of clusterItems) {
      for (const a of (ci.artist_tags ?? []) as string[]) allArtists.add(a);
      for (const a of (ci.agency_tags ?? []) as string[]) allAgencies.add(a);
      sourceTypes.add(ci.source_name);
      if (ci.source_name === "nate_pann_enttalk") pannCount++;
      if (ci.source_name === "theqoo_square") sqCount++;
      if (ci.source_name === "theqoo_ktalk") ktCount++;
      if (ci.source_name === "nate_ent") nateCount++;
      if (ci.source_name?.startsWith("youtube")) ytCount++;
    }

    const sourceOverlap = Math.min(100, sourceTypes.size * 25);
    const clusterKey = await contentHash(`cluster:${key}:${clusterItems.length}`);
    const bestTitle = clusterItems.reduce((a, b) =>
      ((a.raw_metrics as Record<string, number>)?.comment_count ?? 0) >
      ((b.raw_metrics as Record<string, number>)?.comment_count ?? 0) ? a : b
    ).title;

    await sb.from("issue_clusters").upsert({
      cluster_key: clusterKey,
      main_title_ko: bestTitle,
      main_keywords: [...allArtists],
      related_artists: [...allArtists],
      related_agencies: [...allAgencies],
      source_item_ids: clusterItems.map(ci => ci.id),
      source_count: clusterItems.length,
      source_types: [...sourceTypes],
      pann_post_count: pannCount,
      theqoo_square_post_count: sqCount,
      theqoo_ktalk_post_count: ktCount,
      nate_article_count: nateCount,
      youtube_video_count: ytCount,
      cross_source_overlap: sourceOverlap,
      noise_score: Math.max(...clusterItems.map(ci => (ci.noise_flags as Record<string, number>)?.noise_score ?? 0)),
      pr_score: Math.max(...clusterItems.map(ci => (ci.noise_flags as Record<string, number>)?.pr_score ?? 0)),
      legal_risk_score: Math.max(...clusterItems.map(ci => calcLegalRisk(ci.title))),
      status: "new",
    }, { onConflict: "cluster_key" });
    created++;
  }
  return created;
}

// ═══════════════════════════════════
// STAGE 4: DETERMINISTIC FILTERING
// ═══════════════════════════════════

async function filterClusters(): Promise<{ kept: number; rejected: number }> {
  const { data: clusters } = await sb.from("issue_clusters")
    .select("*")
    .eq("status", "new")
    .order("source_count", { ascending: false });

  if (!clusters) return { kept: 0, rejected: 0 };

  let kept = 0, rejected = 0;

  for (const c of clusters) {
    const sourceOverlap = c.cross_source_overlap ?? 0;
    const prScore = c.pr_score ?? 0;
    const noiseScore = c.noise_score ?? 0;
    const legalRisk = c.legal_risk_score ?? 0;
    const sourceCount = c.source_count ?? 0;
    const artists = (c.related_artists ?? []) as string[];

    let status = "candidate";
    let reason = "";

    if (noiseScore >= 75) { status = "reject"; reason = "noise_score too high"; }
    else if (prScore >= 85) { status = "reject"; reason = "pr_score too high"; }
    else if (legalRisk >= 70) { status = "reject"; reason = "legal_risk too high"; }
    else if (artists.length === 0) { status = "reject"; reason = "no artist tags"; }
    else if (sourceCount < 2 && sourceOverlap < 25) { status = "pending_more_signals"; reason = "single weak source"; }
    else if (legalRisk >= 50) { status = "manual_review"; reason = "moderate legal risk"; }

    const freshness = Math.max(0, 100 - ((Date.now() - new Date(c.first_seen_at).getTime()) / 3600000) * 4);

    const trendScore =
      sourceOverlap * 0.25 +
      (c.datalab_growth_score ?? 0) * 0.15 +
      freshness * 0.10 +
      Math.min(100, sourceCount * 15) * 0.20 +
      Math.min(100, (c.pann_post_count + c.theqoo_square_post_count) * 20) * 0.20 +
      (c.naver_search_result_count ?? 0) * 2 * 0.10;

    await sb.from("issue_clusters").update({
      status,
      status_reason: reason,
      freshness,
      trend_score: Math.min(100, trendScore),
      updated_at: new Date().toISOString(),
    }).eq("id", c.id);

    if (status === "reject") rejected++;
    else kept++;
  }
  return { kept, rejected };
}

// ═══════════════════════════════════
// STAGE 5: NAVER VALIDATION
// ═══════════════════════════════════

async function validateWithNaver(): Promise<number> {
  if (!NAVER_CLIENT_ID) return 0;

  const { data: clusters } = await sb.from("issue_clusters")
    .select("*")
    .in("status", ["candidate", "pending_more_signals"])
    .order("trend_score", { ascending: false })
    .limit(30);

  if (!clusters) return 0;

  let validated = 0;
  for (const c of clusters) {
    const keywords = (c.main_keywords ?? []) as string[];
    if (keywords.length === 0) continue;

    const query = keywords.slice(0, 2).join(" ");
    try {
      const url = `https://openapi.naver.com/v1/search/news.json?query=${encodeURIComponent(query)}&display=10&sort=date`;
      const res = await fetch(url, {
        headers: {
          "X-Naver-Client-Id": NAVER_CLIENT_ID,
          "X-Naver-Client-Secret": NAVER_CLIENT_SECRET,
        },
      });
      if (!res.ok) continue;
      const data = await res.json();
      const resultCount = data.items?.length ?? 0;

      let naverScore = 0;
      if (resultCount >= 5) naverScore = 85;
      else if (resultCount >= 3) naverScore = 70;
      else if (resultCount >= 1) naverScore = 50;

      for (const item of (data.items ?? []).slice(0, 5)) {
        const hash = await contentHash(`naver:${item.link}`);
        await sb.from("raw_source_items").upsert({
          source_name: "naver_search",
          source_type: "api",
          url: item.originallink ?? item.link,
          title: (item.title ?? "").replace(/<[^>]*>/g, ""),
          normalized_title: normalizeTitle(item.title ?? ""),
          snippet: (item.description ?? "").replace(/<[^>]*>/g, "").slice(0, 200),
          content_hash: hash,
          artist_tags: extractArtistTags(item.title ?? ""),
          ttl_expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
        }, { onConflict: "content_hash", ignoreDuplicates: true });
      }

      await sb.from("issue_clusters").update({
        naver_search_result_count: resultCount,
        issue_clarity_score: naverScore,
        updated_at: new Date().toISOString(),
      }).eq("id", c.id);

      validated++;
      await new Promise(r => setTimeout(r, 500));
    } catch (e) {
      console.error("[naver_validate]", e);
    }
  }
  return validated;
}

// ═══════════════════════════════════
// STAGE 6: AI SCREENING (Cerebras)
// ═══════════════════════════════════

async function aiScreenClusters(): Promise<number> {
  const { data: budget } = await sb.rpc("check_ai_budget", { p_provider: "cerebras" });
  if (!budget) return 0;

  const { data: clusters } = await sb.from("issue_clusters")
    .select("*")
    .in("status", ["candidate", "pending_more_signals"])
    .gte("trend_score", 20)
    .order("trend_score", { ascending: false })
    .limit(30);

  if (!clusters || clusters.length === 0) return 0;

  let screened = 0;
  for (const c of clusters) {
    const prompt = `You are a Korean entertainment editor for a global K-pop fan app. Evaluate this issue cluster.

Title: ${c.main_title_ko}
Artists: ${(c.related_artists ?? []).join(", ")}
Sources: ${c.source_count} from ${(c.source_types ?? []).join(", ")}
Pann posts: ${c.pann_post_count}, TheQoo: ${c.theqoo_square_post_count}

Is this a real Korean-local K-pop issue worth showing to global fans?
Is this just promotional/generic content?

Return JSON only:
{"keep_candidate":bool,"is_kpop_relevant":bool,"is_generic_pr":bool,"noise_score":0-100,"pr_score":0-100,"issue_clarity_score":0-100,"recommended_status":"keep|manual_review|reject","reasoning_brief":"..."}`;

    try {
      const res = await fetch("https://api.cerebras.ai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${CEREBRAS_API_KEY}`,
        },
        body: JSON.stringify({
          model: "llama3.1-8b",
          messages: [{ role: "user", content: prompt }],
          max_tokens: 500,
          response_format: { type: "json_object" },
        }),
      });

      if (!res.ok) {
        console.error(`[cerebras] ${res.status}`);
        continue;
      }

      const data = await res.json();
      const content = data.choices?.[0]?.message?.content ?? "{}";
      const review = JSON.parse(content);

      await sb.from("issue_clusters").update({
        status: review.recommended_status ?? "reject",
        status_reason: review.reasoning_brief ?? "",
        noise_score: review.noise_score ?? c.noise_score,
        pr_score: review.pr_score ?? c.pr_score,
        issue_clarity_score: review.issue_clarity_score ?? c.issue_clarity_score,
        ai_review_json: { cerebras: review },
        updated_at: new Date().toISOString(),
      }).eq("id", c.id);

      await sb.rpc("increment_ai_usage", { p_provider: "cerebras", p_tokens: 600 });
      await sb.from("ai_usage_logs").insert({
        provider: "cerebras",
        model: "llama3.1-8b",
        run_type: "screen_candidate",
        cluster_id: c.id,
        input_tokens_estimated: 400,
        output_tokens_estimated: 200,
        total_tokens_estimated: 600,
        success: true,
      });

      screened++;
      await new Promise(r => setTimeout(r, 1000));
    } catch (e) {
      console.error("[cerebras_screen]", e);
    }
  }
  return screened;
}

// ═══════════════════════════════════
// STAGE 7: AI REACTION ANALYSIS (Groq)
// ═══════════════════════════════════

async function aiAnalyzeReactions(): Promise<number> {
  const { data: budget } = await sb.rpc("check_ai_budget", { p_provider: "groq" });
  if (!budget) return 0;

  const { data: clusters } = await sb.from("issue_clusters")
    .select("*")
    .in("status", ["keep", "candidate"])
    .gte("trend_score", 15)
    .order("trend_score", { ascending: false })
    .limit(20);

  if (!clusters || clusters.length === 0) return 0;

  let analyzed = 0;
  for (const c of clusters) {
    const { data: reactions } = await sb.from("raw_reaction_items")
      .select("original_text_ko, like_count, source_name")
      .eq("cluster_id", c.id)
      .order("like_count", { ascending: false })
      .limit(10);

    const reactionText = (reactions ?? [])
      .map(r => `[${r.source_name}/${r.like_count}likes] ${r.original_text_ko}`)
      .join("\n");

    const prompt = `You are analyzing Korean community reactions for a K-pop issue.

Issue: ${c.main_title_ko}
Artists: ${(c.related_artists ?? []).join(", ")}

Korean reactions:
${reactionText || "(No reactions collected yet - evaluate based on community signal strength)"}

Community signals: Pann ${c.pann_post_count} posts, TheQoo ${c.theqoo_square_post_count} posts

Evaluate reaction quality for global K-pop fans.

Return JSON only:
{"reaction_strength":0-100,"korean_context_value":0-100,"legal_risk_score":0-100,"has_meaningful_korean_reaction":bool,"main_reaction_themes":["..."],"publish_recommendation":"ready_for_generation|manual_review|reject","reasoning_brief":"..."}`;

    try {
      const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${GROQ_API_KEY}`,
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          messages: [{ role: "user", content: prompt }],
          max_tokens: 600,
          response_format: { type: "json_object" },
        }),
      });

      if (!res.ok) continue;
      const data = await res.json();
      const review = JSON.parse(data.choices?.[0]?.message?.content ?? "{}");

      const publishScore =
        (review.reaction_strength ?? 0) * 0.30 +
        (c.cross_source_overlap ?? 0) * 0.15 +
        (c.issue_clarity_score ?? 0) * 0.15 +
        (review.korean_context_value ?? 0) * 0.15 +
        (c.naver_search_result_count ?? 0) * 2 * 0.10 +
        (c.datalab_growth_score ?? 0) * 0.05 +
        (c.freshness ?? 0) * 0.05 -
        (c.pr_score ?? 0) * 0.15 -
        (c.noise_score ?? 0) * 0.15 -
        (review.legal_risk_score ?? 0) * 0.20;

      await sb.from("issue_clusters").update({
        reaction_strength: review.reaction_strength ?? 0,
        korean_context_value: review.korean_context_value ?? 0,
        legal_risk_score: review.legal_risk_score ?? c.legal_risk_score,
        publish_score: Math.max(0, Math.min(100, publishScore)),
        status: review.publish_recommendation ?? "manual_review",
        ai_review_json: { ...((c.ai_review_json as Record<string, unknown>) ?? {}), groq: review },
        updated_at: new Date().toISOString(),
      }).eq("id", c.id);

      await sb.rpc("increment_ai_usage", { p_provider: "groq", p_tokens: 800 });
      analyzed++;
      await new Promise(r => setTimeout(r, 1500));
    } catch (e) {
      console.error("[groq_analyze]", e);
    }
  }
  return analyzed;
}

// ═══════════════════════════════════
// STAGE 8: CARD GENERATION (Gemini)
// ═══════════════════════════════════

async function generateCards(): Promise<number> {
  const { data: budget } = await sb.rpc("check_ai_budget", { p_provider: "gemini" });
  if (!budget) return 0;

  const { data: clusters } = await sb.from("issue_clusters")
    .select("*")
    .in("status", ["ready_for_generation", "keep"])
    .gte("publish_score", 30)
    .lt("legal_risk_score", 70)
    .order("publish_score", { ascending: false });

  if (!clusters || clusters.length === 0) return 0;

  let generated = 0;
  for (const c of clusters) {
    const { data: sources } = await sb.from("raw_source_items")
      .select("url, title, source_name")
      .in("id", (c.source_item_ids ?? []) as string[])
      .limit(5);

    const { data: reactions } = await sb.from("raw_reaction_items")
      .select("original_text_ko, like_count, source_name")
      .eq("cluster_id", c.id)
      .eq("is_selected", true)
      .order("like_count", { ascending: false })
      .limit(10);

    const groqReview = (c.ai_review_json as Record<string, unknown>)?.groq as Record<string, unknown> ?? {};

    const sourceList = (sources ?? []).map(s => `- [${s.source_name}] ${s.title}\n  ${s.url}`).join("\n");
    const reactionList = (reactions ?? []).map(r => `- [${r.like_count} likes] ${r.original_text_ko}`).join("\n");

    const prompt = `You are the editorial writer for KOK, a K-pop reaction curation app for global fans.

Generate a KOK card in English and Spanish.

ISSUE: ${c.main_title_ko}
ARTISTS: ${(c.related_artists ?? []).join(", ")}
REACTION THEMES: ${(groqReview.main_reaction_themes as string[] ?? []).join(", ")}

SOURCES:
${sourceList || "(community sources)"}

KOREAN REACTIONS (paraphrase, do not copy):
${reactionList || "(based on community discussion volume)"}

RULES:
- Paraphrase all reactions. Never copy raw comments.
- Use safe framing: "Some Korean users felt...", "A common reaction was..."
- Never say "Koreans are angry" or "Everyone is criticizing"
- No defamation, no rumor amplification, no exaggeration
- Make it feel like polished Korean-local reaction curation
- Concise, trendy, vivid but careful tone

Return JSON only:
{
  "title_en":"...",
  "title_es":"...",
  "what_people_are_talking_about_en":"...(1-2 sentences)...",
  "what_people_are_talking_about_es":"...",
  "what_happened_en":"...(2-3 sentences, facts only)...",
  "what_happened_es":"...",
  "korean_reaction_summary_en":"...(3-5 sentences, vivid paraphrased reactions)...",
  "korean_reaction_summary_es":"...",
  "context_for_global_fans_en":"...(1-2 sentences, why this matters)...",
  "context_for_global_fans_es":"...",
  "representative_reactions_en":["paraphrased reaction 1","..."],
  "representative_reactions_es":["..."],
  "tags":["artist1","topic"],
  "issue_type":"PERFORMANCE_REACTION|COMEBACK_REACTION|STYLE_REACTION|AGENCY_ISSUE|CONTROVERSY|CONTRACT_LEGAL|PUBLIC_IMAGE|CONTENT_REACTION|OTHER",
  "reaction_tone":"supportive|critical|divided|amused|mixed",
  "risk_level":"low|medium"
}`;

    try {
      const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=${GEMINI_API_KEY}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { maxOutputTokens: 1200, temperature: 0.7 },
        }),
      });

      if (!res.ok) {
        console.error(`[gemini] ${res.status}`);
        continue;
      }

      const data = await res.json();
      let text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
      text = text.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim();
      const card = JSON.parse(text);

      const sourceLinks = (sources ?? []).map(s => ({ title: s.title, url: s.url, source: s.source_name }));

      const now = new Date().toISOString();
      const tags = card.tags ?? (c.related_artists ?? []);
      const issueType = card.issue_type ?? "OTHER";

      await sb.from("kok_cards").insert({
        cluster_id: c.id,
        title_en: card.title_en ?? "",
        title_es: card.title_es ?? "",
        what_people_are_talking_about_en: card.what_people_are_talking_about_en ?? "",
        what_people_are_talking_about_es: card.what_people_are_talking_about_es ?? "",
        what_happened_en: card.what_happened_en ?? "",
        what_happened_es: card.what_happened_es ?? "",
        korean_reaction_summary_en: card.korean_reaction_summary_en ?? "",
        korean_reaction_summary_es: card.korean_reaction_summary_es ?? "",
        context_for_global_fans_en: card.context_for_global_fans_en ?? "",
        context_for_global_fans_es: card.context_for_global_fans_es ?? "",
        representative_reactions_en: card.representative_reactions_en ?? [],
        representative_reactions_es: card.representative_reactions_es ?? [],
        source_links: sourceLinks,
        reaction_sources: [...new Set((reactions ?? []).map(r => r.source_name))],
        tags,
        issue_type: issueType,
        reaction_tone: card.reaction_tone ?? "mixed",
        risk_level: card.risk_level ?? "low",
        status: "published",
        published_at: now,
        prompt_version: "v2.0",
        model_versions: { cerebras: "llama3.1-8b", groq: "llama-3.3-70b", gemini: "gemini-2.0-flash-lite" },
      });

      const cardImageUrl = await fetchArtistImage(tags);

      const { data: articleRow } = await sb.from("articles").insert({
        issue_title_en: card.title_en ?? "",
        issue_title_es: card.title_es ?? "",
        what_happened_en: card.what_happened_en ?? "",
        what_happened_es: card.what_happened_es ?? "",
        why_it_matters_en: card.what_people_are_talking_about_en ?? "",
        why_it_matters_es: card.what_people_are_talking_about_es ?? "",
        korean_reaction_summary_en: card.korean_reaction_summary_en ?? "",
        korean_reaction_summary_es: card.korean_reaction_summary_es ?? "",
        context_for_fans_en: card.context_for_global_fans_en ?? "",
        context_for_fans_es: card.context_for_global_fans_es ?? "",
        image_url: cardImageUrl,
        issue_tags: [issueType],
        artist_tags: tags,
        sentiment: card.reaction_tone ?? "mixed",
        reaction_sample_size: (reactions ?? []).length,
        content_type: "KOK_ISSUE_CARD",
        content_tier: "heavy",
        label_en: "Issue",
        label_es: "Tema",
        confidence_level: "high",
        published_at: now,
      }).select("id").single();

      if (articleRow) {
        const reps_en = card.representative_reactions_en ?? [];
        const reps_es = card.representative_reactions_es ?? [];
        const reactionRows = reps_en.map((r: string, i: number) => ({
          article_id: articleRow.id,
          content_en: r,
          content_es: reps_es[i] ?? r,
          likes: 0,
          source: "KR community",
        }));
        if (reactionRows.length > 0) await sb.from("top_reactions").insert(reactionRows);

        const slRows = sourceLinks.map((s: Record<string, string>) => ({
          article_id: articleRow.id,
          title: s.title,
          url: s.url,
          type: "article",
        }));
        if (slRows.length > 0) await sb.from("source_links").insert(slRows);
      }

      await sb.from("issue_clusters").update({
        status: "published",
        updated_at: now,
      }).eq("id", c.id);

      await sb.rpc("increment_ai_usage", { p_provider: "gemini", p_tokens: 1500 });
      generated++;
      await new Promise(r => setTimeout(r, 2000));
    } catch (e) {
      console.error("[gemini_generate]", e);
    }
  }
  return generated;
}

// ═══════════════════════════════════════════════
// STAGE 8b: SUPPLEMENTARY CONTENT GENERATION
// ═══════════════════════════════════════════════

const SAFETY_RULES = `SAFETY RULES (mandatory):
- Paraphrase all reactions. Never copy raw comments.
- Use safe framing: "Some Korean users are noticing...", "A visible reaction is forming..."
- Never say "Koreans hate", "Koreans are furious", "Everyone is criticizing"
- No defamation, no rumor amplification, no exaggeration
- Do not state community speculation as fact`;

type SupplementaryType =
  | "STAGE_REACTION_SNACK"
  | "REACTION_SPLIT"
  | "KOREAN_COMMENT_MOOD"
  | "KOREAN_BUZZ_SNACK"
  | "NOT_A_BIG_ISSUE_BUT";

interface ClusterRow {
  id: string;
  main_title_ko: string;
  related_artists: string[] | null;
  source_url_hash: string | null;
  publish_score: number;
  legal_risk_score: number;
  noise_score: number;
  reaction_strength: number;
  status: string;
  ai_review_json: Record<string, unknown> | null;
  source_item_ids: string[] | null;
  [key: string]: unknown;
}

interface ReactionRow {
  id: string;
  original_text_ko: string;
  like_count: number | null;
  source_name: string;
  source_url: string | null;
  cluster_id: string | null;
  korean_ratio: number | null;
  [key: string]: unknown;
}

// ── Cerebras helper ──

async function callCerebras(prompt: string, maxTokens = 600): Promise<Record<string, unknown> | null> {
  try {
    const res = await fetch("https://api.cerebras.ai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${CEREBRAS_API_KEY}`,
      },
      body: JSON.stringify({
        model: "llama3.1-8b",
        messages: [{ role: "user", content: prompt }],
        max_tokens: maxTokens,
        temperature: 0.6,
      }),
    });
    if (!res.ok) {
      console.error(`[cerebras] ${res.status}`);
      return null;
    }
    const data = await res.json();
    let text = data.choices?.[0]?.message?.content ?? "";
    text = text.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim();
    return JSON.parse(text);
  } catch (e) {
    console.error("[cerebras_parse]", e);
    return null;
  }
}

// ── Content type selector ──

function selectSupplementaryType(
  cluster: ClusterRow,
  reactions: ReactionRow[],
): SupplementaryType | null {
  const sources = (cluster.source_item_ids ?? []) as string[];
  const hasYoutube = (cluster as Record<string, unknown>).source_type === "youtube" ||
    sources.some(s => s.includes("youtube"));
  const isPerformance = /무대|직캠|fancam|stage|performance|댄스|dance/i.test(cluster.main_title_ko);
  if (hasYoutube && isPerformance) return "STAGE_REACTION_SNACK";

  const themes = new Set(reactions.map(r => r.source_name));
  const sentiments = new Set(reactions.map(r => {
    const text = r.original_text_ko ?? "";
    if (/ㅋㅋ|웃|재밌|ㅎㅎ/.test(text)) return "amused";
    if (/별로|싫|짜증|화나|실망/.test(text)) return "critical";
    return "neutral";
  }));
  if (themes.size >= 2 && sentiments.size >= 2 && reactions.length >= 8) return "REACTION_SPLIT";

  const qualityReactions = reactions.filter(r => (r.original_text_ko?.length ?? 0) >= 10);
  if (qualityReactions.length >= 15) return "KOREAN_COMMENT_MOOD";
  if (qualityReactions.length >= 8) return "KOREAN_COMMENT_MOOD";

  if ((cluster.reaction_strength ?? 0) >= 45 &&
      (cluster.legal_risk_score ?? 100) < 25 &&
      (cluster.noise_score ?? 100) < 55) return "KOREAN_BUZZ_SNACK";

  if ((cluster.reaction_strength ?? 0) >= 40 &&
      (cluster.legal_risk_score ?? 100) < 20) return "NOT_A_BIG_ISSUE_BUT";

  return null;
}

// ── Individual generators ──

async function genBuzzSnack(
  cluster: ClusterRow,
  reactions: ReactionRow[],
): Promise<Record<string, unknown> | null> {
  if ((cluster.reaction_strength ?? 0) < 45) return null;
  if ((cluster.legal_risk_score ?? 0) >= 25) return null;
  if ((cluster.noise_score ?? 0) >= 55) return null;

  const reactionsText = reactions.slice(0, 8)
    .map(r => `- [${r.source_name}, ${r.like_count ?? 0} likes] "${r.original_text_ko}"`)
    .join("\n");

  const prompt = `You are a K-pop reaction curator for global fans.

TOPIC: ${cluster.main_title_ko}
ARTISTS: ${(cluster.related_artists ?? []).join(", ")}

Korean online reactions:
${reactionsText}

${SAFETY_RULES}

Create a short snack card about what Korean communities are noticing. Return JSON only:
{
  "title_en":"[catchy headline]",
  "title_es":"[same in Spanish]",
  "short_summary_en":"[2-3 sentences, what's being noticed]",
  "short_summary_es":"[same in Spanish]",
  "korean_reaction_point_en":"[the core reaction in one sentence]",
  "korean_reaction_point_es":"[same]",
  "source_hint":"[e.g. Nate Pann, TheQoo]",
  "sentiment":"supportive|critical|divided|amused|mixed",
  "artist_tags":["..."]
}`;

  return await callCerebras(prompt, 400);
}

async function genReactionSplit(
  cluster: ClusterRow,
  reactions: ReactionRow[],
): Promise<Record<string, unknown> | null> {
  if (reactions.length < 8) return null;

  const reactionsText = reactions.slice(0, 12)
    .map(r => `- [${r.source_name}, ${r.like_count ?? 0} likes] "${r.original_text_ko}"`)
    .join("\n");

  const prompt = `You are a K-pop reaction analyst for global fans.

TOPIC: ${cluster.main_title_ko}
ARTISTS: ${(cluster.related_artists ?? []).join(", ")}

Korean reactions showing divided opinions:
${reactionsText}

${SAFETY_RULES}

Identify two sides of the reaction and summarize safely. Return JSON only:
{
  "title_en":"[headline about the split]",
  "title_es":"[same in Spanish]",
  "side_a_en":"[what one side is saying, 2-3 sentences]",
  "side_a_es":"[same]",
  "side_b_en":"[what the other side is saying, 2-3 sentences]",
  "side_b_es":"[same]",
  "what_the_split_means_en":"[brief context, 1-2 sentences]",
  "what_the_split_means_es":"[same]",
  "sentiment":"divided",
  "artist_tags":["..."]
}`;

  return await callCerebras(prompt, 600);
}

async function genCommentMood(
  cluster: ClusterRow,
  reactions: ReactionRow[],
): Promise<Record<string, unknown> | null> {
  const quality = reactions.filter(r => (r.original_text_ko?.length ?? 0) >= 10);
  if (quality.length < 8) return null;

  const reactionsText = quality.slice(0, 15)
    .map(r => `- [${r.like_count ?? 0} likes] "${r.original_text_ko}"`)
    .join("\n");

  const prompt = `You are a K-pop comment mood analyst for global fans.

TOPIC: ${cluster.main_title_ko}
ARTISTS: ${(cluster.related_artists ?? []).join(", ")}

Korean comments to analyze mood:
${reactionsText}

${SAFETY_RULES}

Classify the overall mood and estimate percentages. Return JSON only:
{
  "title_en":"[mood-focused headline]",
  "title_es":"[same in Spanish]",
  "mood_distribution":{"positive":40,"amused":30,"critical":20,"curious":10},
  "main_mood":"positive|mixed|critical|curious|amused|supportive",
  "mood_summary_en":"[2-3 sentences describing the mood]",
  "mood_summary_es":"[same in Spanish]",
  "sentiment":"supportive|critical|divided|amused|mixed",
  "artist_tags":["..."]
}`;

  return await callCerebras(prompt, 500);
}

async function genStageReaction(
  cluster: ClusterRow,
  reactions: ReactionRow[],
): Promise<Record<string, unknown> | null> {
  const reactionsText = reactions.slice(0, 10)
    .map(r => `- [${r.like_count ?? 0} likes] "${r.original_text_ko}"`)
    .join("\n");

  const prompt = `You are a K-pop stage reaction curator for global fans.

TOPIC: ${cluster.main_title_ko}
ARTISTS: ${(cluster.related_artists ?? []).join(", ")}

Korean reactions to a performance/stage:
${reactionsText}

${SAFETY_RULES}

Summarize the stage reaction. Return JSON only:
{
  "title_en":"[headline about the stage reaction]",
  "title_es":"[same in Spanish]",
  "video_title":"[inferred video/performance title]",
  "performance_focus_en":"[what aspect fans are reacting to, 1-2 sentences]",
  "performance_focus_es":"[same]",
  "korean_comment_summary_en":"[paraphrased reactions, 2-3 sentences]",
  "korean_comment_summary_es":"[same]",
  "sentiment":"supportive|critical|divided|amused|mixed",
  "artist_tags":["..."]
}`;

  return await callCerebras(prompt, 400);
}

async function genSmallBuzz(
  cluster: ClusterRow,
  reactions: ReactionRow[],
): Promise<Record<string, unknown> | null> {
  if ((cluster.reaction_strength ?? 0) < 40) return null;
  if ((cluster.legal_risk_score ?? 0) >= 20) return null;

  const reactionsText = reactions.slice(0, 6)
    .map(r => `- [${r.source_name}, ${r.like_count ?? 0} likes] "${r.original_text_ko}"`)
    .join("\n");

  const prompt = `You are a K-pop micro-trend spotter for global fans.

TOPIC: ${cluster.main_title_ko}
ARTISTS: ${(cluster.related_artists ?? []).join(", ")}

Small but interesting Korean reactions:
${reactionsText}

${SAFETY_RULES}

This isn't a big issue, but it's worth noting. Return JSON only:
{
  "title_en":"[headline framed as a small observation]",
  "title_es":"[same in Spanish]",
  "observation_en":"[what's being noticed, 1-2 sentences]",
  "observation_es":"[same]",
  "why_it_is_being_noticed_en":"[why fans are talking about it, 1 sentence]",
  "why_it_is_being_noticed_es":"[same]",
  "caution_note_en":"[brief note on context, 1 sentence]",
  "caution_note_es":"[same]",
  "sentiment":"supportive|critical|divided|amused|mixed",
  "artist_tags":["..."]
}`;

  return await callCerebras(prompt, 400);
}

async function genWhyKoreansCare(): Promise<Record<string, unknown> | null> {
  const { data: existing } = await sb.from("articles")
    .select("id")
    .eq("content_type", "WHY_KOREANS_CARE")
    .gte("published_at", new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString())
    .limit(1);
  if (existing && existing.length > 0) return null;

  const { data: clusters } = await sb.from("issue_clusters")
    .select("main_title_ko, related_artists, main_keywords")
    .in("status", ["published", "candidate", "keep"])
    .order("created_at", { ascending: false })
    .limit(20);

  if (!clusters || clusters.length < 5) return null;

  const topicHints = clusters.slice(0, 10)
    .map((c: Record<string, unknown>) => `- ${c.main_title_ko} (artists: ${((c.related_artists as string[]) ?? []).join(", ")})`)
    .join("\n");

  const prompt = `You are a Korean K-pop culture explainer for global fans.

Based on these recurring Korean K-pop discussion topics:
${topicHints}

Pick ONE recurring cultural pattern and explain WHY Korean fans care about it.

${SAFETY_RULES}

Return JSON only:
{
  "title_en":"[educational title about the cultural pattern]",
  "title_es":"[same in Spanish]",
  "explanation_en":"[3-4 sentences explaining the pattern]",
  "explanation_es":"[same]",
  "why_it_matters_en":"[1-2 sentences on why it matters in Korea]",
  "why_it_matters_es":"[same]",
  "what_global_fans_might_miss_en":"[1-2 sentences]",
  "what_global_fans_might_miss_es":"[same]",
  "artist_tags":["if applicable"],
  "sentiment":"neutral"
}`;

  return await callCerebras(prompt, 600);
}

async function genKeywordPulse(): Promise<Record<string, unknown> | null> {
  const { data: keywords } = await sb.from("keyword_candidates")
    .select("*")
    .gte("created_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
    .order("score", { ascending: false })
    .limit(5);

  if (!keywords || keywords.length < 3) return null;

  const kwList = keywords.map((k: Record<string, unknown>) =>
    `- "${k.keyword}" (score: ${k.score}, sources: ${k.source_count ?? 1})`
  ).join("\n");

  const prompt = `You are a K-pop trending keyword analyst.

Today's top trending Korean K-pop keywords:
${kwList}

${SAFETY_RULES}

Create a brief keyword pulse summary. Return JSON only:
{
  "title_en":"Today's K-pop Keyword Pulse",
  "title_es":"Pulso de palabras clave K-pop de hoy",
  "keywords":[{"keyword":"...","reason_en":"why it's trending","reason_es":"same"}],
  "overall_summary_en":"[1-2 sentences overview]",
  "overall_summary_es":"[same]",
  "artist_tags":["..."]
}`;

  return await callCerebras(prompt, 500);
}

// ── Artist image lookup ──

const _imageCache: Record<string, string> = {};

async function fetchArtistImage(artists: string[]): Promise<string> {
  if (!NAVER_CLIENT_ID || artists.length === 0) return "";

  const mainArtist = artists[0];
  if (_imageCache[mainArtist]) return _imageCache[mainArtist];

  try {
    const query = `${mainArtist} 아이돌 프로필`;
    const url = `https://openapi.naver.com/v1/search/image?query=${encodeURIComponent(query)}&display=5&sort=sim&filter=large`;
    const res = await fetch(url, {
      headers: {
        "X-Naver-Client-Id": NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET,
      },
    });
    if (!res.ok) return "";
    const data = await res.json();
    const items = data.items ?? [];

    const safe = items.find((it: Record<string, string>) => {
      const link = it.link ?? "";
      return /\.(jpg|jpeg|png|webp)/i.test(link) && !/blog|cafe|tistory/i.test(link);
    }) ?? items[0];

    const imageUrl = safe?.link ?? "";
    if (imageUrl) _imageCache[mainArtist] = imageUrl;
    return imageUrl;
  } catch (e) {
    console.error("[artist_image]", e);
    return "";
  }
}

// ── Insert helper ──

async function insertSupplementaryArticle(
  contentType: string,
  labelEn: string,
  labelEs: string,
  tier: "light" | "medium",
  data: Record<string, unknown>,
  reactions: ReactionRow[],
  cluster: ClusterRow | null,
): Promise<void> {
  const now = new Date().toISOString();
  const artists = (data.artist_tags as string[]) ?? cluster?.related_artists ?? [];
  const sentiment = (data.sentiment as string) ?? "mixed";

  const bodyEn = (data.short_summary_en ?? data.mood_summary_en ?? data.observation_en ??
    data.korean_comment_summary_en ?? data.overall_summary_en ?? "") as string;
  const bodyEs = (data.short_summary_es ?? data.mood_summary_es ?? data.observation_es ??
    data.korean_comment_summary_es ?? data.overall_summary_es ?? "") as string;

  const reactionSummaryEn = (data.korean_reaction_point_en ?? data.mood_summary_en ??
    data.performance_focus_en ?? data.why_it_is_being_noticed_en ?? bodyEn) as string;
  const reactionSummaryEs = (data.korean_reaction_point_es ?? data.mood_summary_es ??
    data.performance_focus_es ?? data.why_it_is_being_noticed_es ?? bodyEs) as string;

  const imageUrl = await fetchArtistImage(artists);

  const { title_en, title_es, sentiment: _s, artist_tags: _a, ...extraFields } = data;

  const { data: articleRow } = await sb.from("articles").insert({
    issue_title_en: (title_en ?? "") as string,
    issue_title_es: (title_es ?? "") as string,
    what_happened_en: bodyEn,
    what_happened_es: bodyEs,
    why_it_matters_en: "",
    why_it_matters_es: "",
    korean_reaction_summary_en: reactionSummaryEn,
    korean_reaction_summary_es: reactionSummaryEs,
    context_for_fans_en: "",
    context_for_fans_es: "",
    image_url: imageUrl,
    issue_tags: [contentType],
    artist_tags: artists,
    sentiment,
    reaction_sample_size: reactions.length,
    content_type: contentType,
    content_tier: tier,
    label_en: labelEn,
    label_es: labelEs,
    confidence_level: tier === "light" ? "low" : "medium",
    extra_data: extraFields,
    source_url_hash: cluster?.source_url_hash ?? null,
    published_at: now,
  }).select("id").single();

  if (articleRow && reactions.length > 0) {
    const topReactions = reactions
      .sort((a, b) => (b.like_count ?? 0) - (a.like_count ?? 0))
      .slice(0, 5);

    const translated = await translateReactions(topReactions);

    const reactionRows = topReactions.map((r, i) => ({
      article_id: articleRow.id,
      content_en: translated[i]?.en ?? r.original_text_ko,
      content_es: translated[i]?.es ?? r.original_text_ko,
      likes: r.like_count ?? 0,
      source: r.source_name,
    }));
    await sb.from("top_reactions").insert(reactionRows);
  }
}

async function translateReactions(
  reactions: ReactionRow[],
): Promise<Array<{ en: string; es: string }>> {
  if (reactions.length === 0) return [];

  const koTexts = reactions.map((r, i) => `${i + 1}. "${r.original_text_ko}"`).join("\n");

  const prompt = `Translate and lightly paraphrase these Korean online comments into English and Spanish.

RULES:
- Paraphrase, do NOT translate word-for-word
- Soften profanity and slang but keep the original energy and humor
- Use natural fan community language
- Filter out slurs, hate speech, or personal attacks — rephrase them as mild observations
- Keep each translation short (1-2 sentences max)
- Frame as "A user said..." or "One comment noted..." if needed for safety

Korean comments:
${koTexts}

Return JSON array only, same order:
[{"en":"English version","es":"Spanish version"},...]`;

  const result = await callCerebras(prompt, 500);
  if (!result) return reactions.map(() => ({ en: "", es: "" }));

  if (Array.isArray(result)) return result as Array<{ en: string; es: string }>;

  return reactions.map(() => ({ en: "", es: "" }));
}

// ── Content type → generator mapping ──

const GENERATORS: Record<SupplementaryType, {
  fn: (cluster: ClusterRow, reactions: ReactionRow[]) => Promise<Record<string, unknown> | null>;
  labelEn: string;
  labelEs: string;
  tier: "light" | "medium";
  tokenCost: number;
}> = {
  KOREAN_BUZZ_SNACK: {
    fn: genBuzzSnack, labelEn: "Buzz", labelEs: "Buzz", tier: "light", tokenCost: 400,
  },
  REACTION_SPLIT: {
    fn: genReactionSplit, labelEn: "Reaction Split", labelEs: "Reacciones divididas", tier: "medium", tokenCost: 600,
  },
  KOREAN_COMMENT_MOOD: {
    fn: genCommentMood, labelEn: "Comment Mood", labelEs: "Tono de comentarios", tier: "light", tokenCost: 500,
  },
  STAGE_REACTION_SNACK: {
    fn: genStageReaction, labelEn: "Stage Reaction", labelEs: "Reacción al escenario", tier: "light", tokenCost: 400,
  },
  NOT_A_BIG_ISSUE_BUT: {
    fn: genSmallBuzz, labelEn: "Small Buzz", labelEs: "Pequeño buzz", tier: "light", tokenCost: 400,
  },
};

// ── Main orchestrator ──

async function generateSupplementary(): Promise<number> {
  const { data: budget } = await sb.rpc("check_ai_budget", { p_provider: "cerebras" });
  if (!budget) return 0;

  const { data: usedArticles } = await sb.from("articles")
    .select("source_url_hash")
    .not("source_url_hash", "is", null)
    .gte("published_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());
  const usedHashes = new Set((usedArticles ?? []).map(a => a.source_url_hash));

  const { data: clusters } = await sb.from("issue_clusters")
    .select("*")
    .in("status", ["candidate", "keep", "pending_more_signals", "manual_review"])
    .lt("legal_risk_score", 25)
    .lt("noise_score", 55)
    .order("reaction_strength", { ascending: false })
    .limit(30);

  if (!clusters || clusters.length === 0) {
    const kwResult = await genKeywordPulseArticle();
    return kwResult ? 1 : 0;
  }

  const qualifying = (clusters as ClusterRow[]).filter(c =>
    (c.publish_score ?? 0) < 30 || !["published", "ready_for_generation"].includes(c.status)
  );

  let generated = 0;
  const MAX_SUPPLEMENTARY = 8;

  for (const cluster of qualifying) {
    if (generated >= MAX_SUPPLEMENTARY) break;
    if (cluster.source_url_hash && usedHashes.has(cluster.source_url_hash)) continue;

    const { data: reactions } = await sb.from("raw_reaction_items")
      .select("*")
      .eq("cluster_id", cluster.id)
      .order("like_count", { ascending: false })
      .limit(20);

    if (!reactions || reactions.length < 3) continue;

    const contentType = selectSupplementaryType(cluster, reactions as ReactionRow[]);
    if (!contentType) continue;

    const gen = GENERATORS[contentType];

    try {
      const result = await gen.fn(cluster, reactions as ReactionRow[]);
      if (!result) continue;

      await insertSupplementaryArticle(
        contentType,
        gen.labelEn,
        gen.labelEs,
        gen.tier,
        result,
        reactions as ReactionRow[],
        cluster,
      );

      if (cluster.source_url_hash) usedHashes.add(cluster.source_url_hash);
      await sb.rpc("increment_ai_usage", { p_provider: "cerebras", p_tokens: gen.tokenCost });
      generated++;
      await new Promise(r => setTimeout(r, 1000));
    } catch (e) {
      console.error(`[supplementary_${contentType}]`, e);
    }
  }

  if (generated < MAX_SUPPLEMENTARY) {
    const kwResult = await genKeywordPulseArticle();
    if (kwResult) generated++;
  }

  if (generated < MAX_SUPPLEMENTARY) {
    const wkcResult = await genWhyKoreansCareArticle();
    if (wkcResult) generated++;
  }

  return generated;
}

async function genWhyKoreansCareArticle(): Promise<boolean> {
  const result = await genWhyKoreansCare();
  if (!result) return false;

  try {
    const bodyEn = (result.explanation_en ?? "") as string;
    const bodyEs = (result.explanation_es ?? "") as string;

    const { title_en, title_es, sentiment: _s, artist_tags: _a, ...extraFields } = result;

    await sb.from("articles").insert({
      issue_title_en: (title_en ?? "") as string,
      issue_title_es: (title_es ?? "") as string,
      what_happened_en: bodyEn,
      what_happened_es: bodyEs,
      why_it_matters_en: (result.why_it_matters_en ?? "") as string,
      why_it_matters_es: (result.why_it_matters_es ?? "") as string,
      korean_reaction_summary_en: "",
      korean_reaction_summary_es: "",
      context_for_fans_en: "",
      context_for_fans_es: "",
      issue_tags: ["WHY_KOREANS_CARE"],
      artist_tags: (result.artist_tags as string[]) ?? [],
      sentiment: "neutral",
      reaction_sample_size: 0,
      content_type: "WHY_KOREANS_CARE",
      content_tier: "evergreen",
      label_en: "Context",
      label_es: "Contexto",
      confidence_level: "high",
      extra_data: extraFields,
      published_at: new Date().toISOString(),
    });

    await sb.rpc("increment_ai_usage", { p_provider: "cerebras", p_tokens: 600 });
    return true;
  } catch (e) {
    console.error("[why_koreans_care]", e);
    return false;
  }
}

async function genKeywordPulseArticle(): Promise<boolean> {
  const { data: existing } = await sb.from("articles")
    .select("id")
    .eq("content_type", "KEYWORD_PULSE")
    .gte("published_at", new Date(Date.now() - 20 * 60 * 60 * 1000).toISOString())
    .limit(1);

  if (existing && existing.length > 0) return false;

  const result = await genKeywordPulse();
  if (!result) return false;

  try {
    await insertSupplementaryArticle(
      "KEYWORD_PULSE",
      "Keyword Pulse",
      "Pulso de palabras clave",
      "light",
      result,
      [],
      null,
    );
    await sb.rpc("increment_ai_usage", { p_provider: "cerebras", p_tokens: 500 });
    return true;
  } catch (e) {
    console.error("[keyword_pulse]", e);
    return false;
  }
}

async function generateSnacks(): Promise<number> {
  return await generateSupplementary();
}

// ═══════════════════════════════════
// MAIN HANDLER
// ═══════════════════════════════════

serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { stage } = await req.json().catch(() => ({ stage: "full" }));
    const result: Record<string, unknown> = { stage, started_at: new Date().toISOString() };

    switch (stage) {
      case "collect_pann":
        result.items = await collectNatePann();
        break;
      case "collect_theqoo_square":
        result.items = await collectTheqoo("square", "theqoo_square");
        break;
      case "collect_theqoo_ktalk":
        result.items = await collectTheqoo("ktalk", "theqoo_ktalk");
        break;
      case "collect_nate_ent":
        result.items = await collectNateEnt();
        break;
      case "collect_youtube":
        result.items = await collectYoutube();
        break;
      case "collect_reactions":
        result.reactions = await collectReactionsForClusters();
        break;
      case "extract_keywords":
        result.keywords = await extractKeywords();
        break;
      case "build_clusters":
        result.clusters = await buildClusters();
        break;
      case "filter_clusters":
        result.filter = await filterClusters();
        break;
      case "validate_naver":
        result.validated = await validateWithNaver();
        break;
      case "ai_screen":
        result.screened = await aiScreenClusters();
        break;
      case "ai_analyze":
        result.analyzed = await aiAnalyzeReactions();
        break;
      case "ai_generate":
        result.generated = await generateCards();
        break;
      case "generate_snacks":
        result.snacks_generated = await generateSnacks();
        break;
      case "generate_supplementary":
        result.supplementary_generated = await generateSupplementary();
        break;
      case "cleanup":
        await sb.rpc("cleanup_expired_data");
        result.cleaned = true;
        break;
      case "full": {
        const pannItems = await collectNatePann();
        const sqItems = await collectTheqoo("square", "theqoo_square");
        const ktItems = await collectTheqoo("ktalk", "theqoo_ktalk");
        const nateItems = await collectNateEnt();
        result.collected = { pann: pannItems, theqoo_sq: sqItems, theqoo_kt: ktItems, nate: nateItems };

        const kw = await extractKeywords();
        result.keywords = kw;

        const clusters = await buildClusters();
        result.clusters_built = clusters;

        const filter = await filterClusters();
        result.filter = filter;

        const validated = await validateWithNaver();
        result.naver_validated = validated;

        const reactions = await collectReactionsForClusters();
        result.reactions_collected = reactions;

        const screened = await aiScreenClusters();
        result.ai_screened = screened;

        const analyzed = await aiAnalyzeReactions();
        result.ai_analyzed = analyzed;

        const generated = await generateCards();
        result.cards_generated = generated;

        const snacks = await generateSnacks();
        result.snacks_generated = snacks;

        await sb.rpc("cleanup_expired_data");

        await logRun("full_pipeline", {
          items_collected: pannItems + sqItems + ktItems + nateItems,
          clusters_created: clusters,
          clusters_rejected: filter.rejected,
          cards_generated: generated,
          snacks_generated: snacks,
        });
        break;
      }
      default:
        return new Response(JSON.stringify({ error: `Unknown stage: ${stage}` }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }

    result.finished_at = new Date().toISOString();
    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("[pipeline]", msg);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
