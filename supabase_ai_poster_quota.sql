-- ==============================================================================
-- ATUR KOS - MIGRASI AI POSTER & KUOTA GENERATE VARIASI FOTO KAMAR (v2.1)
-- Fitur: Edge Function AI, Kuota Bulanan per Kos, Riwayat AI Room Variations
-- ==============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. TAMBAH KOLOM KUOTA AI KE TABEL kosts
-- -----------------------------------------------------------------------------
ALTER TABLE public.kosts
ADD COLUMN IF NOT EXISTS ai_credits_monthly_quota INT NOT NULL DEFAULT 30,
ADD COLUMN IF NOT EXISTS ai_credits_used_this_month INT NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS ai_credits_reset_at TIMESTAMPTZ DEFAULT NOW();

-- Sesuaikan kuota berdasarkan tier langganan:
-- Tier Juragan: 30x generate per bulan
-- Tier Starter: 3x generate uji coba
UPDATE public.kosts
SET ai_credits_monthly_quota = CASE 
    WHEN tier = 'juragan' THEN 30 
    ELSE 3 
END
WHERE ai_credits_monthly_quota = 30 AND tier != 'juragan';

-- -----------------------------------------------------------------------------
-- 2. TABEL: ai_room_generations (Pencatatan Riwayat Generate Foto AI)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_room_generations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kost_id UUID NOT NULL REFERENCES public.kosts(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    original_image_url TEXT NOT NULL,
    style_preset VARCHAR(50) NOT NULL DEFAULT 'warm_cozy', -- 'warm_cozy', 'modern_minimalist', 'bright_daylight'
    generated_image_url TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'completed', -- 'processing', 'completed', 'failed'
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_generations_kost ON public.ai_room_generations(kost_id);
CREATE INDEX IF NOT EXISTS idx_ai_generations_room ON public.ai_room_generations(room_id);

-- -----------------------------------------------------------------------------
-- 3. FUNCTION & RPC: check_and_deduct_ai_credit
-- Memeriksa kuota AI, reset bulanan otomatis, dan memotong 1 kredit secara atomik
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_and_deduct_ai_credit(p_kost_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tier subscription_tier;
    v_quota INT;
    v_used INT;
    v_reset_at TIMESTAMPTZ;
    v_now TIMESTAMPTZ := NOW();
    v_remaining INT;
BEGIN
    -- 1. Ambil data kos
    SELECT tier, ai_credits_monthly_quota, ai_credits_used_this_month, ai_credits_reset_at
    INTO v_tier, v_quota, v_used, v_reset_at
    FROM public.kosts
    WHERE id = p_kost_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'message', 'Data kos tidak ditemukan'
        );
    END IF;

    -- 2. Cek apakah perlu reset siklus bulanan (jika sudah lewat 30 hari dari reset terakhir)
    IF v_reset_at IS NULL OR v_now >= (v_reset_at + INTERVAL '30 days') THEN
        v_used := 0;
        v_reset_at := v_now;
        
        -- Sesuaikan kuota jika ada perubahan tier
        IF v_tier = 'juragan' THEN
            v_quota := 30;
        ELSE
            v_quota := 3;
        END IF;

        UPDATE public.kosts
        SET ai_credits_used_this_month = 0,
            ai_credits_monthly_quota = v_quota,
            ai_credits_reset_at = v_reset_at
        WHERE id = p_kost_id;
    END IF;

    -- 3. Cek sisa kuota
    v_remaining := v_quota - v_used;
    IF v_remaining <= 0 THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'tier', v_tier,
            'quota', v_quota,
            'used', v_used,
            'remaining', 0,
            'message', 'Kuota generate poster AI bulan ini sudah habis. Silakan tingkatkan ke paket Juragan atau tunggu reset bulan depan.'
        );
    END IF;

    -- 4. Potong 1 kredit
    UPDATE public.kosts
    SET ai_credits_used_this_month = ai_credits_used_this_month + 1,
        updated_at = v_now
    WHERE id = p_kost_id;

    RETURN jsonb_build_object(
        'allowed', true,
        'tier', v_tier,
        'quota', v_quota,
        'used', v_used + 1,
        'remaining', v_remaining - 1,
        'message', 'Kredit AI berhasil digunakan.'
    );
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. STORAGE BUCKET: ai-room-variations
-- Bucket untuk menyimpan file gambar hasil pemrosesan AI secara publik
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'ai-room-variations',
    'ai-room-variations',
    true,
    10485760, -- 10MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- Storage Policies: Publik bisa melihat, user terautentikasi bisa mengunggah
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Public Access AI Variations'
    ) THEN
        CREATE POLICY "Public Access AI Variations"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'ai-room-variations');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Authenticated Users Upload AI Variations'
    ) THEN
        CREATE POLICY "Authenticated Users Upload AI Variations"
        ON storage.objects FOR INSERT
        TO authenticated
        WITH CHECK (bucket_id = 'ai-room-variations');
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS) UNTUK ai_room_generations
-- -----------------------------------------------------------------------------
ALTER TABLE public.ai_room_generations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners can view own kos AI generations"
ON public.ai_room_generations FOR SELECT
TO authenticated
USING (
    kost_id IN (
        SELECT kost_id FROM public.profiles WHERE id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin'
    )
);

CREATE POLICY "Owners can insert AI generations"
ON public.ai_room_generations FOR INSERT
TO authenticated
WITH CHECK (
    kost_id IN (
        SELECT kost_id FROM public.profiles WHERE id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin'
    )
);

COMMIT;
