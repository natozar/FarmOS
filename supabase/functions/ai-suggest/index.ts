// Edge Function: ai-suggest
// 3 acoes praticas via Gemini 2.5 Flash (free tier). Auth manual (JWT ES256).
// Contexto da propriedade: usa service role apos verificar que user e dono OU gestor.
// thinkingBudget=0 desliga o chain-of-thought do 2.5 (poupa tokens, resposta direta).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;

const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

// Rate limit: Gemini free tier e 1500 req/dia compartilhados. 30/user/dia
// deixa 50 usuarios ativos caberem com folga.
const MAX_AI_SUGGEST_PER_DAY = 30;

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface PropertyContext {
  nome?: string;
  municipio?: string;
  estado?: string;
  crop_type?: string;
  area_ha?: number;
  last_ndvi?: number | null;
  last_classification?: string | null;
  alerts?: string[];
}

async function userHasAccess(propertyId: string, userId: string, userEmail: string, svc: ReturnType<typeof createClient>): Promise<boolean> {
  try {
    const { data: owned } = await svc
      .from("properties")
      .select("id")
      .eq("id", propertyId)
      .eq("owner_id", userId)
      .maybeSingle();
    if (owned) return true;
    const { data: managed } = await svc
      .from("property_managers")
      .select("id")
      .eq("property_id", propertyId)
      .or(`manager_user_id.eq.${userId},manager_email.eq.${userEmail}`)
      .maybeSingle();
    return !!managed;
  } catch (_) {
    return false;
  }
}

async function buildPropertyContext(propertyId: string, svc: ReturnType<typeof createClient>): Promise<PropertyContext> {
  const ctx: PropertyContext = {};
  try {
    const { data: p } = await svc
      .from("properties")
      .select("nome, municipio, estado, crop_type, area_ha")
      .eq("id", propertyId)
      .maybeSingle();
    if (p) Object.assign(ctx, p);
  } catch (_) {}
  try {
    const { data: reading } = await svc
      .from("satellite_readings")
      .select("ndvi, ndvi_mean, classification, captured_at")
      .eq("property_id", propertyId)
      .order("captured_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (reading) {
      ctx.last_ndvi = reading.ndvi ?? reading.ndvi_mean ?? null;
      ctx.last_classification = reading.classification ?? null;
    }
    const { data: alerts } = await svc
      .from("alerts")
      .select("message, severity")
      .eq("property_id", propertyId)
      .eq("resolved", false)
      .order("created_at", { ascending: false })
      .limit(3);
    if (alerts && alerts.length) {
      ctx.alerts = alerts.map((a: { severity: string; message: string }) => `[${a.severity}] ${a.message}`.slice(0, 200));
    }
  } catch (_) {}
  return ctx;
}

function buildPrompt(logText: string, ctx: PropertyContext): string {
  const lines: string[] = [];
  lines.push("Voce e um assistente tecnico para produtores rurais brasileiros (agronegocio e pecuaria).");
  lines.push("O produtor escreveu uma observacao de diario de campo. Sugira 3 acoes praticas, objetivas e especificas para o contexto dele.");
  lines.push("");
  if (ctx.nome) lines.push(`FAZENDA: ${ctx.nome}${ctx.municipio ? ` (${ctx.municipio}/${ctx.estado || "--"})` : ""}`);
  if (ctx.crop_type) lines.push(`CULTURA/USO: ${ctx.crop_type}`);
  if (ctx.area_ha) lines.push(`AREA: ${Math.round(ctx.area_ha)} ha`);
  if (ctx.last_ndvi != null) lines.push(`NDVI MAIS RECENTE: ${ctx.last_ndvi.toFixed(2)}${ctx.last_classification ? ` (${ctx.last_classification})` : ""}`);
  if (ctx.alerts && ctx.alerts.length) {
    lines.push("ALERTAS ATIVOS:");
    for (const a of ctx.alerts) lines.push(`- ${a}`);
  }
  lines.push("");
  lines.push(`OBSERVACAO DO PRODUTOR: "${logText}"`);
  lines.push("");
  lines.push("REGRAS:");
  lines.push("- Exatamente 3 acoes.");
  lines.push("- Cada acao com no maximo 48 caracteres, verbo no infinitivo ou imperativo.");
  lines.push("- Portugues do Brasil, tom de tecnico de campo.");
  lines.push("- Nao repita a observacao do produtor.");
  lines.push("- NAO prescreva medicamentos veterinarios nem dose de defensivo por lei; sugira acionar o profissional habilitado quando aplicavel.");
  lines.push("");
  lines.push('RESPONDA APENAS com um JSON valido no formato: {"suggestions": ["acao 1", "acao 2", "acao 3"]}');
  return lines.join("\n");
}

function extractSuggestions(geminiJson: unknown): { suggestions: string[]; raw: string } {
  const candidates = (geminiJson as { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> }).candidates;
  const text = candidates?.[0]?.content?.parts?.[0]?.text || "";
  try {
    const parsed = JSON.parse(text);
    if (Array.isArray(parsed?.suggestions)) {
      const suggestions = parsed.suggestions
        .filter((s: unknown): s is string => typeof s === "string" && s.trim().length > 0)
        .map((s: string) => s.trim().slice(0, 80))
        .slice(0, 3);
      return { suggestions, raw: text };
    }
    if (Array.isArray(parsed)) {
      return {
        suggestions: parsed.filter((s: unknown): s is string => typeof s === "string").map((s: string) => s.trim().slice(0, 80)).slice(0, 3),
        raw: text,
      };
    }
  } catch (_) {}
  return { suggestions: [], raw: text };
}

async function callGemini(prompt: string, attempt = 1): Promise<{ ok: true; data: unknown } | { ok: false; status: number; detail: string }> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);
  try {
    const res = await fetch(GEMINI_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.4,
          maxOutputTokens: 400,
          responseMimeType: "application/json",
          thinkingConfig: { thinkingBudget: 0 },
        },
        safetySettings: [
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_ONLY_HIGH" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_ONLY_HIGH" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_ONLY_HIGH" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_ONLY_HIGH" },
        ],
      }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      // 503 retry uma vez apos 800ms (modelo sobrecarregado)
      if (res.status === 503 && attempt === 1) {
        await new Promise((r) => setTimeout(r, 800));
        return callGemini(prompt, 2);
      }
      return { ok: false, status: res.status, detail: detail.slice(0, 200) };
    }
    const data = await res.json();
    return { ok: true, data };
  } finally {
    clearTimeout(timeoutId);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const started = Date.now();
  try {
    const auth = req.headers.get("Authorization") || "";
    const userJwt = auth.replace(/^Bearer\s+/i, "");
    if (!userJwt) return json(401, { error: "Missing Authorization bearer token" });

    const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { data: userData, error: userErr } = await authClient.auth.getUser(userJwt);
    if (userErr || !userData?.user) {
      return json(401, { error: "invalid_jwt", detail: userErr?.message?.slice(0, 120) });
    }
    const userId = userData.user.id;
    const userEmail = userData.user.email || "";

    const body = await req.json().catch(() => ({}));
    const logText: string = (body.log_text || "").toString().trim();
    const propertyId: string | undefined = body.property_id;
    if (!logText) return json(400, { error: "log_text is required" });
    if (logText.length > 2000) return json(400, { error: "log_text too long (max 2000 chars)" });

    const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Rate limit em camadas: feature_flag + burst(60s) + daily-user + daily-global.
    const { data: bumped, error: bumpErr } = await svc.rpc("bump_ai_usage", {
      p_user_id: userId,
      p_kind: "ai_suggest",
      p_max_per_day: MAX_AI_SUGGEST_PER_DAY,
    });
    if (bumpErr) {
      console.error("[ai-suggest] bump_ai_usage error", bumpErr.message);
    } else if (bumped && bumped.allowed === false) {
      const reason = (bumped.reason as string) || "rate_limit_exceeded";
      const detail =
        reason === "feature_disabled" ? "sugestoes de IA estao temporariamente desativadas" :
        reason === "burst" ? "muitas chamadas em poucos segundos — espera um pouco" :
        reason === "global_ceiling" ? "sistema atingiu o teto diario global — tenta amanha" :
        reason === "daily_user" ? `voce atingiu ${MAX_AI_SUGGEST_PER_DAY} sugestoes hoje — tenta amanha` :
        "limite atingido";
      return json(429, { error: reason, detail, ...bumped });
    }

    let ctx: PropertyContext = {};
    if (propertyId) {
      const allowed = await userHasAccess(propertyId, userId, userEmail, svc);
      if (allowed) ctx = await buildPropertyContext(propertyId, svc);
    }
    const prompt = buildPrompt(logText, ctx);

    const result = await callGemini(prompt);
    if (!result.ok) {
      console.error("[ai-suggest] gemini", result.status, result.detail);
      return json(502, { error: "upstream", status: result.status, detail: result.detail });
    }
    const { suggestions, raw } = extractSuggestions(result.data);
    if (suggestions.length === 0) {
      return json(502, { error: "empty", raw: raw.slice(0, 400) });
    }
    return json(200, {
      suggestions,
      source: GEMINI_MODEL,
      latency_ms: Date.now() - started,
      context_used: Object.keys(ctx).length > 0,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const aborted = msg.includes("abort") || msg.includes("timeout");
    console.error("[ai-suggest] error", msg);
    return json(aborted ? 504 : 500, { error: aborted ? "timeout" : "internal", detail: msg.slice(0, 200) });
  }
});
