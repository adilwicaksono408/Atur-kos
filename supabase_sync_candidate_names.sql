-- ==============================================================================
-- SISTEM MANAJEMEN OPERASIONAL ATUR KOS
-- Skrip Sinkronisasi Nama Calon Penghuni & Profil Pengguna
-- ==============================================================================
-- Masalah yang diselesaikan:
-- 1. Mengisi nama 'Fatimah' (dan calon penghuni lain) yang tersimpan di auth.users 
--    ke kolom full_name pada tabel public.profiles yang sebelumnya berstatus NULL
--    atau terisi default 'Calon Penghuni'.
-- 2. Memastikan trigger otomatis selalu menyalin nama lengkap saat pendaftaran baru.
-- ==============================================================================
-- Jalankan skrip ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

BEGIN;

-- 1. SINKRONKAN NAMA SEMUA USER DARI auth.users KE public.profiles
-- Mengambil dari metadata 'full_name', 'name', 'nama', atau bagian depan email
UPDATE public.profiles p
SET 
    full_name = COALESCE(
        NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
        NULLIF(TRIM(u.raw_user_meta_data->>'name'), ''),
        NULLIF(TRIM(u.raw_user_meta_data->>'nama'), ''),
        SPLIT_PART(u.email, '@', 1),
        'Penghuni'
    ),
    nomor_wa = COALESCE(
        p.nomor_wa,
        NULLIF(TRIM(u.raw_user_meta_data->>'nomor_wa'), '')
    ),
    updated_at = NOW()
FROM auth.users u
WHERE p.id = u.id
  AND (
      p.full_name IS NULL 
      OR TRIM(p.full_name) = '' 
      OR TRIM(LOWER(p.full_name)) = 'calon penghuni'
      OR TRIM(LOWER(p.full_name)) = 'penghuni'
  );

-- 2. MASUKKAN USER DARI auth.users JIKA BELUM MEMILIKI BARIS DI public.profiles
INSERT INTO public.profiles (
    id, 
    full_name, 
    role, 
    nomor_wa, 
    created_at, 
    updated_at
)
SELECT 
    u.id,
    COALESCE(
        NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
        NULLIF(TRIM(u.raw_user_meta_data->>'name'), ''),
        NULLIF(TRIM(u.raw_user_meta_data->>'nama'), ''),
        SPLIT_PART(u.email, '@', 1),
        'Penghuni'
    ),
    COALESCE((u.raw_user_meta_data->>'role')::public.user_role, 'tenant'::public.user_role),
    u.raw_user_meta_data->>'nomor_wa',
    NOW(),
    NOW()
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = u.id
);

-- 3. PERBAARUI TRIGGER handle_new_user() AGAR SELALU MENYALIN NAMA ASLI
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
    nama_user TEXT;
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

    -- Ekstrak nama asli dengan prioritas berjenjang
    nama_user := COALESCE(
        NULLIF(TRIM(new.raw_user_meta_data->>'full_name'), ''),
        NULLIF(TRIM(new.raw_user_meta_data->>'name'), ''),
        NULLIF(TRIM(new.raw_user_meta_data->>'nama'), ''),
        SPLIT_PART(new.email, '@', 1),
        'Penghuni'
    );

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

    -- Masukkan atau perbarui ke public.profiles
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
        nama_user,
        new.raw_user_meta_data->>'avatar_url',
        user_role_val,
        target_kost_id,
        new.raw_user_meta_data->>'nomor_wa',
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = CASE 
            WHEN profiles.full_name IS NULL OR TRIM(profiles.full_name) = '' OR TRIM(LOWER(profiles.full_name)) IN ('calon penghuni', 'penghuni')
            THEN EXCLUDED.full_name
            ELSE profiles.full_name
        END,
        avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
        role = EXCLUDED.role,
        kost_id = COALESCE(profiles.kost_id, EXCLUDED.kost_id),
        nomor_wa = COALESCE(EXCLUDED.nomor_wa, profiles.nomor_wa),
        updated_at = NOW();

    RETURN new;
END;
$$;

-- 4. CEK HASIL SINKRONISASI
SELECT id, full_name, role, kost_id, nomor_wa 
FROM public.profiles
WHERE role <> 'owner';

COMMIT;
