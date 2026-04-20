// Edge Function: invite-lead
// Admin-only (chatsagrado@gmail.com). Dado um participantes.id, chama
// auth.admin.inviteUserByEmail pro email do lead, redireciona pro painel
// e marca o lead como aprovado.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ADMIN_EMAIL = "chatsagrado@gmail.com";
const REDIRECT_URL = "https://agruai.com/painel.html";

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
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  try {
    const auth = req.headers.get("Authorization") || "";
    const userJwt = auth.replace(/^Bearer\s+/i, "");
    if (!userJwt) return json(401, { error: "missing_token" });

    // Valida quem chamou
    const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { data: userData, error: userErr } = await authClient.auth.getUser(userJwt);
    if (userErr || !userData?.user) return json(401, { error: "invalid_jwt" });
    if (userData.user.email !== ADMIN_EMAIL) return json(403, { error: "admin_only" });

    const body = await req.json().catch(() => ({}));
    const leadId: string | undefined = body.lead_id;
    const emailOverride: string | undefined = body.email;
    if (!leadId && !emailOverride) return json(400, { error: "lead_id_or_email_required" });

    const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Carrega o lead (se foi passado id)
    let targetEmail = emailOverride || "";
    let leadRow: { id: string; nome: string; email: string | null; contato: string; aprovado_at: string | null } | null = null;
    if (leadId) {
      const { data, error } = await svc
        .from("participantes")
        .select("id, nome, email, contato, aprovado_at")
        .eq("id", leadId)
        .maybeSingle();
      if (error) return json(500, { error: "db_error", detail: error.message });
      if (!data) return json(404, { error: "lead_not_found" });
      leadRow = data as typeof leadRow;
      if (!data.email && !targetEmail) return json(400, { error: "lead_sem_email", detail: "participantes.email é null e nenhum email override passado" });
      targetEmail = targetEmail || data.email!;
    }

    // Convida — envia magic link via SMTP configurado no Supabase (Resend)
    const { data: inviteData, error: inviteErr } = await svc.auth.admin.inviteUserByEmail(targetEmail, {
      redirectTo: REDIRECT_URL,
      data: leadRow ? { nome: leadRow.nome, lead_id: leadRow.id, origem: "godmode-invite" } : { origem: "godmode-invite" },
    });

    if (inviteErr) {
      // Se user ja existe, manda reset password pra ele re-entrar. Mensagem clara pra UI.
      const msg = inviteErr.message || "";
      const already = msg.includes("already") || msg.includes("registered");
      return json(already ? 409 : 500, { error: already ? "user_already_exists" : "invite_failed", detail: msg.slice(0, 200) });
    }

    // Marca o lead como aprovado
    if (leadId) {
      await svc.from("participantes")
        .update({ aprovado_at: new Date().toISOString(), aprovado_por: userData.user.id })
        .eq("id", leadId);
    }

    return json(200, {
      ok: true,
      email: targetEmail,
      invited_user_id: inviteData?.user?.id || null,
      redirect_to: REDIRECT_URL,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return json(500, { error: "internal", detail: msg.slice(0, 200) });
  }
});
