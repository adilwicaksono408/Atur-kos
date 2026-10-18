-- =============================================================================
-- ATUR KOS: MIGRASI MODUL 9 (PAPAN PENGUMUMAN DIGITAL & PAKET KURIR TIBA)
-- Row Level Security (RLS), Storage Bucket 'announcements', & Indexing
-- =============================================================================
-- Jalankan skrip ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- =============================================================================

BEGIN;

-- 1. ENUM KATEGORI PENGUMUMAN
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'announcement_category') THEN
        CREATE TYPE announcement_category AS ENUM ('paket', 'barang_hilang', 'info_operasional', 'umum');
    END IF;
END $$;

-- 2. TABEL ANNOUNCEMENTS
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kost_id UUID NOT NULL REFERENCES public.kosts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL, -- NULL jika broadcast seluruh kos
    kategori announcement_category NOT NULL DEFAULT 'paket',
    judul VARCHAR(150) NOT NULL,
    deskripsi TEXT NOT NULL,
    foto_urls TEXT[] DEFAULT '{}',
    is_pinned BOOLEAN DEFAULT FALSE,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indeks performa untuk kueri cepat
CREATE INDEX IF NOT EXISTS idx_announcements_kost ON public.announcements(kost_id, is_pinned DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_target_room ON public.announcements(target_room_id);
CREATE INDEX IF NOT EXISTS idx_announcements_kategori ON public.announcements(kategori);
CREATE INDEX IF NOT EXISTS idx_announcements_resolved ON public.announcements(is_resolved);

-- 3. STORAGE BUCKET 'announcements' (Foto Paket Kurir & Barang Hilang)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'announcements',
    'announcements',
    true,
    5242880, -- Maksimal 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- Storage Policies
DO $$ BEGIN
    -- Semua orang (Authenticated / Public) dapat melihat foto pengumuman
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Public Access Announcements Bucket'
    ) THEN
        CREATE POLICY "Public Access Announcements Bucket"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'announcements');
    END IF;

    -- User terautentikasi dapat mengunggah foto pengumuman/paket
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Authenticated Upload Announcements Bucket'
    ) THEN
        CREATE POLICY "Authenticated Upload Announcements Bucket"
        ON storage.objects FOR INSERT
        TO authenticated
        WITH CHECK (bucket_id = 'announcements');
    END IF;

    -- Pemilik/Pengunggah dapat menghapus fotonya
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Authenticated Delete Announcements Bucket'
    ) THEN
        CREATE POLICY "Authenticated Delete Announcements Bucket"
        ON storage.objects FOR DELETE
        TO authenticated
        USING (bucket_id = 'announcements');
    END IF;
END $$;

-- 4. ROW LEVEL SECURITY (RLS) POLICIES PADA TABEL ANNOUNCEMENTS
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "View announcements policy" ON public.announcements;
DROP POLICY IF EXISTS "Insert announcements policy" ON public.announcements;
DROP POLICY IF EXISTS "Update announcements policy" ON public.announcements;
DROP POLICY IF EXISTS "Delete announcements policy" ON public.announcements;

-- ATURAN 1 (BACA / SELECT):
-- a. Super Admin dapat melihat semua pengumuman.
-- b. Pemilik Kos dapat melihat seluruh pengumuman kos miliknya.
-- c. Penghuni Kos HANYA dapat melihat pengumuman di kos tempat ia aktif sewa, dengan syarat:
--    - Pengumuman bersifat siaran umum (target_room_id IS NULL), ATAU
--    - Pengumuman khusus ditujukan untuk nomor kamarnya (target_room_id = tenant.room_id).
--    (Mencegah penghuni A melihat notifikasi paket penghuni kamar B!)
CREATE POLICY "View announcements policy"
ON public.announcements FOR SELECT
TO authenticated
USING (
    -- Super Admin
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'super_admin'
    )
    OR
    -- Pemilik Kos
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
    OR
    -- Penghuni Kos yang Aktif
    (
        kost_id IN (
            SELECT t.kost_id FROM public.tenants t 
            WHERE t.user_id = auth.uid() AND t.status_sewa = 'aktif'
        )
        AND
        (
            target_room_id IS NULL 
            OR target_room_id IN (
                SELECT t.room_id FROM public.tenants t 
                WHERE t.user_id = auth.uid() AND t.status_sewa = 'aktif'
            )
        )
    )
);

-- ATURAN 2 (TAMBAH / INSERT):
-- Hanya Pemilik Kos atau Super Admin yang berhak menerbitkan pengumuman baru & mencatat paket kurir
CREATE POLICY "Insert announcements policy"
ON public.announcements FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role IN ('owner', 'super_admin')
    )
);

-- ATURAN 3 (UBAH / UPDATE):
-- a. Pemilik Kos & Super Admin dapat memperbarui seluruh kolom pengumuman (pin, edit, status).
-- b. Penghuni kamar terkait HANYA diizinkan mengupdate pengumuman paket miliknya (untuk aksi "Tandai Sudah Diambil").
CREATE POLICY "Update announcements policy"
ON public.announcements FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role IN ('owner', 'super_admin')
    )
    OR
    (
        target_room_id IS NOT NULL
        AND target_room_id IN (
            SELECT t.room_id FROM public.tenants t 
            WHERE t.user_id = auth.uid() AND t.status_sewa = 'aktif'
        )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role IN ('owner', 'super_admin')
    )
    OR
    (
        target_room_id IS NOT NULL
        AND target_room_id IN (
            SELECT t.room_id FROM public.tenants t 
            WHERE t.user_id = auth.uid() AND t.status_sewa = 'aktif'
        )
    )
);

-- ATURAN 4 (HAPUS / DELETE):
-- Hanya Pemilik Kos atau Super Admin yang dapat menghapus pengumuman
CREATE POLICY "Delete announcements policy"
ON public.announcements FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role IN ('owner', 'super_admin')
    )
);

COMMIT;
