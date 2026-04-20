// Edge Function: transcribe-audio
// Recebe storage_path de um arquivo de audio no bucket field-media,
// baixa, manda pro Groq (Whisper Large v3 Turbo, free tier) e devolve texto.
// Auth: JWT ES256 validado manualmente; usuario so pode transcrever arquivos
// na propria pasta (prefixo {user_id}/).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY")!;

const GROQ_URL = "https://api.groq.com/openai/v1/audio/transcriptions";
const GROQ_MODEL = "whisper-large-v3-turbo";
const BUCKET = "field-media";
const MAX_AUDIO_BYTES = 25 * 1024 * 1024; // 25 MB (limite padrao do Whisper)
const MAX_TRANSCRIBE_PER_DAY = 30;

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

    const body = await req.json().catch(() => ({}));
    const storagePath: string = (body.storage_path || "").toString().trim();
    const language: string = (body.language || "pt").toString().slice(0, 5);
    const logId: string | undefined = body.log_id;

    if (!storagePath) return json(400, { error: "storage_path is required" });
    if (!storagePath.startsWith(userId + "/")) {
      return json(403, { error: "path_not_owned", detail: "storage_path must start with your user_id/" });
    }

    const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Rate limit por usuario antes de gastar quota do Groq
    const { data: bumped, error: bumpErr } = await svc.rpc("bump_ai_usage", {
      p_user_id: userId,
      p_kind: "transcribe",
      p_max_per_day: MAX_TRANSCRIBE_PER_DAY,
    });
    if (bumpErr) {
      console.error("[transcribe-audio] bump_ai_usage error", bumpErr.message);
    } else if (bumped && bumped.allowed === false) {
      return json(429, {
        error: "rate_limit_exceeded",
        detail: `limite diario de ${MAX_TRANSCRIBE_PER_DAY} transcricoes atingido — tenta amanha`,
        count: bumped.count,
        max: bumped.max,
      });
    }

    const { data: fileData, error: dlErr } = await svc.storage.from(BUCKET).download(storagePath);
    if (dlErr || !fileData) {
      return json(404, { error: "download_failed", detail: dlErr?.message?.slice(0, 120) });
    }
    const size = fileData.size;
    if (size > MAX_AUDIO_BYTES) {
      return json(413, { error: "too_large", max_bytes: MAX_AUDIO_BYTES, got: size });
    }

    // Monta multipart pro Groq (mesmo contrato da OpenAI Whisper API)
    const form = new FormData();
    const ext = storagePath.split(".").pop() || "webm";
    const mime = fileData.type || "audio/webm";
    form.append("file", new File([fileData], `audio.${ext}`, { type: mime }));
    form.append("model", GROQ_MODEL);
    form.append("language", language);
    form.append("response_format", "verbose_json");
    form.append("temperature", "0");

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000);
    let groqRes: Response;
    try {
      groqRes = await fetch(GROQ_URL, {
        method: "POST",
        headers: { Authorization: `Bearer ${GROQ_API_KEY}` },
        body: form,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeoutId);
    }

    if (!groqRes.ok) {
      const errText = await groqRes.text().catch(() => "");
      console.error("[transcribe-audio] groq error", groqRes.status, errText.slice(0, 300));
      return json(502, { error: "upstream", status: groqRes.status, detail: errText.slice(0, 200) });
    }
    const data = await groqRes.json() as { text?: string; language?: string; duration?: number };
    const transcription = (data.text || "").trim();
    if (!transcription) return json(502, { error: "empty_transcription" });

    // Se log_id for passado, atualiza o field_log com a transcricao definitiva
    let logUpdated = false;
    if (logId) {
      try {
        // Verifica que o log pertence ao usuario OU ele e gestor da propriedade
        const { data: log } = await svc.from("field_logs").select("id, author_id, property_id").eq("id", logId).maybeSingle();
        if (log) {
          const isAuthor = log.author_id === userId;
          let isManager = false;
          if (!isAuthor) {
            const { data: mgr } = await svc.from("property_managers").select("id").eq("property_id", log.property_id).eq("manager_user_id", userId).maybeSingle();
            isManager = !!mgr;
          }
          if (isAuthor || isManager) {
            await svc.from("field_logs").update({ content: "🎙️ " + transcription }).eq("id", logId);
            logUpdated = true;
          }
        }
      } catch (e) {
        console.warn("[transcribe-audio] log update failed", e instanceof Error ? e.message : e);
      }
    }

    return json(200, {
      transcription,
      language: data.language,
      duration_s: data.duration,
      model: GROQ_MODEL,
      source: "groq",
      latency_ms: Date.now() - started,
      log_updated: logUpdated,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const aborted = msg.includes("abort") || msg.includes("timeout");
    console.error("[transcribe-audio] error", msg);
    return json(aborted ? 504 : 500, { error: aborted ? "timeout" : "internal", detail: msg.slice(0, 200) });
  }
});
