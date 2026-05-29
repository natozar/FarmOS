// AgrUAI — Stealth Mode (Vercel Routing Middleware)
// =====================================================
// Bloqueia o site inteiro com 404 ate o visitante apresentar a chave de
// desbloqueio. Intencao: preservar o produto contra "bisbilhoteiros" enquanto
// a credora nao bate o martelo.
//
// Acesso CEO/equipe (bookmark):
//   https://agruai.com/?unlock=<AGRUAI_UNLOCK_KEY>
// O middleware seta cookie HttpOnly de 30 dias e redireciona pra URL limpa.
// Visitas seguintes passam direto.
//
// Para trocar a chave: setar AGRUAI_UNLOCK_KEY como env var na Vercel.
// Sem env var, usa FALLBACK_KEY abaixo (committed; troca via env e' recomendado).
//
// Para desligar o stealth: deletar este arquivo, commit, push (Vercel redeploy).

export const config = {
  // Intercepta tudo, exceto internals da Vercel (insights/scripts).
  matcher: "/((?!_vercel).*)",
};

const FALLBACK_KEY = "ag-stealth-2026-credora-piloto-9k4j2x7Q";
const COOKIE_NAME = "agruai_unlock";

const STEALTH_HTML = `<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
<title>404 Not Found</title>
<meta name="robots" content="noindex, nofollow, noarchive, nosnippet">
<style>
  *{box-sizing:border-box}
  body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
       font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
       background:#0b0b0b;color:#666}
  .card{text-align:center}
  h1{font-size:8rem;font-weight:200;margin:0;letter-spacing:-0.05em;color:#333}
  p{margin:0.5rem 0 0;font-size:1rem;letter-spacing:0.02em}
</style>
</head><body>
<div class="card">
  <h1>404</h1>
  <p>Not Found</p>
</div>
</body></html>`;

export default async function middleware(request: Request): Promise<Response | undefined> {
  const url = new URL(request.url);
  const KEY = (typeof process !== "undefined" && process.env?.AGRUAI_UNLOCK_KEY) || FALLBACK_KEY;

  // Unlock flow: ?unlock=<KEY> seta cookie e redireciona pra URL limpa
  const unlockParam = url.searchParams.get("unlock");
  if (unlockParam && unlockParam === KEY) {
    url.searchParams.delete("unlock");
    return new Response(null, {
      status: 302,
      headers: {
        "Location": url.pathname + (url.search || "") + (url.hash || ""),
        "Set-Cookie": `${COOKIE_NAME}=${KEY}; Path=/; Max-Age=2592000; HttpOnly; Secure; SameSite=Lax`,
        "Cache-Control": "no-store",
      },
    });
  }

  // Cookie check: se desbloqueado, passa direto
  const cookieHeader = request.headers.get("cookie") ?? "";
  const isUnlocked = cookieHeader
    .split(";")
    .map((c) => c.trim())
    .some((c) => c === `${COOKIE_NAME}=${KEY}`);

  if (isUnlocked) {
    return; // passa pra proxima camada (rewrites + static)
  }

  // Caso contrario, 404 stealth
  return new Response(STEALTH_HTML, {
    status: 404,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "X-Robots-Tag": "noindex, nofollow, noarchive, nosnippet",
      "Cache-Control": "no-store, no-cache, must-revalidate",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
