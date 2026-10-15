-- =============================================================================
-- ATUR KOS: MIGRASI AKSES KAMAR TANPA BATAS (UNLIMITED) UNTUK USER PREMIUM (JURAGAN)
-- =============================================================================
-- Deskripsi:
-- Pemilik kos dengan Paket Juragan kini dapat menambah kamar sebanyak-banyaknya
-- tanpa batasan kuota 25 kamar (Unlimited).
-- =============================================================================

-- 1. Perbarui Fungsi Validasi Kuota Kamar (check_room_quota)
CREATE OR REPLACE FUNCTION public.check_room_quota()
RETURNS trigger AS $$
DECLARE
    current_count INT;
    allowed_max INT;
    kost_tier public.subscription_tier;
BEGIN
    SELECT tier, max_rooms INTO kost_tier, allowed_max
    FROM public.kosts
    WHERE id = NEW.kost_id;

    -- JIKA PAKET JURAGAN (PREMIUM): Akses kamar bebas tanpa batas (Unlimited)
    IF kost_tier = 'juragan' THEN
        RETURN NEW;
    END IF;

    -- JIKA PAKET STARTER: Validasi batas kuota (default 5 kamar)
    SELECT COUNT(*) INTO current_count
    FROM public.rooms
    WHERE kost_id = NEW.kost_id;

    IF allowed_max IS NOT NULL AND current_count >= allowed_max THEN
        RAISE EXCEPTION 'Batas kuota kamar terlampaui! Kos Anda menggunakan Paket Starter (Maksimal % kamar). Silakan upgrade ke Paket Juragan untuk mendapatkan akses kamar tanpa batas.', allowed_max;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Pastikan Trigger Aktif pada Tabel Rooms
DROP TRIGGER IF EXISTS trg_check_room_quota ON public.rooms;
CREATE TRIGGER trg_check_room_quota
    BEFORE INSERT ON public.rooms
    FOR EACH ROW EXECUTE FUNCTION public.check_room_quota();

-- 3. Perbarui Nilai max_rooms untuk Kos yang Sudah Menjadi Paket Juragan
UPDATE public.kosts
SET max_rooms = 999999,
    updated_at = NOW()
WHERE tier = 'juragan';

-- Selesai. Akses kamar tanpa batas untuk Paket Juragan kini telah aktif!
