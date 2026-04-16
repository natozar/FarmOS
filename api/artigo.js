// Vercel Serverless Function: /api/artigo?slug=xxx
// Returns full article HTML with OG meta tags pre-rendered for social media crawlers
// WhatsApp, Facebook, Twitter, LinkedIn all read OG tags from raw HTML (no JS execution)

const SUPA_URL = 'https://kyvbnntoxslrtrsiejzc.supabase.co';
const SUPA_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5dmJubnRveHNscnRyc2llanpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NjQ1NDcsImV4cCI6MjA5MTQ0MDU0N30.Dx-9SKxWfAoxXg3gzx3NpzJD1taZgkQCCjwDXlY9J6I';

function escHtml(s) {
  return String(s || '')
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

module.exports = async (req, res) => {
  const slug = req.query.slug;
  if (!slug) {
    res.writeHead(302, { Location: '/blog.html' });
    return res.end();
  }

  // Fetch article from Supabase
  let article = null;
  try {
    const r = await fetch(
      `${SUPA_URL}/rest/v1/artigos?slug=eq.${encodeURIComponent(slug)}&publicado=eq.true&limit=1`,
      { headers: { apikey: SUPA_KEY, Authorization: `Bearer ${SUPA_KEY}` } }
    );
    const rows = await r.json();
    if (rows && rows.length > 0) article = rows[0];
  } catch (e) {
    console.error('Supabase fetch error:', e);
  }

  if (!article) {
    res.writeHead(302, { Location: '/blog.html' });
    return res.end();
  }

  const title = escHtml(article.titulo);
  const desc = escHtml(article.resumo);
  const image = escHtml(article.foto_url || '');
  const url = `https://agruai.com/blog/${encodeURIComponent(slug)}`;
  const categoria = escHtml(article.categoria || 'Agronegócio');
  const date = article.created_at || new Date().toISOString();

  // Read the artigo.html template and inject OG tags
  // Instead of reading the file, we return a minimal HTML that redirects JS-capable
  // browsers to the SPA, while crawlers get the OG tags they need
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<!-- SEO: Pre-rendered for social media crawlers -->
<title>${title} — Blog AgrUAI</title>
<meta name="description" content="${desc}">
<meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1">
<link rel="canonical" href="${url}">

<!-- Open Graph (Facebook, WhatsApp, LinkedIn) -->
<meta property="og:type" content="article">
<meta property="og:url" content="${url}">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${desc}">
<meta property="og:image" content="${image}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="${title}">
<meta property="og:locale" content="pt_BR">
<meta property="og:site_name" content="AgrUAI — Blog do Agro">
<meta property="article:publisher" content="AgrUAI">
<meta property="article:published_time" content="${date}">
<meta property="article:section" content="${categoria}">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${desc}">
<meta name="twitter:image" content="${image}">
<meta name="twitter:image:alt" content="${title}">

<!-- JSON-LD -->
<script type="application/ld+json">
${JSON.stringify({
  "@context": "https://schema.org",
  "@type": "NewsArticle",
  "headline": article.titulo,
  "description": article.resumo,
  "image": article.foto_url || '',
  "datePublished": date,
  "author": { "@type": "Organization", "name": "AgrUAI", "url": "https://agruai.com" },
  "publisher": { "@type": "Organization", "name": "AgrUAI", "logo": { "@type": "ImageObject", "url": "https://agruai.com/logo-full.svg" } },
  "mainEntityOfPage": { "@type": "WebPage", "@id": url },
  "inLanguage": "pt-BR"
})}
</script>

<meta name="theme-color" content="#0F1F0F">
<link rel="icon" type="image/svg+xml" href="/favicon.svg">

<!-- Redirect JS-capable browsers to the SPA -->
<script>window.location.replace('/artigo.html?slug=${encodeURIComponent(slug)}');</script>
<noscript><meta http-equiv="refresh" content="0;url=/artigo.html?slug=${encodeURIComponent(slug)}"></noscript>
</head>
<body style="background:#0F1F0F;color:#F5F0E8;font-family:sans-serif;padding:40px;text-align:center">
<h1 style="font-size:1.5rem;margin-bottom:16px">${title}</h1>
<p style="color:#A89E90;margin-bottom:24px">${desc}</p>
${image ? `<img src="${image}" alt="${title}" style="max-width:100%;border-radius:12px;margin-bottom:24px">` : ''}
<p><a href="/artigo.html?slug=${encodeURIComponent(slug)}" style="color:#C5A572">Leia o artigo completo &rarr;</a></p>
<p style="margin-top:40px;font-size:.8rem;color:#7A7268">&copy; 2026 AgrUAI — Inteligência Rural por Satélite</p>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate=86400');
  res.status(200).send(html);
};
