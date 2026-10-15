-- ==============================================================================
-- ATUR KOS - BASIS DATA SUPABASE POSTGRESQL (FULL SCHEMA v2.0.0)
-- Fitur: Multi-Tenant SaaS, Super Admin, Midtrans Integration, Geolocation, Subscriptions
-- Khusus: Auto-Assign Super Admin untuk wicaksonoadil768@gmail.com
-- ==============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. EXTENSIONS
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 2. ENUM TYPES
-- -----------------------------------------------------------------------------
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('super_admin', 'owner', 'tenant');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kost_status') THEN
        CREATE TYPE kost_status AS ENUM ('pending_verification', 'active', 'rejected', 'suspended');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_tier') THEN
        CREATE TYPE subscription_tier AS ENUM ('starter', 'juragan');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'room_status') THEN
        CREATE TYPE room_status AS ENUM ('kosong', 'terisi', 'akan_kosong', 'perbaikan');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tenant_status') THEN
        CREATE TYPE tenant_status AS ENUM ('aktif', 'akan_berakhir', 'keluar');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_status') THEN
        CREATE TYPE invoice_status AS ENUM ('belum_bayar', 'menunggu_verifikasi', 'lunas', 'kedaluwarsa', 'batal');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'complaint_scope') THEN
        CREATE TYPE complaint_scope AS ENUM ('kamar_pribadi', 'fasilitas_umum');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'complaint_status') THEN
        CREATE TYPE complaint_status AS ENUM ('diajukan', 'sedang_dikerjakan', 'selesai');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'cash_flow_type') THEN
        CREATE TYPE cash_flow_type AS ENUM ('masuk', 'keluar');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'announcement_category') THEN
        CREATE TYPE announcement_category AS ENUM ('paket', 'barang_hilang', 'info_operasional', 'umum');
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3. TABEL: kosts (Entitas Properti Kos Multi-Tenant)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.kosts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_kost VARCHAR(100) NOT NULL,
    alamat TEXT NOT NULL,
    nomor_kontak VARCHAR(20) NOT NULL,
    rekening_bank VARCHAR(50),
    nama_pemilik_rekening VARCHAR(100),
    
    -- Geolocation Dual-Mode (GPS & Peta Manual)
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),
    google_maps_url TEXT,
    
    -- Verifikasi Fisik oleh Super Admin
    foto_bangunan_url TEXT,
    dokumen_ktp_url TEXT,
    status_verifikasi kost_status NOT NULL DEFAULT 'pending_verification',
    catatan_verifikasi_admin TEXT,
    diverifikasi_pada TIMESTAMPTZ,
    
    -- Model Langganan 2-Tier
    tier subscription_tier NOT NULL DEFAULT 'starter',
    max_rooms INT NOT NULL DEFAULT 5,
    subscription_expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_kosts_status ON public.kosts(status_verifikasi);
CREATE INDEX IF NOT EXISTS idx_kosts_lat_long ON public.kosts(latitude, longitude);

-- -----------------------------------------------------------------------------
-- 4. TABEL: profiles (Sinkronisasi dengan auth.users)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    kost_id UUID REFERENCES public.kosts(id) ON DELETE RESTRICT,
    full_name TEXT NOT NULL,
    nomor_wa VARCHAR(20) UNIQUE,
    role user_role NOT NULL DEFAULT 'tenant',
    avatar_url TEXT,
    fcm_token TEXT,
    -- Identitas Legalitas Penghuni & Kontak Darurat (KYC Tenant)
    nik_ktp VARCHAR(20),
    dokumen_ktp_url TEXT,
    kontak_darurat_nama VARCHAR(100),
    kontak_darurat_wa VARCHAR(20),
    status_identitas VARCHAR(30) DEFAULT 'unverified',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_profiles_kost_id ON public.profiles(kost_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- -----------------------------------------------------------------------------
-- 5. TABEL: rooms (Inventaris Kamar & Batas Kuota Paket)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kost_id UUID NOT NULL REFERENCES public.kosts(id) ON DELETE CASCADE,
    nomor_kamar VARCHAR(20) NOT NULL,
    tipe VARCHAR(50) NOT NULL DEFAULT 'Standard',
    harga_bulanan NUMERIC(12, 2) NOT NULL,
    fasilitas TEXT[] DEFAULT '{}',
    foto_url TEXT,
    status room_status NOT NULL DEFAULT 'kosong',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_room_per_kost UNIQUE (kost_id, nomor_kamar)
);
CREATE INDEX IF NOT EXISTS idx_rooms_kost_status ON public.rooms(kost_id, status);

-- -----------------------------------------------------------------------------
-- 6. TABEL: tenants (Alokasi Sewa Aktif Penghuni & Kamar)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kost_id UUID NOT NULL REFERENCES public.kosts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE RESTRICT,
    tanggal_masuk DATE NOT NULL,
    tanggal_jatuh_tempo_bulanan INT NOT NULL CHECK (tanggal_jatuh_tempo_bulanan BETWEEN 1 AND 31),
    tanggal_akhir_sewa DATE,
    status_sewa tenant_status NOT NULL DEFAULT 'aktif',
    h30_response VARCHAR(30) DEFAULT 'menunggu', -- 'lanjut', 'selesai', 'menunggu', 'perlu_manual'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_tenants_active ON public.tenants(kost_id, status_sewa);
CREATE INDEX IF NOT EXISTS idx_tenants_user ON public.tenants(user_id);
CREATE INDEX IF NOT EXISTS idx_tenants_room ON public.tenants(room_id);

-- -----------------------------------------------------------------------------
-- 7. TABEL: invoices (Siklus Tagihan, Midtrans Gateway & Kuitansi QR)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kost_id UUID NOT NULL REFERENCES public.kosts(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
    order_id VARCHAR(60) NOT NULL UNIQUE, -- Contoh: INV/202610/05/001
    periode VARCHAR(20) NOT NULL, -- 'YYYY-MM'
    nominal NUMERIC(12, 2) NOT NULL,
    tanggal_jatuh_tempo DATE NOT NULL,
    
    -- Integrasi Midtrans Snap & Webhook
    snap_token TEXT,
    payment_type VARCHAR(50), -- 'qris', 'bank_transfer', 'gopay'
    midtrans_transaction_id TEXT,
    transaction_time TIMESTAMPTZ,
    settlement_time TIMESTAMPTZ,
    status invoice_status NOT NULL DEFAULT 'belum_bayar',
    
    -- Kuitansi Sah Digital Anti-Manipulasi
    qr_verification_code TEXT UNIQUE,
    kuitansi_pdf_url TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_invoices_status_date ON public.invoices(kost_id, status, tanggal_jatuh_tempo);
CREATE INDEX IF NOT EXISTS idx_invoices_order_id ON public.invoices(order_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant ON public.invoices(tenant_id);

-- -----------------------------------------------------------------------------
-- 8. TABEL: notification_logs (Log WhatsApp Reminder Anti-Banned)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notification_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    tipe_reminder VARCHAR(20) NOT NULL, -- 'H-3', 'Hari-H', 'H+2', 'Kuitansi'
    nomor_tujuan VARCHAR(20) NOT NULL,
    status_kirim VARCHAR(20) NOT NULL, -- 'sent', 'failed'
    response_payload JSONB,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_invoice_reminder ON public.notification_logs(invoice_id, tipe_reminder);

-- -----------------------------------------------------------------------------
-- 9. TABEL: complaints (Tiket Keluhan Kerusakan Fasilitas)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kost_id UUID NOT NULL REFERENCES public.kosts(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    tipe_fasilitas complaint_scope NOT NULL DEFAULT 'kamar_pribadi',
    judul VARCHAR(150) NOT NULL,
    deskripsi TEXT NOT NULL,
    foto_urls TEXT[] DEFAULT '{}',
    status complaint_status NOT NULL DEFAULT 'diajukan',
    catatan_penanganan TEXT,
    diselesaikan_pada TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_complaints_kost_status ON public.complaints(kost_id, status);
CREATE INDEX IF NOT EXISTS idx_complaints_tenant ON public.complaints(tenant_id);

-- -----------------------------------------------------------------------------
-- 10. TABEL: cash_ledgers (Buku Kas Masuk Otomatis & Kas Keluar Manual)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cash_ledgers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kost_id UUID NOT NULL REFERENCES public.kosts(id) ON DELETE CASCADE,
    tipe cash_flow_type NOT NULL,
    kategori VARCHAR(50) NOT NULL, -- 'sewa_kamar', 'listrik_air', 'wifi', 'perbaikan', 'lainnya'
    nominal NUMERIC(12, 2) NOT NULL,
    tanggal DATE NOT NULL DEFAULT CURRENT_DATE,
    keterangan TEXT,
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
    bukti_nota_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cash_ledgers_date ON public.cash_ledgers(kost_id, tanggal);

-- -----------------------------------------------------------------------------
-- 11. TABEL: announcements (Papan Pengumuman & Paket Kurir FCM)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kost_id UUID NOT NULL REFERENCES public.kosts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL, -- NULL jika disiarkan ke seluruh kos
    kategori announcement_category NOT NULL DEFAULT 'paket',
    judul VARCHAR(150) NOT NULL,
    deskripsi TEXT NOT NULL,
    foto_urls TEXT[] DEFAULT '{}',
    is_pinned BOOLEAN DEFAULT FALSE,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_announcements_kost ON public.announcements(kost_id, is_pinned DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_target_room ON public.announcements(target_room_id);

-- -----------------------------------------------------------------------------
-- 12. TRIGGER OTOMATIS: SINKRONISASI USER BARU & PENETAPAN SUPER ADMIN
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    assigned_role public.user_role;
    target_kost_id UUID;
BEGIN
    -- ATURAN KHUSUS: Jika email adalah wicaksonoadil768@gmail.com, otomatis jadikan super_admin
    IF LOWER(new.email) = 'wicaksonoadil768@gmail.com' THEN
        assigned_role := 'super_admin'::public.user_role;
        target_kost_id := NULL;
    ELSE
        assigned_role := COALESCE((new.raw_user_meta_data->>'role')::public.user_role, 'tenant'::public.user_role);
        SELECT id INTO target_kost_id FROM public.kosts ORDER BY created_at ASC LIMIT 1;
    END IF;

    INSERT INTO public.profiles (id, full_name, avatar_url, role, kost_id, updated_at)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
        new.raw_user_meta_data->>'avatar_url',
        assigned_role,
        target_kost_id,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        avatar_url = EXCLUDED.avatar_url,
        role = assigned_role,
        kost_id = COALESCE(EXCLUDED.kost_id, profiles.kost_id),
        updated_at = NOW();

    RETURN new;

EXCEPTION WHEN OTHERS THEN
    -- PENGAMAN: Jika ada anomali, jangan batalkan pembuatan akun di auth.users!
    RAISE WARNING 'handle_new_user error: %', SQLERRM;
    INSERT INTO public.profiles (id, full_name, role, updated_at)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        CASE WHEN LOWER(new.email) = 'wicaksonoadil768@gmail.com' THEN 'super_admin'::public.user_role ELSE 'tenant'::public.user_role END,
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 13. SEEDING / PENETAPAN SUPER ADMIN JIKA AKUN SUDAH PERNAH MENDAFTAR
-- -----------------------------------------------------------------------------
UPDATE public.profiles
SET role = 'super_admin'
WHERE id IN (
    SELECT id FROM auth.users WHERE LOWER(email) = 'wicaksonoadil768@gmail.com'
);

-- Buat kos awal terverifikasi untuk pengujian jika tabel kosts kosong
INSERT INTO public.kosts (nama_kost, alamat, nomor_kontak, rekening_bank, nama_pemilik_rekening, status_verifikasi, tier, max_rooms)
SELECT 'Kos Princess', 'Jl. Kaliurang KM 5, Sleman, D.I. Yogyakarta', '628123456789', 'BCA 1234567890', 'Ibu Rina', 'active', 'juragan', 999999
WHERE NOT EXISTS (SELECT 1 FROM public.kosts WHERE nama_kost = 'Kos Princess');

COMMIT;
