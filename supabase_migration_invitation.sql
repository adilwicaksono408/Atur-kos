-- ==============================================================================
-- SISTEM MANAJEMEN OPERASIONAL ATUR KOS
-- Migrasi: Fitur Kode Undangan Kos (Multi-Tenant) & Registrasi Pemilik Baru
-- ==============================================================================

BEGIN;

-- 1. Tambahkan kolom kode_kost pada tabel kosts jika belum ada
ALTER TABLE public.kosts 
ADD COLUMN IF NOT EXISTS kode_kost VARCHAR(20) UNIQUE;

-- 2. Set kode default untuk Kos Princess
UPDATE public.kosts 
SET kode_kost = 'PRINCESS' 
WHERE (nama_kost = 'Kos Princess' OR kode_kost IS NULL) 
  AND id = (SELECT id FROM public.kosts ORDER BY created_at ASC LIMIT 1);

-- 3. Perbarui Fungsi Trigger handle_new_user agar mendukung multi-tenant otomatis
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    target_kost_id UUID;
    user_role_val user_role;
    kode_input TEXT;
    nama_kost_input TEXT;
    alamat_kost_input TEXT;
    generated_kode TEXT;
BEGIN
    -- Ambil role dari metadata, default 'tenant'
    user_role_val := COALESCE((new.raw_user_meta_data->>'role')::user_role, 'tenant'::user_role);
    kode_input := UPPER(TRIM(COALESCE(new.raw_user_meta_data->>'kode_kost', '')));
    nama_kost_input := TRIM(COALESCE(new.raw_user_meta_data->>'nama_kost', ''));
    alamat_kost_input := TRIM(COALESCE(new.raw_user_meta_data->>'alamat_kost', 'Jl. Belum diatur'));

    -- SKENARIO A: Pendaftaran sebagai Pemilik Kos Baru
    IF user_role_val = 'owner' AND nama_kost_input <> '' THEN
        -- Generate kode kos unik otomatis (misal: MELATI123)
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

    -- SKENARIO B: Pendaftaran sebagai Penghuni (Tenant)
    ELSE
        -- 1. Cari berdasarkan kode_kost yang dimasukkan
        IF kode_input <> '' THEN
            SELECT id INTO target_kost_id FROM public.kosts WHERE kode_kost = kode_input LIMIT 1;
        END IF;

        -- 2. Jika kode tidak ditemukan atau tidak diisi, otomatis hubungkan ke Kos Princess
        IF target_kost_id IS NULL THEN
            SELECT id INTO target_kost_id FROM public.kosts WHERE kode_kost = 'PRINCESS' LIMIT 1;
        END IF;

        -- 3. Fallback darurat jika data Kos Princess belum ber-kode
        IF target_kost_id IS NULL THEN
            SELECT id INTO target_kost_id FROM public.kosts ORDER BY created_at ASC LIMIT 1;
        END IF;
    END IF;

    -- Sinkronisasi ke tabel profiles
    INSERT INTO public.profiles (id, full_name, avatar_url, role, kost_id, nomor_wa)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', new.email),
        new.raw_user_meta_data->>'avatar_url',
        user_role_val,
        target_kost_id,
        new.raw_user_meta_data->>'nomor_wa'
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        avatar_url = EXCLUDED.avatar_url,
        role = EXCLUDED.role,
        kost_id = EXCLUDED.kost_id,
        nomor_wa = EXCLUDED.nomor_wa,
        updated_at = NOW();

    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
