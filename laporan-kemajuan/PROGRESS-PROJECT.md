# Matriks Kemajuan Project: Platform SaaS Multi-Tenant Atur Kos

**Nama Aplikasi:** Atur Kos (Platform Operasional, Otomasi & SaaS Multi-Tenant Manajemen Kos)  
**Tech Stack:** Flutter, Supabase (PostgreSQL 15+, Auth, Storage, RLS), Midtrans Snap & Webhook  
**Dokumen Acuan:** [PRD_v2.md](file:///d:/Atur%20kos/PRD_v2.md) & [supabase_migration_v2.sql](file:///d:/Atur%20kos/supabase_migration_v2.sql)

---

## 📊 Ringkasan Status Keseluruhan (PRD v2.0.0)

| Modul | Status | Persentase | Terakhir Diperbarui |
| :--- | :---: | :---: | :---: |
| **Fondasi Database & Migrasi v2.0.0** | Selesai | 100% | 11 Oktober 2026 |
| **Modul 1: Autentikasi, Multi-Tenancy & RBAC (3 Role)** | Selesai | 100% | 11 Oktober 2026 |
| **Modul 2: Super Admin Portal & Verifikasi Properti** | Selesai | 100% | 11 Oktober 2026 |
| **Modul 3: Manajemen Kamar & Kuota Freemium 2-Tier** | Selesai | 100% | 11 Oktober 2026 |
| **Modul 4: Smart Billing, Midtrans Gateway & Kuitansi QR** | Selesai | 100% | 15 Oktober 2026 |
| **Modul 5: WhatsApp Notification Engine (Anti-Ban)** | Menunggu | 0% | - |
| **Modul 6: Helpdesk Kerusakan Fasilitas** | Menunggu | 0% | - |
| **Modul 7: Mitigasi H-30 & Poster AI Marketing** | In Progress | 40% | 11 Oktober 2026 |
| **Modul 8: Pembukuan Arus Kas (Cash Ledger)** | In Progress | 40% | 11 Oktober 2026 |
| **Modul 9: Papan Pengumuman & Paket Kurir (FCM)** | Menunggu | 0% | - |

---

## 🛠️ Rincian Status per Modul

### 0. Fondasi Database & Migrasi v2.0.0
- [x] Migrasi non-destruktif `supabase_migration_v2.sql`
- [x] Enum baru: `user_role` (`super_admin`), `kost_status`, `subscription_tier`, `invoice_status` (`kedaluwarsa`, `batal`)
- [x] Trigger PostgreSQL `trg_check_room_quota` untuk pembatasan kuota kamar otomatis

### 1. Modul 1: Autentikasi, Multi-Tenancy & RBAC 3 Tingkatan (100% Selesai)
- [x] Enum `UserRole` (`superAdmin`, `owner`, `tenant`) di [user_profile.dart](file:///d:/Atur%20kos/atur_kos/lib/models/user_profile.dart)
- [x] Rute terpusat dinamis berbasis peran di [main.dart](file:///d:/Atur%20kos/atur_kos/lib/main.dart)
- [x] Reset password, konfirmasi email, Google OAuth

### 2. Modul 2: Onboarding Properti, Dual-Mode Geolocation & Verifikasi Super Admin (100% Selesai)
- [x] Dasbor terdedikasi Super Admin di [super_admin_dashboard_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/admin/super_admin_dashboard_screen.dart)
- [x] Validasi fisik bangunan, dokumen KTP, dan koordinat maps
- [x] Aksi Setujui (*Approve*), Tolak (*Reject*), dan Bekukan (*Suspend*)
- [x] Banner status verifikasi dinamis pada dasbor pemilik
- [x] Dual-Mode Location Picker di [kos_settings_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/owner/kos_settings_screen.dart):
  - [x] Opsi A: Deteksi GPS 1-klik otomatis via `geolocator`
  - [x] Opsi B: Koordinat manual & tombol verifikasi Google Maps via `url_launcher`
  - [x] Penanganan fallback saat izin GPS ditolak
- [x] Upload & pratinjau berkas KTP pemilik dan foto fisik tampak depan kos

### 3. Modul 3: Manajemen Kamar & Kuota Freemium 2-Tier (100% Selesai)
- [x] Kartu kuota & progress bar kamar di [room_management_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/owner/room_management_screen.dart)
- [x] Interseptor kuota kamar: Paket Starter (maks 5 kamar) vs Juragan (s/d 25 kamar)
- [x] Dialog Upgrade Paket Juragan (Opsi Bulanan Rp 50rb vs Tahunan Rp 500rb)
- [x] Logika alokasi kamar & kode undangan kos dinamis

### 4. Modul 4: Smart Billing, Midtrans Gateway & Kuitansi QR (100% Selesai)
- [x] Penerbitan invoice otomatis perdana dengan order_id unik
- [x] Integrasi Midtrans Snap Pemilik (Upgrade Juragan via QRIS & 7 Virtual Account)
- [x] Integrasi Midtrans Snap Penghuni (Pelunasan sewa bulanan dengan live timer 24 jam)
- [x] Penerbitan Kuitansi Sah Digital ber-QR Code fisik nyata ISO/IEC 18004 anti-manipulasi
- [x] Layar Verifikasi Publik Kuitansi Bebas Login ([public_receipt_verification_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/payment/public_receipt_verification_screen.dart)) dengan chip uji demo 1-klik, scanner link, stempel validitas resmi, dan salin ke WhatsApp
- [x] Integrasi akses verifikasi publik di footer [welcome_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/auth/welcome_screen.dart), modal kuitansi penghuni, dan dasbor tagihan pemilik
- [x] SQL Migration RPC `verify_receipt_public` dengan `SECURITY DEFINER` untuk publik anonim ([supabase_verify_receipt_rpc.sql](file:///d:/Atur%20kos/supabase_verify_receipt_rpc.sql))
- [x] Sinkronisasi otomatis status invoice & buku kas masuk `cash_ledgers` seketika saat lunas
- [x] Akses Kuitansi Digital ber-QR Code & integrasi WhatsApp bagi Pemilik Kos
- [x] Portal Audit Transaksi Midtrans & Langganan SaaS B2B untuk Super Admin (MRR, ARR, Konversi, Simulator Sandbox, Ekspor Bab IV)
- [x] Simulasi alur webhook settlement Midtrans teruji end-to-end dengan integritas data Supabase riil

### 5. Modul 5-9: Otomasi Lanjutan (Dalam Antrean Sprint)
- [ ] Modul 5: WhatsApp Reminder Berjenjang (Anti-Ban Jitter 5-10s)
- [ ] Modul 6: Tiket Keluhan Kerusakan (Kamar Pribadi & Umum + Multi-Foto)
- [x] Modul 7: Generator Poster Kamar Kosong AI (1:1 Feed & 9:16 Story)
- [x] Modul 7: Backend Supabase Edge Function AI Image-to-Image (`generate-room-variation`)
- [x] Modul 7: Skema Database Kuota AI Bulanan & Bucket Storage (`supabase_ai_poster_quota.sql`)
- [x] Modul 7: Deteksi Sisa Sewa 30 Hari (Radar Mitigasi H-30)
- [x] Modul 7: AI Natural Touch-up & Real-Lighting (100% foto asli kamar tanpa manipulasi fiktif/dilebih-lebihkan)
- [ ] Modul 8: Ekspor Rekap Buku Kas (Excel / PDF)
- [ ] Modul 9: Pengumuman Paket Kurir Tiba Terarah via FCM

