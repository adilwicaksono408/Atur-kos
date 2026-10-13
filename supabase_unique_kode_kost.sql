-- ==============================================================================
-- ATUR KOS: UNIQUE CONSTRAINT INDEX KODE KOS (MENCEGAH KODE UNDANGAN GANDA)
-- ==============================================================================
-- Skrip ini memastikan tidak ada dua kos yang memiliki kode undangan sama (case-insensitive).
-- ==============================================================================

-- 1. Buat Unique Index pada kode_kost (case-insensitive)
CREATE UNIQUE INDEX IF NOT EXISTS idx_kosts_kode_kost_unique 
ON public.kosts (UPPER(TRIM(kode_kost))) 
WHERE kode_kost IS NOT NULL AND kode_kost <> '';

-- 2. Verifikasi status index
COMMENT ON INDEX public.idx_kosts_kode_kost_unique IS 'Mencegah duplikasi kode undangan antar pemilik kos di seluruh sistem Atur Kos.';
