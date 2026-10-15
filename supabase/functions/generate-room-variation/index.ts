// ==============================================================================
// SUPABASE EDGE FUNCTION: generate-room-variation
// Mengolah foto asli kamar menjadi variasi estetik & siap poster menggunakan AI
// Mendukung: Fal.ai (Flux Im2Im / SDXL ControlNet), Replicate, & Mode Sandbox
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RequestPayload {
  kost_id: string
  room_id?: string
  image_url: string
  style_preset: 'warm_cozy' | 'modern_minimalist' | 'bright_daylight' | 'clean_aesthetic'
}

serve(async (req) => {
  // 1. Tangani CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

    // Auth Client untuk verifikasi user caller
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, message: 'Header otorisasi (JWT) diperlukan.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUserClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: userError } = await supabaseUserClient.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, message: 'Sesi login tidak valid atau telah kedaluwarsa.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Admin Client untuk eksekusi storage & database operasi terlindungi
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // 2. Parse payload request
    const body: RequestPayload = await req.json()
    const { kost_id, room_id, image_url, style_preset = 'warm_cozy' } = body

    if (!kost_id || !image_url) {
      return new Response(
        JSON.stringify({ success: false, message: 'Parameter kost_id dan image_url wajib diisi.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3. Validasi & Potong Kuota AI via Database RPC
    const { data: quotaResult, error: quotaError } = await supabaseAdmin.rpc('check_and_deduct_ai_credit', {
      p_kost_id: kost_id,
    })

    if (quotaError) {
      return new Response(
        JSON.stringify({ success: false, message: `Gagal memeriksa kuota AI: ${quotaError.message}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!quotaResult?.allowed) {
      return new Response(
        JSON.stringify({
          success: false,
          message: quotaResult?.message ?? 'Kuota AI Anda telah habis.',
          remaining: 0,
        }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. Susun Prompt AI berdasarkan Gaya Terpilih (Menjaga 100% Realistis Foto Kamar Kos Asli)
    let prompt = ''
    const negativePrompt = 'luxury hotel suite, luxury penthouse, mansion, swimming pool, massive king size bed, unrealistic architectural alteration, fake furniture, false advertising, distorted walls, blurry, messy floor, CGI render, fake lighting, deformed bed'

    switch (style_preset) {
      case 'modern_minimalist':
        prompt = 'Clean, honest, and tidy Indonesian boarding house bedroom (kamar kos) photography of this exact room, neat single bed, clean tiled floor, clear daytime ambient light, ultra-realistic real estate photo, 100% faithful to original room boundaries, walls, and furniture layout.'
        break
      case 'bright_daylight':
        prompt = 'Bright natural morning daylight illuminating this real Indonesian boarding house bedroom, crisp clarity, clean bedsheets, balanced realistic exposure, natural window light, accurate room size, authentic and trustworthy rental photo.'
        break
      case 'clean_aesthetic':
        prompt = 'Neat and natural Indonesian kos-kosan bedroom photography, soft warm ambient lighting, clean and organized study desk, tidy mattress, authentic wooden accents, maintaining exact room proportions and layout.'
        break
      case 'warm_cozy':
      default:
        prompt = 'Cozy evening warm lighting for this Indonesian kos room, warm bedside lamp glow, neat and clean bed, comfortable homey atmosphere, true to real-life dimensions, preserving all original furniture and door placement.'
        break
    }

    // 5. Panggil Engine AI (Fal.ai / Replicate / Sandbox Mock)
    const falKey = Deno.env.get('FAL_KEY')
    const replicateToken = Deno.env.get('REPLICATE_API_TOKEN')

    let generatedImageUrl = ''
    let isMock = false

    if (falKey) {
      // === Integrasi Fal.ai (Flux Im2Im / SDXL Fast dengan strength konservatif) ===
      const falResponse = await fetch('https://fal.run/fal-ai/flux/dev/image-to-image', {
        method: 'POST',
        headers: {
          'Authorization': `Key ${falKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          image_url: image_url,
          prompt: prompt,
          strength: 0.30, // Konservatif (0.30) agar perabot dan bentuk kamar asli tidak berubah sama sekali
          guidance_scale: 7.0,
          num_inference_steps: 25,
        }),
      })

      if (falResponse.ok) {
        const falData = await falResponse.json()
        generatedImageUrl = falData?.images?.[0]?.url ?? ''
      }
    } else if (replicateToken) {
      // === Integrasi Replicate ===
      const repResponse = await fetch('https://api.replicate.com/v1/predictions', {
        method: 'POST',
        headers: {
          'Authorization': `Token ${replicateToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          version: '76c4e07082d08e7a814c0b345e23b4f020c9439f24cd54133417a0a4f3adc33e',
          input: {
            image: image_url,
            prompt: prompt,
            negative_prompt: negativePrompt,
            prompt_strength: 0.30,
          },
        }),
      })

      if (repResponse.ok) {
        const repData = await repResponse.json()
        generatedImageUrl = repData?.output?.[0] ?? ''
      }
    }

    // Jika API Key belum terhubung, pertahankan 100% foto asli kamar milik pemilik kos
    // agar foto tetap autentik, jujur, dan tidak melebih-lebihkan kondisi kamar kos
    if (!generatedImageUrl) {
      isMock = true
      generatedImageUrl = image_url
    }

    // 6. Unduh Buffer Gambar & Simpan Permanen ke Supabase Storage (Bucket: ai-room-variations)
    let finalPublicUrl = generatedImageUrl

    try {
      const imageFetch = await fetch(generatedImageUrl)
      if (imageFetch.ok) {
        const imageBlob = await imageFetch.blob()
        const fileName = `${kost_id}/${room_id ?? 'custom'}_${Date.now()}.jpg`

        const { error: uploadError } = await supabaseAdmin.storage
          .from('ai-room-variations')
          .upload(fileName, imageBlob, {
            contentType: 'image/jpeg',
            upsert: true,
          })

        if (!uploadError) {
          const { data: publicData } = supabaseAdmin.storage
            .from('ai-room-variations')
            .getPublicUrl(fileName)
          if (publicData?.publicUrl) {
            finalPublicUrl = publicData.publicUrl
          }
        }
      }
    } catch (e) {
      console.warn('Storage upload fallback ke original generated url:', e)
    }

    // 7. Catat ke Tabel Riwayat Generasi (ai_room_generations)
    await supabaseAdmin.from('ai_room_generations').insert({
      kost_id: kost_id,
      room_id: room_id || null,
      user_id: user.id,
      original_image_url: image_url,
      style_preset: style_preset,
      generated_image_url: finalPublicUrl,
      status: 'completed',
    })

    // 8. Kembalikan Respons Sukses ke Aplikasi Flutter
    return new Response(
      JSON.stringify({
        success: true,
        generated_image_url: finalPublicUrl,
        original_image_url: image_url,
        style_preset: style_preset,
        credits_remaining: quotaResult.remaining,
        is_mock: isMock,
        message: isMock
          ? 'Variasi foto dihasilkan (Mode Sandbox/Uji Coba aktif).'
          : 'Foto kamar berhasil ditingkatkan kualitasnya oleh AI!',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, message: err?.message || 'Terjadi kesalahan sistem internal.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
