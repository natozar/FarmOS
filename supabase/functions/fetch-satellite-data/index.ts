import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const COPERNICUS_CLIENT_ID = Deno.env.get('COPERNICUS_CLIENT_ID')!
const COPERNICUS_CLIENT_SECRET = Deno.env.get('COPERNICUS_CLIENT_SECRET')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

async function getToken(): Promise<string> {
  const res = await fetch('https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: COPERNICUS_CLIENT_ID,
      client_secret: COPERNICUS_CLIENT_SECRET
    })
  })
  if (!res.ok) {
    const err = await res.text()
    throw new Error(`Copernicus auth failed: ${res.status} ${err}`)
  }
  const data = await res.json()
  return data.access_token
}

async function fetchNDVI(token: string, geojson: any, dateFrom: string, dateTo: string) {
  const evalscript = `
    //VERSION=3
    function setup() {
      return {
        input: [{ bands: ["B04", "B08", "B03", "B11", "SCL"], units: "DN" }],
        output: [
          { id: "ndvi", bands: 1 },
          { id: "evi", bands: 1 },
          { id: "ndwi", bands: 1 }
        ],
        mosaicking: "ORBIT"
      }
    }
    function evaluatePixel(samples) {
      let dominated_by_clouds = [3, 8, 9, 10]
      let dominated = dominated_by_clouds.includes(samples[0].SCL)
      if (dominated) return { ndvi: [-9999], evi: [-9999], ndwi: [-9999] }

      let nir = samples[0].B08
      let red = samples[0].B04
      let green = samples[0].B03

      let ndvi = (nir - red) / (nir + red + 0.0001)
      let evi = 2.5 * (nir - red) / (nir + 6 * red - 7.5 * 0.5 * green + 1)
      let ndwi = (green - nir) / (green + nir + 0.0001)

      return { ndvi: [ndvi], evi: [evi], ndwi: [ndwi] }
    }
  `

  const body = {
    input: {
      bounds: { geometry: geojson, properties: { crs: "http://www.opengis.net/def/crs/EPSG/0/4326" } },
      data: [{
        type: "sentinel-2-l2a",
        dataFilter: { timeRange: { from: dateFrom, to: dateTo }, maxCloudCoverage: 30 }
      }]
    },
    aggregation: {
      timeRange: { from: dateFrom, to: dateTo },
      aggregationInterval: { of: "P5D" },
      evalscript,
      resx: 20,
      resy: 20
    },
    calculations: { default: { statistics: { default: { percentiles: { k: [25, 50, 75] } } } } }
  }

  const res = await fetch('https://sh.dataspace.copernicus.eu/api/v1/statistics', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  })

  if (!res.ok) {
    console.error('Sentinel API error:', res.status, await res.text())
    return null
  }

  return await res.json()
}

Deno.serve(async (_req) => {
  try {
    const { data: properties, error } = await supabase
      .rpc('get_all_active_properties_for_satellite')

    if (error) throw error
    if (!properties || properties.length === 0) {
      return new Response(JSON.stringify({ message: 'No properties to process' }), {
        status: 200, headers: { 'Content-Type': 'application/json' }
      })
    }

    const token = await getToken()
    const now = new Date()
    const dateTo = now.toISOString().split('T')[0] + 'T23:59:59Z'
    const from = new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000)
    const dateFrom = from.toISOString().split('T')[0] + 'T00:00:00Z'

    let processed = 0
    let alerts_created = 0

    for (const prop of properties) {
      const geojson = prop.geojson
      if (!geojson) continue

      try {
        const stats = await fetchNDVI(token, geojson, dateFrom, dateTo)
        if (!stats || !stats.data || stats.data.length === 0) continue

        const latest = stats.data[stats.data.length - 1]
        const ndviStats = latest.outputs?.ndvi?.bands?.B0?.stats
        const eviStats = latest.outputs?.evi?.bands?.B0?.stats
        const ndwiStats = latest.outputs?.ndwi?.bands?.B0?.stats

        if (!ndviStats) continue

        const ndvi_mean = ndviStats.mean
        const evi_mean = eviStats?.mean ?? null
        const ndwi_mean = ndwiStats?.mean ?? null

        let classification = 'healthy'
        if (ndvi_mean < 0.2) classification = 'critical'
        else if (ndvi_mean < 0.4) classification = 'stressed'
        else if (ndvi_mean < 0.6) classification = 'moderate'

        const cloud_coverage = ndviStats.sampleCount > 0
          ? (1 - ndviStats.sampleCount / (ndviStats.sampleCount + (ndviStats.noDataCount || 0))) * 100
          : null

        const { error: insertError } = await supabase
          .from('satellite_readings')
          .insert({
            property_id: prop.id,
            reading_date: latest.interval.from.split('T')[0],
            ndvi: ndvi_mean,
            evi: evi_mean,
            ndwi: ndwi_mean,
            cloud_coverage,
            source: 'sentinel-2-l2a',
            classification,
            raw_data: latest
          })

        if (!insertError) processed++
        else console.error('Insert error for', prop.nome, insertError.message)

        if (ndvi_mean < 0.3) {
          await supabase.from('alerts').insert({
            property_id: prop.id,
            type: 'ndvi_low',
            severity: ndvi_mean < 0.2 ? 'critical' : 'warning',
            message: `NDVI baixo (${ndvi_mean.toFixed(2)}) detectado em ${prop.nome}. Possível estresse na vegetação.`,
            data: { ndvi: ndvi_mean, evi: evi_mean, date: latest.interval.from }
          })
          alerts_created++
        }
      } catch (propErr) {
        console.error('Error processing', prop.nome, propErr)
      }
    }

    return new Response(JSON.stringify({
      processed,
      alerts_created,
      total_properties: properties.length
    }), { status: 200, headers: { 'Content-Type': 'application/json' } })

  } catch (err) {
    console.error('Pipeline error:', err)
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500, headers: { 'Content-Type': 'application/json' }
    })
  }
})