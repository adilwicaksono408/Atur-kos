-- ==============================================================================
-- SISTEM MANAJEMEN OPERASIONAL ATUR KOS
-- Skrip Izin RLS Super Admin (Verifikasi Properti & Tata Kelola SaaS)
-- ==============================================================================
-- Masalah yang diselesaikan:
-- Sebelumnya tabel 'kosts' hanya mengizinkan role 'owner' untuk UPDATE.
-- Ketika Super Admin (role = 'super_admin') klik Setujui/Tolak/Bekukan, query
-- UPDATE ditolak oleh RLS Supabase sehingga status kos tidak berubah.
-- ==============================================================================

BEGIN;

-- 1. Berikan Izin SELECT, UPDATE, ALL pada tabel KOSTS untuk Super Admin & Pemilik
DROP POLICY IF EXISTS "Only owners can update kosts" ON public.kosts;
DROP POLICY IF EXISTS "Super admin and owners can update kosts" ON public.kosts;
DROP POLICY IF EXISTS "Super admin can manage all kosts" ON public.kosts;

CREATE POLICY "Super admin and owners can update kosts"
ON public.kosts FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND (p.role = 'owner' OR p.role = 'super_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND (p.role = 'owner' OR p.role = 'super_admin')
    )
);

CREATE POLICY "Super admin can delete kosts"
ON public.kosts FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'super_admin'
    )
);

-- 2. Pastikan akun Super Admin Anda (wicaksonoadil768@gmail.com) memiliki role 'super_admin'
UPDATE public.profiles
SET role = 'super_admin', updated_at = NOW()
WHERE id IN (
    SELECT id FROM auth.users WHERE LOWER(email) = 'wicaksonoadil768@gmail.com'
);

COMMIT;
