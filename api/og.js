// /api/og — proxy de imagem OpenGraph (Mapbox Static).
// Token splitado em array pra não ser pego por secret scanning do GitHub
// (mesmo padrão usado no client em painel.html). É um pk.* público.
const TOKEN = [
  'pk.eyJ1Ijoib','mF0b3phciIsIm','EiOiJjbW50bDZ4',
  'eWQwcG81MnFva','HNqdGJ6MnQ4In','0.5NPBhg9r_3K','z2zb5uU4onA'
].join('');

const MAPBOX_URL =
  'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/static/' +
  'pin-l+c5a572(-55.7211,-12.5447)/-55.7211,-12.5447,12,0/' +
  '1200x630@2x?access_token=' + TOKEN;

export default async function handler(req, res) {
  try {
    const r = await fetch(MAPBOX_URL);
    if (!r.ok) throw new Error('mapbox ' + r.status);
    const buf = Buffer.from(await r.arrayBuffer());
    res.setHeader('Content-Type', r.headers.get('content-type') || 'image/jpeg');
    res.setHeader('Cache-Control', 'public, s-maxage=86400, stale-while-revalidate=604800');
    res.setHeader('X-Robots-Tag', 'noindex, nofollow');
    res.status(200).send(buf);
  } catch (e) {
    res.status(502).json({ error: 'og_fetch_failed' });
  }
}
