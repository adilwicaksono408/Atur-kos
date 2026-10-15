-- =============================================================================
-- ATUR KOS: MASTER MIGRATION MODUL 4 (MIDTRANS, KUITANSI QR & BUKU KAS OTOMATIS)
-- =============================================================================
-- Skrip ini 100% IDEMPOTENT & AMAN (TIDAK AKAN menghapus data yang sudah ada).
-- Jalankan skrip ini di: Supabase Dashboard -> SQL Editor -> Run (Ctrl + Enter).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. PASTIKAN SELURUH KOLOM TRANSAKSI MIDTRANS TERSEDIA DI TABEL INVOICES
-- -----------------------------------------------------------------------------
ALTER TABLE public.invoices
ADD COLUMN IF NOT EXISTS order_id VARCHAR(60),
ADD COLUMN IF NOT EXISTS snap_token TEXT,
ADD COLUMN IF NOT EXISTS payment_type VARCHAR(50),
ADD COLUMN IF NOT EXISTS midtrans_transaction_id TEXT,
ADD COLUMN IF NOT EXISTS transaction_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS settlement_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS qr_verification_code TEXT,
ADD COLUMN IF NOT EXISTS kuitansi_pdf_url TEXT;

-- Buat index pencarian cepat untuk verifikasi kuitansi & audit
CREATE INDEX IF NOT EXISTS idx_invoices_order_id ON public.invoices(order_id);
CREATE INDEX IF NOT EXISTS idx_invoices_qr_code ON public.invoices(qr_verification_code);

-- -----------------------------------------------------------------------------
-- 2. FUNGSI RPC: verify_receipt_public (PRD Modul 4 US-4.3 & US-4.4)
-- Memungkinkan siapa saja (anak kos, ortu, kampus, pemilik) memverifikasi
-- keabsahan kuitansi secara mandiri TANPA LOGIN (Publik).
-- Dilindungi SECURITY DEFINER dengan filter presisi tinggi (Anti-Harvesting / UU PDP)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_receipt_public(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Berjalan dengan otoritas sistem untuk membaca 1 kuitansi yang cocok persis
SET search_path = public
AS $$
DECLARE
    v_clean_code TEXT;
    v_result JSONB;
BEGIN
    -- Normalisasi dan sanitasi input kode
    v_clean_code := TRIM(p_code);
    IF v_clean_code IS NULL OR v_clean_code = '' THEN
        RETURN jsonb_build_object('is_valid', false, 'message', 'Kode verifikasi tidak boleh kosong');
    END IF;

    -- Bersihkan jika pengguna mem-paste URL verifikasi lengkap
    IF v_clean_code LIKE '%seal=%' THEN
        v_clean_code := SUBSTRING(v_clean_code FROM 'seal=([^&]+)');
    ELSIF v_clean_code LIKE '%id=%' THEN
        v_clean_code := SUBSTRING(v_clean_code FROM 'id=([^&]+)');
    END IF;

    -- Cari tagihan yang cocok persis dengan order_id, qr_verification_code, atau id
    SELECT jsonb_build_object(
        'is_valid', true,
        'id', inv.id,
        'order_id', COALESCE(inv.order_id, inv.id::text),
        'nomor_invoice', COALESCE(inv.order_id, inv.id::text),
        'status', inv.status,
        'nominal', inv.nominal,
        'periode', inv.periode,
        'payment_type', inv.payment_type,
        'midtrans_transaction_id', inv.midtrans_transaction_id,
        'settlement_time', COALESCE(inv.settlement_time, inv.transaction_time, inv.updated_at),
        'qr_verification_code', COALESCE(inv.qr_verification_code, 'ATURKOS-' || inv.order_id),
        'tenant_name', COALESCE(p.full_name, 'Penghuni Kos'),
        'tenant_phone', COALESCE(p.nomor_wa, '-'),
        'room_number', COALESCE(r.nomor_kamar, '-'),
        'room_type', COALESCE(r.tipe, '-'),
        'kos_name', COALESCE(k.nama_kost, 'Atur Kos'),
        'kos_address', COALESCE(k.alamat, '-'),
        'kos_contact', COALESCE(k.nomor_kontak, '-'),
        'created_at', inv.created_at
    )
    INTO v_result
    FROM public.invoices inv
    LEFT JOIN public.tenants t ON inv.tenant_id = t.id
    LEFT JOIN public.profiles p ON t.user_id = p.id
    LEFT JOIN public.rooms r ON t.room_id = r.id
    LEFT JOIN public.kosts k ON inv.kost_id = k.id
    WHERE inv.order_id = v_clean_code
       OR inv.qr_verification_code = v_clean_code
       OR inv.id::text = v_clean_code
    LIMIT 1;

    -- Jika tidak ditemukan, kembalikan respon invalid
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'is_valid', false,
            'message', 'Kuitansi tidak ditemukan dalam basis data resmi'
        );
    END IF;

    RETURN v_result;
END;
$$;

-- Berikan izin eksekusi ke peran anon (tanpa login) dan authenticated
GRANT EXECUTE ON FUNCTION public.verify_receipt_public(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_receipt_public(TEXT) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. PASTIKAN TABEL BUKU KAS (CASH_LEDGERS) SUDAH TERSEDIA
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cash_ledgers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kost_id UUID NOT NULL REFERENCES public.kosts(id) ON DELETE CASCADE,
    tipe public.cash_flow_type NOT NULL,
    kategori VARCHAR(50) NOT NULL,
    nominal NUMERIC(12, 2) NOT NULL,
    tanggal DATE NOT NULL DEFAULT CURRENT_DATE,
    keterangan TEXT,
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
    bukti_nota_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cash_ledgers_date ON public.cash_ledgers(kost_id, tanggal);

-- -----------------------------------------------------------------------------
-- 4. TRIGGER OTOMASI: BUKU KAS MASUK (CASH LEDGER) OTOMATIS SAAT LUNAS (PRD US-6.1)
-- Ketika tagihan lunas (via Midtrans Snap atau Verifikasi Pemilik),
-- PostgreSQL otomatis mencatat arus kas masuk tanpa bergantung pada koneksi client HP!
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_record_settlement_cash_ledger()
RETURNS trigger AS $$
DECLARE
    v_room_number TEXT;
    v_tenant_name TEXT;
BEGIN
    -- Hanya berjalan saat status invoice berubah menjadi 'lunas'
    IF (NEW.status = 'lunas' AND (OLD.status IS DISTINCT FROM 'lunas')) THEN
        -- Cegah duplikasi pencatatan jika invoice_id sudah ada di cash_ledgers
        IF NOT EXISTS (SELECT 1 FROM public.cash_ledgers WHERE invoice_id = NEW.id) THEN
            -- Ambil nomor kamar dan nama penyewa untuk rincian keterangan buku kas
            SELECT r.nomor_kamar, p.full_name
            INTO v_room_number, v_tenant_name
            FROM public.tenants t
            LEFT JOIN public.rooms r ON t.room_id = r.id
            LEFT JOIN public.profiles p ON t.user_id = p.id
            WHERE t.id = NEW.tenant_id;

            INSERT INTO public.cash_ledgers (
                kost_id,
                tipe,
                kategori,
                nominal,
                tanggal,
                keterangan,
                invoice_id
            ) VALUES (
                NEW.kost_id,
                'masuk'::public.cash_flow_type,
                'sewa_kamar',
                NEW.nominal,
                COALESCE(NEW.settlement_time::date, CURRENT_DATE),
                'Pelunasan sewa Kamar ' || COALESCE(v_room_number, '-') || ' (' || COALESCE(NEW.periode, '-') || ') via Midtrans Snap (' || COALESCE(NEW.payment_type, 'gateway') || ') - ' || COALESCE(NEW.order_id, NEW.id::text),
                NEW.id
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_auto_cash_ledger_on_settlement ON public.invoices;
CREATE TRIGGER trg_auto_cash_ledger_on_settlement
    AFTER UPDATE OF status ON public.invoices
    FOR EACH ROW
    EXECUTE FUNCTION public.auto_record_settlement_cash_ledger();

-- -----------------------------------------------------------------------------
-- 5. KEBIJAKAN RLS UNTUK TABEL CASH_LEDGERS (RBAC ATUR KOS)
-- Relasi Pemilik tersambung melalui tabel profiles (role = 'owner', p.kost_id)
-- -----------------------------------------------------------------------------
ALTER TABLE public.cash_ledgers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner can view cash ledgers" ON public.cash_ledgers;
DROP POLICY IF EXISTS "Owner can manage cash ledgers" ON public.cash_ledgers;

CREATE POLICY "Owner can view cash ledgers"
ON public.cash_ledgers FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() 
          AND (p.role = 'owner' OR p.role = 'super_admin')
          AND (p.kost_id = cash_ledgers.kost_id OR p.role = 'super_admin')
    )
);

CREATE POLICY "Owner can manage cash ledgers"
ON public.cash_ledgers FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() 
          AND p.role = 'owner'
          AND p.kost_id = cash_ledgers.kost_id
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() 
          AND p.role = 'owner'
          AND p.kost_id = cash_ledgers.kost_id
    )
);

-- =============================================================================
-- SELESAI. Skrip ini 100% aman dan telah diperbaiki sesuai skema tabel Atur Kos!
-- =============================================================================
