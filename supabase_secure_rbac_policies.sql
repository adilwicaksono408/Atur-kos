-- ==============================================================================
-- SISTEM MANAJEMEN OPERASIONAL ATUR KOS
-- Skrip Kebijakan Keamanan Tingkat Tinggi (Strict Row Level Security - RBAC)
-- Menjaga Privasi & Keamanan Data Antar Pemilik dan Penghuni
-- ==============================================================================
-- Jalankan skrip ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. TABEL PROFILES (Profil Pengguna)
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Hapus kebijakan lama jika ada
DROP POLICY IF EXISTS "Authenticated users can view profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow profile updates" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- ATURAN 1: Pengguna yang sudah LOGIN (Authenticated) dapat melihat profil dalam ekosistem
-- (Diperlukan agar Pemilik dapat melihat nama calon penghuni, dan Penghuni dapat melihat pengelola)
-- Pengguna anonim dari luar (tanpa login) DITOLAK TOTAL.
CREATE POLICY "Authenticated users can view profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (true);

-- ATURAN 2: Setiap pengguna HANYA bisa mendaftarkan profil dengan ID-nya sendiri
CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- ATURAN 3: Pengguna dapat mengupdate profilnya sendiri
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ATURAN 4: Pemilik kos memiliki hak khusus untuk mengikat kost_id pada profil calon penghuni saat alokasi
CREATE POLICY "Owners can allocate kost_id to tenants"
ON public.profiles FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
);

-- -----------------------------------------------------------------------------
-- 2. TABEL KOSTS (Properti Kos)
-- -----------------------------------------------------------------------------
ALTER TABLE public.kosts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can view kosts" ON public.kosts;
DROP POLICY IF EXISTS "Only owners can update kosts" ON public.kosts;

-- Siapa pun yang login dapat melihat informasi kos (nama kos, rekening, alamat)
CREATE POLICY "Anyone authenticated can view kosts"
ON public.kosts FOR SELECT
TO authenticated
USING (true);

-- Hanya pemilik kos yang berhak mengedit data properti kos
CREATE POLICY "Only owners can update kosts"
ON public.kosts FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
);

-- -----------------------------------------------------------------------------
-- 3. TABEL ROOMS (Kamar)
-- -----------------------------------------------------------------------------
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can view rooms" ON public.rooms;
DROP POLICY IF EXISTS "Only owners can manage rooms" ON public.rooms;

-- Semua user login dapat melihat daftar kamar kosong & terisi
CREATE POLICY "Authenticated can view rooms"
ON public.rooms FOR SELECT
TO authenticated
USING (true);

-- Hanya Pemilik yang berhak menambah, mengubah status, atau menghapus kamar
CREATE POLICY "Only owners can manage rooms"
ON public.rooms FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
);

-- -----------------------------------------------------------------------------
-- 4. TABEL TENANTS (Alokasi Sewa Kamar)
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "View tenants policy" ON public.tenants;
DROP POLICY IF EXISTS "Manage tenants policy" ON public.tenants;

-- Pemilik dapat melihat semua penghuninya, DAN penghuni HANYA dapat melihat data sewanya sendiri
CREATE POLICY "View tenants policy"
ON public.tenants FOR SELECT
TO authenticated
USING (
    user_id = auth.uid() 
    OR EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
);

-- Hanya Pemilik yang dapat menambah / mengubah alokasi kamar sewa
CREATE POLICY "Manage tenants policy"
ON public.tenants FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
);

-- -----------------------------------------------------------------------------
-- 5. TABEL INVOICES (Tagihan & Keuangan)
-- -----------------------------------------------------------------------------
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "View invoices policy" ON public.invoices;
DROP POLICY IF EXISTS "Manage invoices policy" ON public.invoices;
DROP POLICY IF EXISTS "Tenants can upload proof" ON public.invoices;

-- Pemilik melihat semua tagihan kos miliknya, Penghuni HANYA melihat tagihan miliknya sendiri
-- (Mencegah penghuni A mengintip tagihan penghuni B!)
CREATE POLICY "View invoices policy"
ON public.invoices FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
    OR tenant_id IN (
        SELECT id FROM public.tenants WHERE user_id = auth.uid()
    )
);

-- Pemilik dapat menerbitkan tagihan & memverifikasi status pembayaran
CREATE POLICY "Manage invoices policy"
ON public.invoices FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'owner'
    )
);

-- Penghuni boleh mengupdate bukti transfer pembayaran pada tagihannya sendiri
CREATE POLICY "Tenants can upload proof"
ON public.invoices FOR UPDATE
TO authenticated
USING (
    tenant_id IN (
        SELECT id FROM public.tenants WHERE user_id = auth.uid()
    )
)
WITH CHECK (
    tenant_id IN (
        SELECT id FROM public.tenants WHERE user_id = auth.uid()
    )
);

-- -----------------------------------------------------------------------------
-- 6. TABEL COMPLAINTS (Helpdesk Keluhan Fasilitas)
-- -----------------------------------------------------------------------------
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "View complaints policy" ON public.complaints;
DROP POLICY IF EXISTS "Insert complaints policy" ON public.complaints;
DROP POLICY IF EXISTS "Update complaints policy" ON public.complaints;

-- Pemilik melihat semua keluhan, Penghuni melihat keluhan miliknya sendiri & fasilitas umum
CREATE POLICY "View complaints policy"
ON public.complaints FOR SELECT
TO authenticated
USING (
    tipe_fasilitas = 'fasilitas_umum'
    OR tenant_id IN (SELECT id FROM public.tenants WHERE user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'owner')
);

-- Penghuni dapat membuat laporan keluhan baru
CREATE POLICY "Insert complaints policy"
ON public.complaints FOR INSERT
TO authenticated
WITH CHECK (
    tenant_id IN (SELECT id FROM public.tenants WHERE user_id = auth.uid())
);

-- Pemilik dapat mengupdate status pengerjaan tiket keluhan
CREATE POLICY "Update complaints policy"
ON public.complaints FOR UPDATE
TO authenticated
USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'owner')
);

COMMIT;
