import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()

  try {
    const body = await req.json()
    const { log_id, storage_path } = body

    if (!log_id || !storage_path) {
      return new Response(
        JSON.stringify({ error: 'log_id and storage_path are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[transcribe] Starting: log=${log_id}, path=${storage_path}`)

    // 1. Download audio from Supabase Storage
    const { data: fileData, error: downloadError } = await supabase.storage
      .from('audio-logs')
      .download(storage_path)

    if (downloadError || !fileData) {
      console.error('[transcribe] Download error:', downloadError)
      return new Response(
        JSON.stringify({ error: 'Failed to download audio: ' + (downloadError?.message || 'empty') }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[transcribe] Downloaded: ${fileData.size} bytes`)

    // 2. Send to OpenAI Whisper API
    const formData = new FormData()
    formData.append('file', new File([fileData], 'audio.webm', { type: 'audio/webm' }))
    formData.append('model', 'whisper-1')
    formData.append('language', 'pt')
    formData.append('response_format', 'json')

    const whisperRes = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${OPENAI_API_KEY}` },
      body: formData,
    })

    if (!whisperRes.ok) {
      const errText = await whisperRes.text()
      console.error('[transcribe] Whisper error:', whisperRes.status, errText)
      return new Response(
        JSON.stringify({ error: 'Whisper API error: ' + whisperRes.status }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const whisperData = await whisperRes.json()
    const transcription = whisperData.text?.trim()

    if (!transcription) {
      return new Response(
        JSON.stringify({ error: 'Empty transcription', status: 'empty' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[transcribe] Result: "${transcription.substring(0, 80)}..."`)

    // 3. Update field_log with transcribed text
    const { error: updateError } = await supabase
      .from('field_logs')
      .update({
        content: '🎙️ ' + transcription + ' [Transcrito por I.A.]',
      })
      .eq('id', log_id)

    if (updateError) {
      console.error('[transcribe] Update error:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to update log: ' + updateError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const duration = ((Date.now() - startTime) / 1000).toFixed(1)
    console.log(`[transcribe] Done in ${duration}s`)

    return new Response(
      JSON.stringify({
        status: 'transcribed',
        transcription,
        log_id,
        duration_seconds: parseFloat(duration),
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error('[transcribe] Fatal:', msg)
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
