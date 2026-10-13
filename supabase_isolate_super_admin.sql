-- ==============================================================================
-- SISTEM ISOLASI ROLE SUPER ADMIN ATUR KOS
-- File: supabase_isolate_super_admin.sql
-- ==============================================================================
-- Tujuan:
-- 1. Memastikan akun Super Admin (wicaksonoadil768@gmail.com) memiliki role 'super_admin'.
-- 2. Mengosongkan kolom 'kost_id' pada akun Super Admin agar tidak terikat ke kos manapun.
-- 3. Menghapus data sewa palsu/uji coba di tabel 'tenants' jika akun Super Admin sempat teralokasi ke kamar.
-- 4. Memastikan akun Super Admin tidak pernah muncul di daftar "Calon Penghuni" maupun "Penghuni Aktif" pemilik kos manapun.
-- ==============================================================================

BEGIN;

-- 1. Update profil akun Super Admin: set role ke 'super_admin' dan kosongkan kost_id
UPDATE public.profiles
SET 
    role = 'super_admin',
    kost_id = NULL,
    updated_at = NOW()
WHERE id IN (
    SELECT id FROM auth.users WHERE LOWER(email) = 'wicaksonoadil768@gmail.com'
);

-- 2. Hapus dari tabel penghuni kamar (tenants) jika sempat dialokasikan secara tidak sengaja
DELETE FROM public.tenants
WHERE user_id IN (
    SELECT id FROM auth.users WHERE LOWER(email) = 'wicaksonoadil768@gmail.com'
);

-- 3. Sinkronisasi metadata role di tabel auth.users
UPDATE auth.users
SET raw_user_meta_data = jsonb_set(
    COALESCE(raw_user_meta_data, '{}'::jsonb),
    '{role}',
    '"super_admin"'
)
WHERE LOWER(email) = 'wicaksonoadil768@gmail.com';

COMMIT;
