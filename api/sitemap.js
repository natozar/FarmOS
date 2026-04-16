// Vercel Serverless Function: /sitemap.xml
// Generates dynamic sitemap with static pages + all published articles

const SUPA_URL = 'https://kyvbnntoxslrtrsiejzc.supabase.co';
const SUPA_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5dmJubnRveHNscnRyc2llanpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NjQ1NDcsImV4cCI6MjA5MTQ0MDU0N30.Dx-9SKxWfAoxXg3gzx3NpzJD1taZgkQCCjwDXlY9J6I';

module.exports = async (req, res) => {
  const today = new Date().toISOString().split('T')[0];

  // Static pages
  const staticPages = [
    { loc: 'https://agruai.com/', changefreq: 'weekly', priority: '1.0', lastmod: today },
    { loc: 'https://agruai.com/en', changefreq: 'monthly', priority: '0.8', lastmod: today },
    { loc: 'https://agruai.com/es', changefreq: 'monthly', priority: '0.8', lastmod: today },
    { loc: 'https://agruai.com/blog', changefreq: 'daily', priority: '0.9', lastmod: today },
  ];

  // Fetch all published articles
  let articles = [];
  try {
    const r = await fetch(
      `${SUPA_URL}/rest/v1/artigos?publicado=eq.true&select=slug,created_at,updated_at&order=created_at.desc&limit=500`,
      { headers: { apikey: SUPA_KEY, Authorization: `Bearer ${SUPA_KEY}` } }
    );
    articles = await r.json();
  } catch (e) {
    console.error('Sitemap: failed to fetch articles', e);
  }

  // Build XML
  let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  xml += '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"\n';
  xml += '        xmlns:xhtml="http://www.w3.org/1999/xhtml">\n\n';

  // Static pages
  for (const p of staticPages) {
    xml += '  <url>\n';
    xml += `    <loc>${p.loc}</loc>\n`;
    xml += `    <lastmod>${p.lastmod}</lastmod>\n`;
    xml += `    <changefreq>${p.changefreq}</changefreq>\n`;
    xml += `    <priority>${p.priority}</priority>\n`;

    // Hreflang for landing pages
    if (p.loc === 'https://agruai.com/') {
      xml += '    <xhtml:link rel="alternate" hreflang="pt-BR" href="https://agruai.com/" />\n';
      xml += '    <xhtml:link rel="alternate" hreflang="en" href="https://agruai.com/en" />\n';
      xml += '    <xhtml:link rel="alternate" hreflang="es" href="https://agruai.com/es" />\n';
      xml += '    <xhtml:link rel="alternate" hreflang="x-default" href="https://agruai.com/" />\n';
    }
    xml += '  </url>\n\n';
  }

  // Article pages
  if (articles && articles.length) {
    for (const a of articles) {
      const lastmod = (a.updated_at || a.created_at || today).split('T')[0];
      xml += '  <url>\n';
      xml += `    <loc>https://agruai.com/blog/${encodeURIComponent(a.slug)}</loc>\n`;
      xml += `    <lastmod>${lastmod}</lastmod>\n`;
      xml += '    <changefreq>monthly</changefreq>\n';
      xml += '    <priority>0.7</priority>\n';
      xml += '  </url>\n';
    }
  }

  xml += '\n</urlset>';

  res.setHeader('Content-Type', 'application/xml; charset=utf-8');
  res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate=86400');
  res.status(200).send(xml);
};
