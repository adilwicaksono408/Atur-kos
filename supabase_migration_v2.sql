-- ==============================================================================
-- ATUR KOS: SKRIP MIGRASI BASIS DATA v2.0.0 (NON-DESTRUKTIF)
-- Transformasi Multi-Tenant SaaS, Super Admin, Midtrans Snap, & 2-Tier Pricing
-- ==============================================================================
-- Skrip ini aman dijalankan di Supabase SQL Editor.
-- Menggunakan ADD COLUMN IF NOT EXISTS sehingga TIDAK AKAN MENGHAPUS data yang sudah ada.
-- ==============================================================================

-- 1. PEMBARUAN & PENAMBAHAN TIPE ENUM
-- -----------------------------------------------------------------------------
-- Tambah role 'super_admin' ke user_role
DO $$ BEGIN
    BEGIN
        ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'super_admin';
    EXCEPTION WHEN duplicate_object THEN null;
    END;
END $$;

-- Buat enum kost_status untuk verifikasi kos oleh Super Admin
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kost_status') THEN
        CREATE TYPE public.kost_status AS ENUM ('pending_verification', 'active', 'rejected', 'suspended');
    END IF;
END $$;

-- Buat enum subscription_tier untuk paket freemium (Starter vs Juragan)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_tier') THEN
        CREATE TYPE public.subscription_tier AS ENUM ('starter', 'juragan');
    END IF;
END $$;

-- Tambah status Midtrans ('kedaluwarsa', 'batal') ke invoice_status
DO $$ BEGIN
    BEGIN
        ALTER TYPE public.invoice_status ADD VALUE IF NOT EXISTS 'kedaluwarsa';
    EXCEPTION WHEN duplicate_object THEN null;
    END;
    BEGIN
        ALTER TYPE public.invoice_status ADD VALUE IF NOT EXISTS 'batal';
    EXCEPTION WHEN duplicate_object THEN null;
    END;
END $$;

-- 2. UPGRADE TABEL: kosts (Geolocation, Verifikasi Super Admin & Paket Langganan)
-- -----------------------------------------------------------------------------
ALTER TABLE public.kosts
ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 8),
ADD COLUMN IF NOT EXISTS longitude NUMERIC(11, 8),
ADD COLUMN IF NOT EXISTS google_maps_url TEXT,
ADD COLUMN IF NOT EXISTS foto_bangunan_url TEXT,
ADD COLUMN IF NOT EXISTS dokumen_ktp_url TEXT,
ADD COLUMN IF NOT EXISTS status_verifikasi public.kost_status NOT NULL DEFAULT 'pending_verification',
ADD COLUMN IF NOT EXISTS catatan_verifikasi_admin TEXT,
ADD COLUMN IF NOT EXISTS diverifikasi_pada TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS tier public.subscription_tier NOT NULL DEFAULT 'starter',
ADD COLUMN IF NOT EXISTS max_rooms INT NOT NULL DEFAULT 5,
ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ;

-- Indeks performa untuk pencarian status verifikasi dan lokasi koordinat
CREATE INDEX IF NOT EXISTS idx_kosts_status ON public.kosts(status_verifikasi);
CREATE INDEX IF NOT EXISTS idx_kosts_lat_long ON public.kosts(latitude, longitude);

-- Otomatis aktifkan kos default (Kos Princess) yang sudah ada sebelumnya
UPDATE public.kosts
SET status_verifikasi = 'active'
WHERE status_verifikasi = 'pending_verification' 
  AND (kode_kost = 'PRINCESS' OR nama_kost = 'Kos Princess');

-- 3. UPGRADE TABEL: invoices (Integrasi Midtrans Snap & Kuitansi Sah Digital)
-- -----------------------------------------------------------------------------
ALTER TABLE public.invoices
ADD COLUMN IF NOT EXISTS order_id VARCHAR(60) UNIQUE,
ADD COLUMN IF NOT EXISTS snap_token TEXT,
ADD COLUMN IF NOT EXISTS payment_type VARCHAR(50),
ADD COLUMN IF NOT EXISTS midtrans_transaction_id TEXT,
ADD COLUMN IF NOT EXISTS transaction_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS settlement_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS qr_verification_code TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS kuitansi_pdf_url TEXT;

-- Sinkronkan order_id dengan nomor_invoice lama jika ada data invoice sebelumnya
UPDATE public.invoices
SET order_id = nomor_invoice
WHERE order_id IS NULL AND nomor_invoice IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_invoices_order_id ON public.invoices(order_id);

-- Pastikan relasi invoices ke tenants menggunakan ON DELETE CASCADE (mencegah error delete user)
ALTER TABLE public.invoices
DROP CONSTRAINT IF EXISTS invoices_tenant_id_fkey,
ADD CONSTRAINT invoices_tenant_id_fkey
    FOREIGN KEY (tenant_id)
    REFERENCES public.tenants(id)
    ON DELETE CASCADE;

-- 4. VALIDASI KUOTA KAMAR OTOMATIS (Paket Starter max 5 vs Juragan UNLIMITED)
-- -----------------------------------------------------------------------------
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

    -- JIKA PAKET JURAGAN (PREMIUM): Bebas akses kamar tanpa batas (Unlimited)
    IF kost_tier = 'juragan' THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*) INTO current_count
    FROM public.rooms
    WHERE kost_id = NEW.kost_id;

    IF allowed_max IS NOT NULL AND current_count >= allowed_max THEN
        RAISE EXCEPTION 'Batas kuota kamar terlampaui! Kos Anda menggunakan Paket % (Maksimal % kamar). Silakan upgrade ke Paket Juragan untuk menambah kamar tanpa batas.', kost_tier, allowed_max;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_room_quota ON public.rooms;
CREATE TRIGGER trg_check_room_quota
    BEFORE INSERT ON public.rooms
    FOR EACH ROW EXECUTE FUNCTION public.check_room_quota();

-- Selesai. Seluruh fitur PRD v2.0.0 telah aktif di database Anda!
