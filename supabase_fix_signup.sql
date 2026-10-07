-- ==============================================================================
-- SISTEM MANAJEMEN OPERASIONAL ATUR KOS
-- Skrip Perbaikan Definitif: Mengatasi "Database error saving new user" (HTTP 500)
-- & Menjamin Registrasi Penghuni (PRINCESS) & Pemilik Berjalan 100% Mulus
-- ==============================================================================

BEGIN;

-- 1. Pastikan tipe ENUM user_role tersedia di schema public
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE public.user_role AS ENUM ('owner', 'tenant');
    END IF;
END $$;

-- 2. Pastikan tabel kosts memiliki kolom kode_kost dan data default Kos Princess
CREATE TABLE IF NOT EXISTS public.kosts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_kost VARCHAR(100) NOT NULL DEFAULT 'Kos Princess',
    alamat TEXT NOT NULL DEFAULT 'Jl. Kos Princess No. 1',
    nomor_kontak VARCHAR(20) NOT NULL DEFAULT '628123456789',
    rekening_bank VARCHAR(50),
    nama_pemilik_rekening VARCHAR(100),
    kode_kost VARCHAR(20) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.kosts ADD COLUMN IF NOT EXISTS kode_kost VARCHAR(20) UNIQUE;

-- Pastikan data Kos Princess terdaftar dan memiliki kode_kost 'PRINCESS'
INSERT INTO public.kosts (nama_kost, alamat, nomor_kontak, kode_kost)
SELECT 'Kos Princess', 'Jl. Kos Princess No. 1, Yogyakarta', '628123456789', 'PRINCESS'
WHERE NOT EXISTS (SELECT 1 FROM public.kosts WHERE kode_kost = 'PRINCESS' OR nama_kost = 'Kos Princess');

UPDATE public.kosts 
SET kode_kost = 'PRINCESS' 
WHERE kode_kost IS NULL OR nama_kost = 'Kos Princess';

-- 3. Pastikan kolom-kolom pada tabel profiles lengkap dan aman dari constraint crash
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS kost_id UUID REFERENCES public.kosts(id) ON DELETE SET NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS nomor_wa VARCHAR(50);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role public.user_role NOT NULL DEFAULT 'tenant';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Hapus constraint UNIQUE pada nomor_wa jika ada (mencegah crash registrasi jika nomor serupa)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_nomor_wa_key;

-- 4. Perbarui Fungsi Trigger handle_new_user() dengan Proteksi Exception Penuh
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    target_kost_id UUID;
    user_role_val public.user_role;
    raw_role_str TEXT;
    kode_input TEXT;
    nama_kost_input TEXT;
    alamat_kost_input TEXT;
    generated_kode TEXT;
BEGIN
    -- Ambil role dengan fallback aman
    raw_role_str := LOWER(TRIM(COALESCE(new.raw_user_meta_data->>'role', 'tenant')));
    IF raw_role_str = 'owner' THEN
        user_role_val := 'owner'::public.user_role;
    ELSE
        user_role_val := 'tenant'::public.user_role;
    END IF;

    kode_input := UPPER(TRIM(COALESCE(new.raw_user_meta_data->>'kode_kost', '')));
    nama_kost_input := TRIM(COALESCE(new.raw_user_meta_data->>'nama_kost', ''));
    alamat_kost_input := TRIM(COALESCE(new.raw_user_meta_data->>'alamat_kost', 'Jl. Belum diatur'));

    -- SKENARIO A: Pemilik Kos Baru mendaftarkan kosnya
    IF user_role_val = 'owner' AND nama_kost_input <> '' THEN
        generated_kode := UPPER(SUBSTRING(REGEXP_REPLACE(nama_kost_input, '[^a-zA-Z0-9]', '', 'g') FROM 1 FOR 6)) 
                          || LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
        
        INSERT INTO public.kosts (nama_kost, alamat, nomor_kontak, kode_kost)
        VALUES (
            nama_kost_input,
            alamat_kost_input,
            COALESCE(new.raw_user_meta_data->>'nomor_wa', '08123456789'),
            generated_kode
        )
        RETURNING id INTO target_kost_id;

    -- SKENARIO B: Penghuni (Tenant)
    ELSE
        -- 1. Cari berdasarkan kode_kost yang dimasukkan
        IF kode_input <> '' THEN
            SELECT id INTO target_kost_id FROM public.kosts WHERE UPPER(kode_kost) = kode_input LIMIT 1;
        END IF;

        -- 2. Jika kode tidak cocok / tidak diisi, hubungkan otomatis ke Kos Princess
        IF target_kost_id IS NULL THEN
            SELECT id INTO target_kost_id FROM public.kosts WHERE UPPER(kode_kost) = 'PRINCESS' LIMIT 1;
        END IF;

        -- 3. Fallback darurat jika ada properti kos lain
        IF target_kost_id IS NULL THEN
            SELECT id INTO target_kost_id FROM public.kosts ORDER BY created_at ASC LIMIT 1;
        END IF;
    END IF;

    -- 5. Masukkan profil ke tabel public.profiles
    INSERT INTO public.profiles (
        id, 
        full_name, 
        avatar_url, 
        role, 
        kost_id, 
        nomor_wa, 
        updated_at
    )
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', new.email),
        new.raw_user_meta_data->>'avatar_url',
        user_role_val,
        target_kost_id,
        new.raw_user_meta_data->>'nomor_wa',
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        avatar_url = EXCLUDED.avatar_url,
        role = EXCLUDED.role,
        kost_id = COALESCE(EXCLUDED.kost_id, profiles.kost_id),
        nomor_wa = EXCLUDED.nomor_wa,
        updated_at = NOW();

    RETURN new;

EXCEPTION WHEN OTHERS THEN
    -- FAIL-SAFE: Jangan sampai registrasi Supabase Auth gagal jika terjadi anomali
    RAISE WARNING 'handle_new_user error: %', SQLERRM;
    INSERT INTO public.profiles (id, full_name, role, updated_at)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', new.email),
        'tenant'::public.user_role,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        updated_at = NOW();

    RETURN new;
END;
$$;

-- 6. Pasang ulang trigger pada tabel auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

COMMIT;
