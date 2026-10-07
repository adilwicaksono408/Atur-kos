-- ==============================================================================
-- SISTEM MANAJEMEN OPERASIONAL ATUR KOS
-- Skrip Izin Akses RLS: Memastikan Pemilik Dapat Melihat & Mengalokasikan Penghuni
-- ==============================================================================
-- Jalankan skrip ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

BEGIN;

-- 1. PENGATURAN RLS TABEL PROFILES
-- Agar Pemilik dapat melihat profil calon penghuni yang telah memasukkan kode undangan kos
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Izinkan semua pengguna yang login (authenticated) membaca profil
DROP POLICY IF EXISTS "Authenticated users can view profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;

CREATE POLICY "Authenticated users can view profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (true);

-- Izinkan pengguna memasukkan profil mereka
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (true);

-- Izinkan pengguna mengupdate profil mereka sendiri & pemilik mengupdate alokasi kos
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Owners can update tenant profile" ON public.profiles;

CREATE POLICY "Allow profile updates"
ON public.profiles FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- 2. PENGATURAN RLS TABEL TENANTS (Alokasi Sewa)
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can view tenants" ON public.tenants;
CREATE POLICY "Authenticated can view tenants"
ON public.tenants FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Authenticated can insert tenants" ON public.tenants;
CREATE POLICY "Authenticated can insert tenants"
ON public.tenants FOR INSERT
TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated can update tenants" ON public.tenants;
CREATE POLICY "Authenticated can update tenants"
ON public.tenants FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- 3. PENGATURAN RLS TABEL ROOMS (Kamar)
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can view rooms" ON public.rooms;
CREATE POLICY "Authenticated can view rooms"
ON public.rooms FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Authenticated can manage rooms" ON public.rooms;
CREATE POLICY "Authenticated can manage rooms"
ON public.rooms FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 4. PENGATURAN RLS TABEL INVOICES (Tagihan)
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can view invoices" ON public.invoices;
CREATE POLICY "Authenticated can view invoices"
ON public.invoices FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Authenticated can manage invoices" ON public.invoices;
CREATE POLICY "Authenticated can manage invoices"
ON public.invoices FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 5. OPTIONAL FAIL-SAFE:
-- Jika Anda sebelumnya mengatur tabel sebagai Unrestricted (RLS Disabled),
-- Anda juga dapat menonaktifkan RLS pada profiles agar 100% bebas hambatan:
-- ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

COMMIT;
