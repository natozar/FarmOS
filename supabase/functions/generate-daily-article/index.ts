// Edge Function: generate-daily-article
// Cron: runs daily at 06:00 BRT (09:00 UTC)
// Flow: fetch news → fetch cotações → generate article via Claude → fetch photo → save to Supabase

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const PEXELS_API_KEY = Deno.env.get("PEXELS_API_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ============================================================
// 1. FETCH AGRO NEWS (Google News RSS → JSON)
// ============================================================
async function fetchAgroNews(): Promise<string[]> {
  const topics = [
    "agronegócio+Brasil",
    "pecuária+boi+gordo",
    "soja+milho+safra",
    "café+commodities+Brasil",
    "agricultura+precisão+tecnologia",
  ];
  const topic = topics[Math.floor(Math.random() * topics.length)];
  const rssUrl = `https://news.google.com/rss/search?q=${topic}&hl=pt-BR&gl=BR&ceid=BR:pt-419`;

  try {
    const res = await fetch(rssUrl);
    const xml = await res.text();
    // Simple XML title extraction
    const titles: string[] = [];
    const regex = /<title><!\[CDATA\[(.*?)\]\]><\/title>/g;
    let match;
    while ((match = regex.exec(xml)) !== null && titles.length < 8) {
      if (match[1] && !match[1].includes("Google")) {
        titles.push(match[1]);
      }
    }
    // Fallback: plain title tags
    if (titles.length < 3) {
      const regex2 = /<title>(.*?)<\/title>/g;
      while ((match = regex2.exec(xml)) !== null && titles.length < 8) {
        if (match[1] && !match[1].includes("Google") && match[1].length > 20) {
          titles.push(match[1]);
        }
      }
    }
    return titles;
  } catch (e) {
    console.error("News fetch failed:", e);
    return [
      "Mercado do boi gordo segue em alta no Brasil",
      "Safra de soja 2025/26 atinge recorde",
      "Tecnologia no campo: sensoriamento remoto cresce entre produtores",
    ];
  }
}

// ============================================================
// 2. FETCH COTAÇÕES
// Schema: cotacoes (id, commodity, preco, moeda, unidade, variacao_pct, fonte, referencia, created_at)
// Row-per-commodity design
// ============================================================
interface CotacaoRow {
  commodity: string;
  preco: number;
  variacao_pct: number | null;
  unidade: string;
}

interface CotacoesMap {
  [commodity: string]: CotacaoRow;
}

async function fetchCotacoes(): Promise<CotacoesMap> {
  const cotacoes: CotacoesMap = {};

  try {
    const { data: rows } = await supabase
      .from("cotacoes")
      .select("commodity, preco, variacao_pct, unidade, fonte")
      .order("created_at", { ascending: false })
      .limit(20);

    if (rows) {
      // Get latest per commodity
      for (const row of rows) {
        if (!cotacoes[row.commodity]) {
          cotacoes[row.commodity] = row;
        }
      }
    }
  } catch (e) {
    console.error("Cotacoes fetch failed:", e);
  }

  // Dólar via BCB PTAX (update if newer)
  try {
    const hoje = new Date();
    const fmt = (d: Date) =>
      `${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}-${d.getFullYear()}`;
    const res = await fetch(
      `https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarDia(dataCotacao=@d)?@d='${fmt(hoje)}'&$format=json`
    );
    const data = await res.json();
    if (data.value?.length > 0) {
      const dolarValue = data.value[data.value.length - 1].cotacaoCompra;
      cotacoes["USD/BRL"] = {
        commodity: "USD/BRL",
        preco: dolarValue,
        variacao_pct: cotacoes["USD/BRL"]?.variacao_pct || 0,
        unidade: "BRL",
      };
    }
  } catch (e) {
    console.error("BCB fetch failed:", e);
  }

  return cotacoes;
}

// ============================================================
// 3. GENERATE ARTICLE VIA CLAUDE
// ============================================================
const CATEGORIES = ["pecuaria", "graos", "cafe", "cana", "tecnologia", "mercado"];

function pickCategory(headlines: string[]): string {
  const text = headlines.join(" ").toLowerCase();
  if (text.includes("boi") || text.includes("pecuária") || text.includes("gado")) return "pecuaria";
  if (text.includes("soja") || text.includes("milho") || text.includes("grão") || text.includes("safra")) return "graos";
  if (text.includes("café")) return "cafe";
  if (text.includes("cana") || text.includes("etanol") || text.includes("açúcar")) return "cana";
  if (text.includes("tecnologia") || text.includes("drone") || text.includes("satélite") || text.includes("precisão")) return "tecnologia";
  return "mercado";
}

function formatCotacoesForPrompt(c: CotacoesMap): string {
  const lines: string[] = [];
  for (const [name, row] of Object.entries(c)) {
    const varStr = row.variacao_pct != null
      ? ` (${row.variacao_pct >= 0 ? "+" : ""}${row.variacao_pct.toFixed(2)}%)`
      : "";
    lines.push(`${name}: R$ ${row.preco.toFixed(2)}/${row.unidade || ""}${varStr}`);
  }
  return lines.join("\n");
}

interface ArticleData {
  titulo: string;
  resumo: string;
  conteudo: string;
  tags: string[];
  slug: string;
  categoria: string;
  pexels_query: string;
}

async function generateArticle(headlines: string[], cotacoes: CotacoesMap): Promise<ArticleData> {
  const categoria = pickCategory(headlines);
  const cotacoesText = formatCotacoesForPrompt(cotacoes);
  const today = new Date().toLocaleDateString("pt-BR", {
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
  });

  const prompt = `Você é um jornalista especializado em agronegócio brasileiro. Escreva um artigo completo para o blog da AgrUAI, uma plataforma de inteligência rural por satélite.

DATA DE HOJE: ${today}

MANCHETES RECENTES DO AGRO:
${headlines.map((h, i) => `${i + 1}. ${h}`).join("\n")}

COTAÇÕES ATUALIZADAS:
${cotacoesText}

CATEGORIA DO ARTIGO: ${categoria}

REGRAS DO ARTIGO:
1. Título chamativo e SEO-friendly (máx 80 caracteres), usando keywords como "cotação", "preço", "safra", "mercado"
2. Resumo (max 200 caracteres) para preview
3. Artigo com 800-1200 palavras, dividido em seções com ## para subtítulos
4. OBRIGATÓRIO: Inclua as cotações atualizadas usando os placeholders exatos:
   - {{cotacao:boi_gordo}} para o preço do boi gordo
   - {{cotacao:soja}} para o preço da soja
   - {{cotacao:milho}} para o preço do milho
   - {{cotacao:cafe}} para o preço do café
   - {{cotacao:dolar}} para o dólar
   Use pelo menos 3 desses placeholders no corpo do texto, integrados naturalmente nas frases.
5. PLANTADO SUTIL (NÃO pode parecer propaganda): Em algum ponto do artigo, mencione naturalmente a importância da gestão à distância de propriedades rurais e como o acompanhamento por imagens de satélite tem ajudado produtores a gerar relatórios mais precisos sobre suas lavouras e pastagens. Isso deve parecer uma observação jornalística sobre uma tendência do setor, não uma propaganda. Pode mencionar que "plataformas de monitoramento por satélite, como as que utilizam dados do Sentinel-2" estão mudando a forma como proprietários de múltiplas fazendas tomam decisões.
6. Tom: profissional mas acessível, como um colunista respeitado do agro. Sem jargões acadêmicos.
7. Inclua pelo menos 1 blockquote (usando > ) com uma frase de impacto ou dado relevante.
8. Termine com uma perspectiva para os próximos dias/semanas.
9. Gere 4-6 tags relevantes para SEO.
10. Gere um query de 2-3 palavras em inglês para buscar uma foto no Pexels (ex: "cattle farm", "soybean harvest", "coffee plantation").

FORMATO DA RESPOSTA (JSON exato):
{
  "titulo": "...",
  "resumo": "...",
  "conteudo": "...",
  "tags": ["tag1", "tag2", ...],
  "pexels_query": "..."
}

Responda APENAS com o JSON, sem markdown code blocks.`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  const result = await res.json();
  const text = result.content?.[0]?.text || "";

  // Parse JSON from response
  let article: ArticleData;
  try {
    article = JSON.parse(text);
  } catch {
    // Try to extract JSON from within the text
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      article = JSON.parse(jsonMatch[0]);
    } else {
      throw new Error("Failed to parse Claude response as JSON");
    }
  }

  // Generate slug
  article.slug = article.titulo
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .substring(0, 80);

  // Add date to slug for uniqueness
  const dateStr = new Date().toISOString().split("T")[0];
  article.slug = `${article.slug}-${dateStr}`;
  article.categoria = categoria;

  return article;
}

// ============================================================
// 4. FETCH PHOTO FROM PEXELS → DOWNLOAD → UPLOAD TO SUPABASE STORAGE
// ============================================================
async function fetchPexelsPhoto(query: string, slug: string): Promise<{ url: string; credit: string }> {
  try {
    const res = await fetch(
      `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=5&orientation=landscape`,
      { headers: { Authorization: PEXELS_API_KEY } }
    );
    const data = await res.json();
    if (data.photos?.length > 0) {
      const photo = data.photos[Math.floor(Math.random() * Math.min(5, data.photos.length))];
      const pexelsUrl = photo.src.large2x || photo.src.large || photo.src.original;
      const credit = `Foto: ${photo.photographer} via Pexels (uso livre)`;

      // Download the image
      const imgRes = await fetch(pexelsUrl);
      if (!imgRes.ok) {
        console.error("[pexels] Download failed:", imgRes.status);
        return { url: pexelsUrl, credit };
      }
      const imgBuffer = await imgRes.arrayBuffer();
      const contentType = imgRes.headers.get("content-type") || "image/jpeg";
      const ext = contentType.includes("png") ? "png" : "jpg";
      const fileName = `blog/${slug}.${ext}`;

      // Upload to Supabase Storage (bucket: blog-images)
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from("blog-images")
        .upload(fileName, imgBuffer, {
          contentType,
          upsert: true,
        });

      if (uploadError) {
        console.error("[storage] Upload error:", uploadError.message);
        // Fallback to Pexels URL if upload fails
        return { url: pexelsUrl, credit };
      }

      // Get public URL
      const { data: publicUrlData } = supabase.storage
        .from("blog-images")
        .getPublicUrl(fileName);

      const permanentUrl = publicUrlData?.publicUrl || pexelsUrl;
      console.log(`[storage] Uploaded: ${permanentUrl}`);

      return { url: permanentUrl, credit };
    }
  } catch (e) {
    console.error("Pexels fetch failed:", e);
  }
  return {
    url: "",
    credit: "Foto: Pexels (uso livre)",
  };
}

// ============================================================
// 5. MAIN HANDLER
// ============================================================
Deno.serve(async (req) => {
  // Verify it's a cron call or manual trigger with auth
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.includes(SUPABASE_SERVICE_KEY) && req.method !== "POST") {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    console.log("[generate-daily-article] Starting...");

    // Step 1: Fetch news
    const headlines = await fetchAgroNews();
    console.log(`[news] Got ${headlines.length} headlines`);

    // Step 2: Fetch cotações
    const cotacoes = await fetchCotacoes();
    console.log("[cotacoes] Fetched");

    // Step 3: Generate article
    const article = await generateArticle(headlines, cotacoes);
    console.log(`[claude] Generated: ${article.titulo}`);

    // Step 4: Fetch photo → download → upload to Supabase Storage
    const photo = await fetchPexelsPhoto(article.pexels_query, article.slug);
    console.log(`[pexels] Photo: ${photo.url ? "found" : "not found"}`);

    // Step 5: Save to Supabase
    // Schema: artigos (id, titulo, slug, conteudo, resumo, categoria, tags, foto_url, foto_credito, autor, publicado, destaque, views, created_at, updated_at)
    const { data, error } = await supabase.from("artigos").insert({
      slug: article.slug,
      titulo: article.titulo,
      resumo: article.resumo,
      conteudo: article.conteudo,
      categoria: article.categoria,
      tags: article.tags,
      foto_url: photo.url,
      foto_credito: photo.credit,
      autor: "AgrUAI com Claude",
      publicado: true,
      destaque: false,
    }).select().single();

    if (error) {
      console.error("[supabase] Insert error:", error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[done] Article saved: ${data.slug}`);

    return new Response(
      JSON.stringify({
        success: true,
        article: {
          id: data.id,
          slug: data.slug,
          titulo: data.titulo,
          categoria: data.categoria,
        },
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (e) {
    console.error("[error]", e);
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
