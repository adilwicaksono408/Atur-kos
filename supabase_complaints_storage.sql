-- =============================================================================
-- ATUR KOS: STORAGE BUCKET UNTUK HELPDESK & FOTO KELUHAN FASILITAS (MODUL 6)
-- =============================================================================

-- 1. Buat bucket penyimpanan 'complaints' jika belum ada
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'complaints',
    'complaints',
    true,
    5242880, -- 5MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- 2. Kebijakan Keamanan (Storage Policies)
DO $$ BEGIN
    -- Publik / Authenticated bisa melihat foto bukti keluhan
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Public Access Complaints Bucket'
    ) THEN
        CREATE POLICY "Public Access Complaints Bucket"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'complaints');
    END IF;

    -- User terautentikasi (Penghuni & Pemilik) dapat mengunggah foto keluhan
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Authenticated Upload Complaints Bucket'
    ) THEN
        CREATE POLICY "Authenticated Upload Complaints Bucket"
        ON storage.objects FOR INSERT
        TO authenticated
        WITH CHECK (bucket_id = 'complaints');
    END IF;

    -- Pengguna dapat mengupdate atau menghapus fotonya sendiri
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Authenticated Delete Complaints Bucket'
    ) THEN
        CREATE POLICY "Authenticated Delete Complaints Bucket"
        ON storage.objects FOR DELETE
        TO authenticated
        USING (bucket_id = 'complaints');
    END IF;
END $$;
