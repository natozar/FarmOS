// Edge Function: lender-api
// Endpoint publico pra credoras consumirem get_lender_report.
//
// Autenticacao: header `X-Lender-Key: agruai_lk_xxxx`
//   - sha256 da chave -> lender_auth RPC -> lender_id
// Autorizacao: lender_has_access(lender_id, property_id) precisa ser true
//   - acesso e concedido pelo dono via grant_lender_access (no painel ou godmode)
// Audit: TODA chamada loga em lender_audit_log (sucesso ou falha)
//
// URL prevista:
//   GET https://{project}.supabase.co/functions/v1/lender-api/property/{uuid}
//
// Resposta: JSON do get_lender_report (vide migration 0033)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-lender-key, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function getPathSegments(url: string): string[] {
  const u = new URL(url);
  // Path esperado: /lender-api/property/{uuid}  ou  /property/{uuid}
  return u.pathname.split("/").filter(Boolean);
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function audit(opts: {
  lender_id: string | null;
  api_key_prefix: string | null;
  property_id: string | null;
  endpoint: string;
  status_code: number;
  reason: string | null;
  ip: string | null;
  user_agent: string | null;
}) {
  // Best-effort: nunca falha a request por causa de audit
  try {
    await svc.from("lender_audit_log").insert(opts);
  } catch (_) { /* swallow */ }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET")     return json(405, { error: "method_not_allowed" });

  const segments = getPathSegments(req.url);
  // Normaliza: ignora prefixo da Edge Function se vier
  const idx = segments.indexOf("property");
  const propertyId = idx >= 0 ? segments[idx + 1] : null;
  const endpoint   = `GET /property/${propertyId ?? ""}`;
  const ip         = req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip");
  const ua         = req.headers.get("user-agent");

  if (!propertyId || !UUID_RE.test(propertyId)) {
    await audit({ lender_id: null, api_key_prefix: null, property_id: null, endpoint, status_code: 400, reason: "invalid_path", ip, user_agent: ua });
    return json(400, { error: "invalid_path", expected: "/property/{uuid}" });
  }

  const rawKey = req.headers.get("x-lender-key") || "";
  if (!rawKey) {
    await audit({ lender_id: null, api_key_prefix: null, property_id: propertyId, endpoint, status_code: 401, reason: "missing_key", ip, user_agent: ua });
    return json(401, { error: "missing_key", hint: "envie header X-Lender-Key" });
  }
  const keyPrefix = rawKey.slice(0, 18);
  const keyHash   = await sha256Hex(rawKey);

  // Autenticacao
  const { data: authRows, error: authErr } = await svc.rpc("lender_auth", { p_api_key_hash: keyHash });
  if (authErr) {
    await audit({ lender_id: null, api_key_prefix: keyPrefix, property_id: propertyId, endpoint, status_code: 500, reason: `auth_rpc_error:${authErr.message}`, ip, user_agent: ua });
    return json(500, { error: "auth_failed" });
  }
  const lender = (authRows as Array<{ lender_id: string; name: string; monthly_quota: number | null; prefix: string }>)[0];
  if (!lender) {
    await audit({ lender_id: null, api_key_prefix: keyPrefix, property_id: propertyId, endpoint, status_code: 401, reason: "invalid_key", ip, user_agent: ua });
    return json(401, { error: "invalid_key" });
  }

  // Quota mensal (se setada)
  if (lender.monthly_quota != null) {
    const monthStart = new Date();
    monthStart.setUTCDate(1);
    monthStart.setUTCHours(0, 0, 0, 0);
    const { count, error: quotaErr } = await svc
      .from("lender_audit_log")
      .select("id", { count: "exact", head: true })
      .eq("lender_id", lender.lender_id)
      .eq("status_code", 200)
      .gte("called_at", monthStart.toISOString());
    if (!quotaErr && typeof count === "number" && count >= lender.monthly_quota) {
      await audit({ lender_id: lender.lender_id, api_key_prefix: keyPrefix, property_id: propertyId, endpoint, status_code: 429, reason: "monthly_quota_exceeded", ip, user_agent: ua });
      return json(429, { error: "monthly_quota_exceeded", quota: lender.monthly_quota });
    }
  }

  // Autorizacao
  const { data: hasAccess, error: accessErr } = await svc.rpc("lender_has_access", {
    p_lender_id: lender.lender_id,
    p_property_id: propertyId,
  });
  if (accessErr) {
    await audit({ lender_id: lender.lender_id, api_key_prefix: keyPrefix, property_id: propertyId, endpoint, status_code: 500, reason: `access_rpc_error:${accessErr.message}`, ip, user_agent: ua });
    return json(500, { error: "access_check_failed" });
  }
  if (!hasAccess) {
    await audit({ lender_id: lender.lender_id, api_key_prefix: keyPrefix, property_id: propertyId, endpoint, status_code: 403, reason: "no_access", ip, user_agent: ua });
    return json(403, { error: "no_access", hint: "propriedade nao foi liberada pra esta credora" });
  }

  // Relatorio
  const { data: report, error: reportErr } = await svc.rpc("get_lender_report", {
    p_property_id: propertyId,
  });
  if (reportErr) {
    await audit({ lender_id: lender.lender_id, api_key_prefix: keyPrefix, property_id: propertyId, endpoint, status_code: 500, reason: `report_rpc_error:${reportErr.message}`, ip, user_agent: ua });
    return json(500, { error: "report_failed" });
  }

  await audit({ lender_id: lender.lender_id, api_key_prefix: keyPrefix, property_id: propertyId, endpoint, status_code: 200, reason: null, ip, user_agent: ua });

  return new Response(JSON.stringify(report), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "X-Lender-Name": lender.name,
    },
  });
});
