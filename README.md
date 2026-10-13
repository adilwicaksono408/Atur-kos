# 🏠 Atur Kos — SaaS Manajemen & Otomasi Kos Multi-Tenant

Platform manajemen hunian sewa (kost) modern yang dibangun dengan **Flutter** dan **Supabase (PostgreSQL, Auth, Storage)**. Mengadopsi arsitektur **SaaS Multi-Tenant** dengan model freemium 2-tier (*Starter* vs *Juragan*) dan portal verifikasi **Super Admin**.

---

## 📊 1. Ringkasan Status Proyek Saat Ini

* **PRD v2.0.0 & Database Migration v2:** ✅ **SELESAI & DIADOPSI (100%)**
* **Modul 1 (Autentikasi & RBAC 3 Peran: Super Admin, Pemilik, Penghuni):** ✅ **SELESAI (100%)**
* **Modul 2 (Onboarding Properti Kos, Geolocation & Dokumen Keabsahan):** ✅ **SELESAI (100%)**
* **Modul 2 (Inventaris Kamar & Alokasi Penghuni):** ✅ **SELESAI (100%)**
* **Modul 3 (Enforcement Kuota Freemium 2-Tier: Starter 5 Kamar vs Juragan 25 Kamar):** ✅ **SELESAI (100%)**
* **Modul 4 (Finansial, Tagihan & Smart Billing):** 🔄 **BERJALAN (50%)** — Tahap 1 Selesai: Penerbitan Tagihan Otomatis
* **Modul 5 (Tiket Keluhan Fasilitas):** ⏳ **MENUNGGU (0%)**
* **Modul 6 (Dashboard, Mitigasi H-30 & Poster AI):** 🔄 **BERJALAN (40%)**
* **Kondisi Kode Flutter:** 🛡️ **Stabil & Bersih** (`flutter analyze`: 0 errors, 0 warnings).

---

## 🚀 2. Rincian Pekerjaan yang Telah Diselesaikan (Completed Work)

### A. Fondasi RBAC 3 Peran & Portal Super Admin (PRD v2 Modul 1 & 2)
* **Perluasan Enum Role & Model Properti:**
  * Penambahan peran `superAdmin` pada enum `UserRole` di [`user_profile.dart`](atur_kos/lib/models/user_profile.dart).
  * Pembuatan [`kost_model.dart`](atur_kos/lib/models/kost_model.dart) mencakup koordinat geolokasi (`latitude`, `longitude`, `google_maps_url`), dokumen fisik (`dokumen_ktp_url`, `foto_bangunan_url`), status verifikasi (`KostStatus`), dan tier langganan (`SubscriptionTier`).
* **Routing Terpusat di `main.dart`:**
  * Rute otomatis mengarahkan ke `SuperAdminDashboardScreen` untuk super admin, `OwnerDashboardScreen` untuk pemilik, dan `TenantDashboardScreen` untuk penghuni.
* **Portal Super Admin ([`super_admin_dashboard_screen.dart`](atur_kos/lib/screens/admin/super_admin_dashboard_screen.dart)):**
  * Pencarian properti, filter tab status (`Semua`, `Menunggu Verifikasi`, `Aktif`, `Ditolak`, `Dibekukan`).
  * Pratinjau foto KTP pemilik & foto tampak depan bangunan kos, koordinat maps, serta tombol aksi **Setujui (Approve)**, **Tolak (Reject)** dengan catatan, dan **Bekukan (Suspend)**.

### B. Onboarding Properti Kos, Lokasi & Dokumen Keabsahan (PRD v2 Modul 2)
* **Penyederhanaan Lokasi Google Maps & GPS:**
  * Kolom utama yang ramah: **Tautan / Link Google Maps Kos** dengan tombol langsung buka pin di peta.
  * Tombol deteksi koordinat GPS 1-klik dengan proteksi *timeout* (3 detik pemeriksaan layanan, 6 detik pencarian posisi) agar tidak macet di web browser.
  * Otomatisasi ekstraksi koordinat Lat/Lng via Regex saat tautan Google Maps disimpan.
* **Upload Foto KTP & Bangunan Visual:**
  * Kartu upload visual interaktif dengan pilihan **"Ambil dari Kamera"** dan **"Buka Galeri"** menggunakan `image_picker`.
  * Thumbnail pratinjau instan di layar, indikator status kelengkapan dokumen, kompresi otomatis, dan penyimpanan Supabase Storage dengan fallback Base64 aman.
* **Alur Pengajuan Verifikasi Wajib Kos Baru:**
  * Modal dialog onboarding penyambutan pemilik baru dengan checklist dokumen (Maps, Foto Bangunan, KTP) dan tombol CTA **"Lengkapi & Ajukan Sekarang"**.
  * Banner peringatan interaktif di dasbor pemilik dengan status real-time (`pending_verification` / `rejected` / `active`).
* **Pre-fill Data Registrasi & Pencegahan Duplikasi Kode Undangan:**
  * Data Informasi Umum & Alamat Kos otomatis terisi dari pendaftaran awal pemilik baru.
  * Skrip SQL [`supabase_unique_kode_kost.sql`](supabase_unique_kode_kost.sql) dengan indeks unik case-insensitive (`UPPER(TRIM(kode_kost))`) dan validasi ketersediaan kode secara real-time di `kos_service.dart`.
* **Pembatasan Akses Fitur (*Feature Gating*) Kos Belum Terverifikasi:**
  * Seluruh fitur operasional terkunci secara visual dengan ikon gembok selama properti belum berstatus `active`.
  * Dialog instruktif *"Fitur Terkunci"* muncul jika pemilik mencoba mengakses menu operasional sebelum disetujui Super Admin.

### C. Enforcement Paket Freemium 2-Tier: Starter vs Juragan (PRD v2 Modul 3)
* **Kuota Kamar Dinamis:**
  * Progress bar kuota kamar di [`room_management_screen.dart`](atur_kos/lib/screens/owner/room_management_screen.dart).
  * Paket Starter dibatasi maksimal 5 kamar. Jika kuota penuh, tombol tambah kamar terkunci dan menampilkan modal penawaran upgrade ke Paket Juragan (s/d 25 kamar, otomasi WA reminder, dan AI poster) dengan opsi langganan Bulanan (Rp 50.000) atau Tahunan (Rp 500.000).

### D. Manajemen Kamar, Alokasi Penghuni & Tagihan Pertama (PRD Modul 2 & 3)
* **Alur Calon Penghuni Masuk:**
  * Penghuni memasukkan kode undangan di dasbor (`joinKosByInvitationCode`), akun otomatis terhubung ke properti kos.
* **Layar Alokasi Kamar ([`tenant_allocation_screen.dart`](atur_kos/lib/screens/owner/tenant_allocation_screen.dart)):**
  * Pemilik memilih calon penghuni, memilih kamar kosong, menentukan harga sewa dan siklus jatuh tempo.
  * Saat alokasi disimpan, kamar otomatis berubah status jadi terisi, kontrak tercatat di `tenants`, dan invoice perdana otomatis terbit di tabel `invoices`.

### E. Keamanan Database & Skrip Migrasi
* Kebijakan keamanan RLS granular berbasis Role: [`supabase_secure_rbac_policies.sql`](supabase_secure_rbac_policies.sql).
* Migrasi v2 multi-tenant & geolokasi: [`supabase_migration_v2.sql`](supabase_migration_v2.sql).
* Penanganan pendaftaran pemilik kos: [`supabase_fix_owner_registration.sql`](supabase_fix_owner_registration.sql).
* Pencegahan duplikasi kode kos: [`supabase_unique_kode_kost.sql`](supabase_unique_kode_kost.sql).

---

## 📁 3. File Kunci Proyek

| Kategori | File | Peran / Fungsi |
| :--- | :--- | :--- |
| **Spesifikasi** | `PRD_v2.md` | Dokumen PRD v2.0.0 (SaaS Multi-Tenant, Super Admin & Freemium 2-Tier). |
| **Database SQL** | `supabase_migration_v2.sql` | Skema DDL tabel `kosts`, geolokasi, status verifikasi, dan subscription tier. |
| **Database SQL** | `supabase_unique_kode_kost.sql` | Indeks unik case-insensitive untuk kode undangan kos. |
| **Database SQL** | `supabase_fix_owner_registration.sql` | Perbaikan alur registrasi pemilik dan pembuatan properti kos otomatis. |
| **Database SQL** | `supabase_secure_rbac_policies.sql` | Kebijakan Row Level Security (RLS) granular multi-tenant. |
| **Flutter Models** | `kost_model.dart` | Entitas data kos, geolokasi, dokumen KTP/bangunan, status, dan tier langganan. |
| **Flutter Models** | `user_profile.dart` | Model profil pengguna dengan peran Super Admin, Owner, dan Tenant. |
| **Flutter UI (Admin)** | `super_admin_dashboard_screen.dart` | Portal Super Admin: verifikasi properti, preview KTP/bangunan, aksi setujui/tolak. |
| **Flutter UI (Owner)** | `owner_dashboard_screen.dart` | Dasbor pemilik: banner verifikasi, feature gating, akses Super Admin, KPI kos. |
| **Flutter UI (Owner)** | `kos_settings_screen.dart` | Pengaturan kos: Tautan Google Maps, GPS timeout, upload foto KTP & bangunan. |
| **Flutter UI (Owner)** | `room_management_screen.dart` | Manajemen kamar & enforcement kuota freemium (5 kamar Starter vs 25 Juragan). |
| **Flutter UI (Owner)** | `tenant_allocation_screen.dart` | Alokasi kamar ke calon penghuni & penerbitan tagihan pertama otomatis. |
| **Flutter Service** | `kos_service.dart` | Operasional kos: verifikasi admin, kuota langganan, GPS koordinat, alokasi kamar. |
| **Flutter Service** | `auth_service.dart` | Layanan autentikasi Supabase, Google OAuth, registrasi peran, dan lupa sandi. |

---

## 📈 4. Pemetaan Progres Sesuai Dokumen PRD v2

```text
PRD v2 Modul 1: Autentikasi & RBAC (3 Roles)  [████████████████████] 100% (SELESAI)
PRD v2 Modul 2: Onboarding Kos & Verifikasi   [████████████████████] 100% (SELESAI)
PRD v2 Modul 2: Inventaris & Alokasi Kamar    [████████████████████] 100% (SELESAI)
PRD v2 Modul 3: Kuota Freemium (2-Tier)       [████████████████████] 100% (SELESAI)
PRD v2 Modul 4: Smart Billing & Pembayaran    [██████████░░░░░░░░░░]  50% (BERJALAN)
PRD v2 Modul 5: Sistem Tiket Keluhan          [░░░░░░░░░░░░░░░░░░░░]   0% (MENUNGGU)
PRD v2 Modul 6: Dashboard & Poster AI         [████████░░░░░░░░░░░░]  40% (BERJALAN)
```

---

## 🎯 5. Roadmap Langkah Selanjutnya (Next Steps)

* **Modul 4: Integrasi Payment Gateway Midtrans (US-4.1 s/d US-4.3)**
  * Menampilkan rincian tagihan sewa dan tombol bayar instan di akun penghuni.
  * Integrasi Midtrans Snap (QRIS & Virtual Account) dan simulasi webhook settlement.
  * Penerbitan Kuitansi Digital ber-QR Code verifikasi anti-manipulasi dan sinkronisasi kas masuk.
* **Modul 5: Sistem Tiket Keluhan Kerusakan Fasilitas (US-5.1 & US-5.2)**
  * Pelaporan komplain kamar pribadi dan fasilitas umum beserta foto bukti.
  * Alur penanganan status perbaikan oleh pemilik kos.
* **Modul 6: Otomasi Reminder WhatsApp & Radar H-30 (US-6.1 & US-6.2)**
  * Notifikasi pengingat jatuh tempo sewa ke nomor WhatsApp penghuni.
  * Formulir komitmen perpanjangan sewa H-30 dan mitigasi kamar kosong.

---

## 🛠️ Cara Menjalankan Aplikasi

1. Masuk ke direktori aplikasi Flutter:
   ```bash
   cd atur_kos
   ```
2. Pastikan dependensi sinkron:
   ```bash
   flutter pub get
   ```
3. Jalankan aplikasi ke perangkat terhubung:
   ```bash
   flutter run
   ```
