-- ============================================================================
-- SKRIP PERBAIKAN: PENDAFTARAN KOS BARU & PEMISAHAN DARI KOS PRINCESS
-- ============================================================================
-- Masalah yang diselesaikan:
-- 1. Trigger handle_new_user lama di Supabase selalu menghubungkan semua user baru
--    ke Kos Princess (baris pertama tabel kosts) tanpa membuat kos baru untuk pemilik.
-- 2. Memperbaiki akun pemilik yang sudah terlanjur dibuat agar otomatis mendapatkan
--    data kos miliknya sendiri sesuai isian nama kos dan alamat saat mendaftar.
-- ============================================================================

-- 1. PERBAARUI TRIGGER handle_new_user() AGAR PEMILIK KOS OTOMATIS DIBUATKAN KOS BARU
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
    nomor_wa_input TEXT;
    generated_kode TEXT;
BEGIN
    -- Ambil role dari metadata user
    raw_role_str := LOWER(TRIM(COALESCE(new.raw_user_meta_data->>'role', 'tenant')));
    IF raw_role_str = 'owner' THEN
        user_role_val := 'owner'::public.user_role;
    ELSIF raw_role_str = 'super_admin' OR LOWER(new.email) = 'wicaksonoadil768@gmail.com' THEN
        user_role_val := 'super_admin'::public.user_role;
    ELSE
        user_role_val := 'tenant'::public.user_role;
    END IF;

    -- Ekstrak nama asli pengguna
    nama_user := COALESCE(
        NULLIF(TRIM(new.raw_user_meta_data->>'full_name'), ''),
        NULLIF(TRIM(new.raw_user_meta_data->>'name'), ''),
        NULLIF(TRIM(new.raw_user_meta_data->>'nama'), ''),
        SPLIT_PART(new.email, '@', 1),
        'Pengguna Atur Kos'
    );

    nomor_wa_input := COALESCE(new.raw_user_meta_data->>'nomor_wa', '081234567890');
    nama_kost_input := TRIM(COALESCE(new.raw_user_meta_data->>'nama_kost', ''));
    alamat_kost_input := TRIM(COALESCE(new.raw_user_meta_data->>'alamat_kost', 'Alamat belum diatur'));
    kode_input := UPPER(TRIM(COALESCE(new.raw_user_meta_data->>'kode_kost', '')));

    -- SKENARIO A: Pemilik Kos (Owner)
    IF user_role_val = 'owner' THEN
        -- Gunakan nama kos dari form atau default nama pengguna
        IF nama_kost_input = '' THEN
            nama_kost_input := 'Kos ' || nama_user;
        END IF;

        -- Generate kode unik otomatis (misal: 6 huruf pertama + 3 digit angka unik)
        generated_kode := UPPER(SUBSTRING(REGEXP_REPLACE(nama_kost_input, '[^a-zA-Z0-9]', '', 'g') FROM 1 FOR 6));
        IF generated_kode = '' THEN
            generated_kode := 'KOS';
        END IF;
        generated_kode := generated_kode || LPAD(FLOOR(RANDOM() * 900 + 100)::TEXT, 3, '0');

        -- Buat properti kos baru untuk pemilik ini
        INSERT INTO public.kosts (
            nama_kost,
            alamat,
            nomor_kontak,
            kode_kost,
            status_verifikasi,
            tier,
            max_rooms
        )
        VALUES (
            nama_kost_input,
            alamat_kost_input,
            nomor_wa_input,
            generated_kode,
            'pending_verification',
            'starter',
            5
        )
        RETURNING id INTO target_kost_id;

    -- SKENARIO B: Super Admin
    ELSIF user_role_val = 'super_admin' THEN
        target_kost_id := NULL;

    -- SKENARIO C: Penghuni (Tenant)
    ELSE
        -- 1. Cari berdasarkan kode_kost yang dimasukkan calon penghuni
        IF kode_input <> '' THEN
            SELECT id INTO target_kost_id FROM public.kosts WHERE UPPER(TRIM(kode_kost)) = kode_input LIMIT 1;
        END IF;

        -- 2. Jika kode tidak cocok / tidak diisi, hubungkan otomatis ke Kos default pertama
        IF target_kost_id IS NULL THEN
            SELECT id INTO target_kost_id FROM public.kosts ORDER BY created_at ASC LIMIT 1;
        END IF;
    END IF;

    -- Masukkan atau perbarui profil ke public.profiles
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
        nomor_wa_input,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
        role = EXCLUDED.role,
        kost_id = COALESCE(EXCLUDED.kost_id, profiles.kost_id),
        nomor_wa = COALESCE(EXCLUDED.nomor_wa, profiles.nomor_wa),
        updated_at = NOW();

    RETURN new;

EXCEPTION WHEN OTHERS THEN
    -- Pengaman: jangan gagalkan signup auth jika terjadi error relasi
    RAISE WARNING 'handle_new_user error: %', SQLERRM;
    INSERT INTO public.profiles (id, full_name, role, updated_at)
    VALUES (new.id, nama_user, user_role_val, NOW())
    ON CONFLICT (id) DO NOTHING;
    RETURN new;
END;
$$;

-- Pastikan trigger terpasang pada auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================================
-- 2. KOREKSI DATA: PISAHKAN AKUN PEMILIK YANG SUDAH TERDAFTAR DARI KOS PRINCESS
-- ============================================================================
-- Bagian ini memeriksa semua pemilik (role = 'owner') yang saat ini masih
-- tertaut ke Kos Princess padahal di metadata pendaftaran ada nama_kost tersendiri.

DO $$
DECLARE
    owner_rec RECORD;
    new_kos_id UUID;
    v_nama_kost TEXT;
    v_alamat TEXT;
    v_wa TEXT;
    v_kode TEXT;
BEGIN
    FOR owner_rec IN 
        SELECT 
            p.id AS profile_id,
            p.kost_id,
            u.raw_user_meta_data
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
        WHERE p.role = 'owner'
    LOOP
        v_nama_kost := TRIM(COALESCE(owner_rec.raw_user_meta_data->>'nama_kost', ''));
        v_alamat := TRIM(COALESCE(owner_rec.raw_user_meta_data->>'alamat_kost', 'Alamat belum diatur'));
        v_wa := TRIM(COALESCE(owner_rec.raw_user_meta_data->>'nomor_wa', '081234567890'));

        -- Jika pemilik memiliki nama_kost di metadata dan saat ini tertaut ke Kos Princess
        IF v_nama_kost <> '' AND v_nama_kost <> 'Kos Princess' THEN
            -- Generate kode
            v_kode := UPPER(SUBSTRING(REGEXP_REPLACE(v_nama_kost, '[^a-zA-Z0-9]', '', 'g') FROM 1 FOR 6)) 
                      || LPAD(FLOOR(RANDOM() * 900 + 100)::TEXT, 3, '0');

            -- Buat kos baru
            INSERT INTO public.kosts (
                nama_kost, alamat, nomor_kontak, kode_kost, status_verifikasi, tier, max_rooms
            )
            VALUES (
                v_nama_kost, v_alamat, v_wa, v_kode, 'pending_verification', 'starter', 5
            )
            RETURNING id INTO new_kos_id;

            -- Update profil pemilik ke kos miliknya sendiri
            UPDATE public.profiles
            SET kost_id = new_kos_id, updated_at = NOW()
            WHERE id = owner_rec.profile_id;

            RAISE NOTICE 'Pemilik % berhasil dibuatkan kos baru: % (ID: %)', owner_rec.profile_id, v_nama_kost, new_kos_id;
        END IF;
    END LOOP;
END;
$$;
