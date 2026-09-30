-- ==============================================================================
-- SISTEM MANAJEMEN OPERASIONAL & OTOMASI KOS PRINCESS
-- Skrip Rollback (Mengembalikan Database ke Kondisi Awal: Hanya profiles bawaan)
-- ==============================================================================

BEGIN;

-- 1. Hapus Trigger & Function Auth
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 2. Hapus Tabel Bisnis (Berurutan / CASCADE)
DROP TABLE IF EXISTS public.announcements CASCADE;
DROP TABLE IF EXISTS public.cash_ledgers CASCADE;
DROP TABLE IF EXISTS public.complaints CASCADE;
DROP TABLE IF EXISTS public.notification_logs CASCADE;
DROP TABLE IF EXISTS public.invoices CASCADE;
DROP TABLE IF EXISTS public.tenants CASCADE;
DROP TABLE IF EXISTS public.rooms CASCADE;
DROP TABLE IF EXISTS public.kosts CASCADE;

-- 3. Bersihkan Kolom Tambahan dari Tabel profiles (Kembalikan ke struktur awal)
ALTER TABLE public.profiles DROP COLUMN IF EXISTS kost_id;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS nomor_wa;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS role;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS fcm_token;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS updated_at;

-- 4. Hapus Index Tambahan pada profiles
DROP INDEX IF EXISTS public.idx_profiles_kost_id;
DROP INDEX IF EXISTS public.idx_profiles_role;

-- 5. Hapus ENUM Types
DROP TYPE IF EXISTS public.announcement_category CASCADE;
DROP TYPE IF EXISTS public.cash_flow_type CASCADE;
DROP TYPE IF EXISTS public.complaint_status CASCADE;
DROP TYPE IF EXISTS public.complaint_scope CASCADE;
DROP TYPE IF EXISTS public.invoice_status CASCADE;
DROP TYPE IF EXISTS public.tenant_status CASCADE;
DROP TYPE IF EXISTS public.room_status CASCADE;
DROP TYPE IF EXISTS public.user_role CASCADE;

COMMIT;
