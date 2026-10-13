# 🏠 Atur Kos — SaaS Manajemen & Otomasi Kos Multi-Tenant

Platform manajemen hunian sewa (kost) modern yang dibangun dengan **Flutter** dan **Supabase (PostgreSQL, Auth, Storage)**. Mengadopsi arsitektur **SaaS Multi-Tenant** dengan model freemium 2-tier (*Starter* vs *Juragan*) dan portal verifikasi **Super Admin**.

---

## 📊 1. Ringkasan Status Proyek Saat Ini

* **PRD v2.0.0 & Database Migration v2:** ✅ **SELESAI & DIADOPSI (100%)**
* **Modul 1 (Autentikasi & RBAC 3 Peran: Super Admin, Pemilik, Penghuni):** ✅ **SELESAI (100%)**
* **Modul 2 (Onboarding Properti Kos, Geolocation & Dokumen Keabsahan):** ✅ **SELESAI (100%)**
* **Modul 2 (Inventaris Kamar & Alokasi Penghuni):** ✅ **SELESAI (100%)**
* **Modul 3 (Enforcement Kuota Freemium 2-Tier: Starter 5 Kamar vs Juragan 50 Kamar):** ✅ **SELESAI (100%)**
* **Modul 4 (Payment Gateway Midtrans Snap: Langganan Pemilik ke Super Admin):** ✅ **SELESAI (85%)**
* **Modul 5 (Tiket Keluhan Fasilitas):** ⏳ **MENUNGGU (0%)**
* **Modul 6 (Dashboard, Mitigasi H-30 & Generator Poster Kamar):** 🔄 **BERJALAN (75%)**
* **Kondisi Kode Flutter:** 🛡️ **Stabil & Bersih** (`flutter analyze`: 0 errors, 0 warnings).

---

## 🚀 2. Rincian Pekerjaan yang Telah Diselesaikan (Completed Work)

### A. Integrasi Payment Gateway Midtrans Snap (PRD v2 Modul 4 & 10)
* **Modal Dialog Midtrans Snap Sandbox ([`midtrans_snap_payment_dialog.dart`](atur_kos/lib/screens/payment/midtrans_snap_payment_dialog.dart)):**
  * Alur pembayaran uji coba resmi Midtrans Snap untuk upgrade paket langganan Pemilik ke Super Admin (Starter -> Juragan).
  * Pilihan durasi fleksibel (1 s/d 12 bulan) dengan kalkulasi diskon otomatis.
  * Metode pembayaran lengkap: **QRIS Dinamis (GoPay/ShopeePay/BCA/Dana)** dan **Virtual Account Bank (BCA, Mandiri, BNI, BRI, Permata, CIMB Niaga)**.
  * *Ticking countdown timer* 24 jam real-time dengan status expired otomatis jika waktu habis.
  * Fitur salin nomor VA, unduh QRIS, simulator pembayaran instan Midtrans Sandbox, dan pembatalan transaksi aman.
  * Mutasi database Supabase seketika saat sukses: properti kos otomatis naik ke tier `juragan`, kuota naik ke `50` kamar, dan masa aktif `subscription_expires_at` diperpanjang otomatis.

### B. Fondasi RBAC 3 Peran & Portal Super Admin (PRD v2 Modul 1 & 2)
* **Perluasan Enum Role & Model Properti:**
  * Penambahan peran `superAdmin` pada enum `UserRole` di [`user_profile.dart`](atur_kos/lib/models/user_profile.dart).
  * Pembuatan [`kost_model.dart`](atur_kos/lib/models/kost_model.dart) mencakup koordinat geolokasi (`latitude`, `longitude`, `google_maps_url`), dokumen fisik (`dokumen_ktp_url`, `foto_bangunan_url`), status verifikasi (`KostStatus`), dan tier langganan (`SubscriptionTier`) dengan fungsi `copyWith`.
* **Routing Terpusat di `main.dart`:**
  * Rute otomatis mengarahkan ke `SuperAdminDashboardScreen` untuk super admin, `OwnerDashboardScreen` untuk pemilik, dan `TenantDashboardScreen` untuk penghuni.
* **Portal Super Admin ([`super_admin_dashboard_screen.dart`](atur_kos/lib/screens/admin/super_admin_dashboard_screen.dart)):**
  * Pencarian properti, filter tab status (`Semua`, `Menunggu Verifikasi`, `Aktif`, `Ditolak / Dibekukan`).
  * Pratinjau foto KTP pemilik & foto tampak depan bangunan kos, koordinat maps, serta tombol aksi **Setujui (Approve)**, **Tolak (Reject)** dengan catatan, dan **Bekukan (Suspend)**.
  * *Optimistic UI & Auto-Switch Tab*: Status kos langsung ter-update di antarmuka dan otomatis berpindah ke tab tujuan dengan notifikasi sukses instan.
* **Isolasi Akun Super Admin & Perbaikan Kebijakan RLS Supabase:**
  * [`supabase_rbac_super_admin_fix.sql`](supabase_rbac_super_admin_fix.sql): Memberikan izin RLS Postgres bagi Super Admin untuk memverifikasi, mengubah, dan menghapus kos apapun.
  * [`supabase_isolate_super_admin.sql`](supabase_isolate_super_admin.sql): Mengisolasi akun Super Admin (`wicaksonoadil768@gmail.com`) dengan `kost_id = NULL` dan membersihkan rekaman sewa uji coba di tabel `tenants`.
  * Pengetatan query di [`kos_service.dart`](atur_kos/lib/services/kos_service.dart) dan [`tenant_allocation_screen.dart`](atur_kos/lib/screens/owner/tenant_allocation_screen.dart) menggunakan `.eq('role', 'tenant')` sehingga Super Admin tidak akan pernah bocor ke daftar calon penghuni kos.

### C. Onboarding Properti Kos, Lokasi & Dokumen Keabsahan (PRD v2 Modul 2)
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

### D. Enforcement Paket Freemium 2-Tier & Generator Poster Kamar (PRD v2 Modul 3 & 6)
* **Kuota Kamar Dinamis & Tombol Upgrade Langsung:**
  * Progress bar kuota kamar di [`room_management_screen.dart`](atur_kos/lib/screens/owner/room_management_screen.dart).
  * Paket Starter dibatasi maksimal 5 kamar. Jika kuota penuh, tombol tambah kamar terkunci dan membuka modal pembayaran Midtrans Snap untuk upgrade instan ke Paket Juragan.
* **Generator Poster Kamar Siap Huni ([`room_poster_generator_screen.dart`](atur_kos/lib/screens/owner/room_poster_generator_screen.dart)):**
  * Desain template poster kamar kosong modern dengan foto kamar, harga, fasilitas, nomor kontak WhatsApp, dan QR code / kode undangan kos untuk media sosial.

### E. Manajemen Kamar, Alokasi Penghuni & Tagihan Pertama (PRD Modul 2 & 3)
* **Alur Calon Penghuni Masuk:**
  * Penghuni memasukkan kode undangan di dasbor (`joinKosByInvitationCode`), akun otomatis terhubung ke properti kos.
* **Layar Alokasi Kamar ([`tenant_allocation_screen.dart`](atur_kos/lib/screens/owner/tenant_allocation_screen.dart)):**
  * Pemilik memilih calon penghuni, memilih kamar kosong, menentukan harga sewa dan siklus jatuh tempo.
  * Saat alokasi disimpan, kamar otomatis berubah status jadi terisi, kontrak tercatat di `tenants`, dan invoice perdana otomatis terbit di tabel `invoices`.

### F. Keamanan Database & Skrip Migrasi
* Kebijakan RLS Super Admin & Pemilik: [`supabase_rbac_super_admin_fix.sql`](supabase_rbac_super_admin_fix.sql).
* Isolasi akun platform Super Admin: [`supabase_isolate_super_admin.sql`](supabase_isolate_super_admin.sql).
* Kebijakan keamanan RLS granular berbasis Role: [`supabase_secure_rbac_policies.sql`](supabase_secure_rbac_policies.sql).
* Migrasi v2 multi-tenant & geolokasi: [`supabase_migration_v2.sql`](supabase_migration_v2.sql).
* Penanganan pendaftaran pemilik kos: [`supabase_fix_owner_registration.sql`](supabase_fix_owner_registration.sql).
* Pencegahan duplikasi kode kos: [`supabase_unique_kode_kost.sql`](supabase_unique_kode_kost.sql).

---

## 📁 3. File Kunci Proyek

| Kategori | File | Peran / Fungsi |
| :--- | :--- | :--- |
| **Spesifikasi** | `PRD_v2.md` | Dokumen PRD v2.0.0 (SaaS Multi-Tenant, Super Admin & Freemium 2-Tier). |
| **Payment UI** | `midtrans_snap_payment_dialog.dart` | Dialog modal pembayaran Midtrans Snap (QRIS, VA Bank, Sandbox simulator, auto-tier update). |
| **Database SQL** | `supabase_rbac_super_admin_fix.sql` | Kebijakan izin RLS Super Admin untuk menyetujui, menolak, membekukan, dan menghapus kos. |
| **Database SQL** | `supabase_isolate_super_admin.sql` | Isolasi peran Super Admin, pengosongan kost_id, dan pembersihan alokasi tenant yang salah. |
| **Database SQL** | `supabase_migration_v2.sql` | Skema DDL tabel `kosts`, geolokasi, status verifikasi, dan subscription tier. |
| **Database SQL** | `supabase_unique_kode_kost.sql` | Indeks unik case-insensitive untuk kode undangan kos. |
| **Database SQL** | `supabase_fix_owner_registration.sql` | Perbaikan alur registrasi pemilik dan pembuatan properti kos otomatis. |
| **Flutter Models** | `kost_model.dart` | Entitas data kos, geolokasi, dokumen KTP/bangunan, status, tier langganan, dan helper copyWith. |
| **Flutter Models** | `user_profile.dart` | Model profil pengguna dengan peran Super Admin, Owner, dan Tenant. |
| **Flutter UI (Admin)** | `super_admin_dashboard_screen.dart` | Portal Super Admin: verifikasi properti, preview KTP/bangunan, optimistic UI aksi setujui/tolak. |
| **Flutter UI (Owner)** | `owner_dashboard_screen.dart` | Dasbor pemilik: banner verifikasi, feature gating, akses Super Admin, KPI kos, upgrade tier. |
| **Flutter UI (Owner)** | `kos_settings_screen.dart` | Pengaturan kos: Tautan Google Maps, GPS timeout, upload foto KTP & bangunan. |
| **Flutter UI (Owner)** | `room_management_screen.dart` | Manajemen kamar & enforcement kuota freemium dengan trigger langsung ke Midtrans Snap. |
| **Flutter UI (Owner)** | `room_poster_generator_screen.dart` | Pembuat poster promosi kamar kosong siap huni ber-QR code dan kontak pengelola. |
| **Flutter UI (Owner)** | `tenant_allocation_screen.dart` | Alokasi kamar ke calon penghuni dengan proteksi ketat isolasi akun Super Admin. |
| **Flutter Service** | `kos_service.dart` | Operasional kos: verifikasi admin, kuota langganan, GPS koordinat, alokasi kamar strictly role 'tenant'. |
| **Flutter Service** | `auth_service.dart` | Layanan autentikasi Supabase, Google OAuth, registrasi peran, dan lupa sandi. |

---

## 📈 4. Pemetaan Progres Sesuai Dokumen PRD v2

```text
PRD v2 Modul 1: Autentikasi & RBAC (3 Roles)  [████████████████████] 100% (SELESAI)
PRD v2 Modul 2: Onboarding Kos & Verifikasi   [████████████████████] 100% (SELESAI)
PRD v2 Modul 2: Inventaris & Alokasi Kamar    [████████████████████] 100% (SELESAI)
PRD v2 Modul 3: Kuota Freemium (2-Tier)       [████████████████████] 100% (SELESAI)
PRD v2 Modul 4: Smart Billing & Payment Snap  [█████████████████░░░]  85% (BERJALAN)
PRD v2 Modul 5: Sistem Tiket Keluhan          [░░░░░░░░░░░░░░░░░░░░]   0% (MENUNGGU)
PRD v2 Modul 6: Dashboard & Poster Kamar      [███████████████░░░░░]  75% (BERJALAN)
```

---

## 🎯 5. Roadmap Langkah Selanjutnya (Next Steps)

* **Modul 4: Integrasi Tagihan Penghuni & Webhook Midtrans (US-4.1 s/d US-4.3)**
  * Menampilkan rincian tagihan sewa bulanan dan tombol bayar instan di akun penghuni.
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
