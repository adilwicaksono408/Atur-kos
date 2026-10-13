# Logbook Harian Kemajuan Project & Skripsi

Dokumen ini mencatat kronologis capaian konkret per hari.  
Setiap entri harian berisi **hasil nyata (deliverables)** yang selesai dikerjakan, bukan rencana atau kegiatan belajar.

---

## 📅 Selasa, 22 September 2026 (Inisialisasi & Setup Sistem Laporan)

### 1. Kemajuan Project (Kos Princess)
* **Capaian:**
  * Peninjauan menyeluruh dokumen spesifikasi kebutuhan sistem ([PRD.md](file:///d:/Kos%20Princess/PRD.md)) dengan 5 modul utama.
  * Audit fondasi kode dasar aplikasi pada repositori [login-supabase-app](file:///d:/Kos%20Princess/login-supabase-app): fitur autentikasi (email & Google OAuth) dan integrasi awal Supabase SSR.
  * Pembentukan struktur pemantauan progres berkala (`laporan-kemajuan/`).
* **Bukti/Artefak:**
  * Repositori Next.js terkonfigurasi dengan Supabase Auth.
  * Dokumen PRD v1.0.0 siap eksekusi.

### 2. Kemajuan Skripsi
* **Capaian:**
  * Penyusunan matriks pemetaan kebutuhan fungsional (FR) dan non-fungsional (NFR) untuk bahan Bab 3 (Analisis Kebutuhan).
  * Penentuan daftar diagram perancangan sistem yang wajib dibuat: Use Case, Activity, Sequence, dan ERD.
* **Bukti/Artefak:**
  * Matriks bab skripsi di [PROGRESS-SKRIPSI.md](file:///d:/Kos%20Princess/laporan-kemajuan/PROGRESS-SKRIPSI.md).

### 3. Komitmen Output Besok (Rabu, 23 September 2026)
* **Project:** Pembuatan skrip DDL SQL skema database PostgreSQL Supabase (5 tabel: `profiles`, `rooms`, `tenants`, `invoices`, `complaints`) beserta Row Level Security (RLS) policies.
* **Skripsi:** Penulisan Bab 3 Subbab 3.3 (Perancangan Basis Data: ERD fisik & kamus data atribut tabel).

---

## 📅 Senin, 6 Oktober 2026 (Modul 1 & 2 Selesai, Keamanan RLS & Tahap 1 Finansial)

### 1. Kemajuan Project (Atur Kos)
* **Ringkasan Status:**
  * Modul 1 (Autentikasi & RBAC): **SELESAI (100%)**
  * Modul 2 (Manajemen Kamar & Alokasi Penghuni): **SELESAI (100%)**
  * Modul 3 (Finansial, Tagihan & Pembayaran): **BERJALAN** (Tahap 1 Selesai: Penerbitan Tagihan Otomatis)
  * Kondisi Kode Flutter: **Stabil & Bersih** (`flutter analyze`: 0 error, 0 warning)

* **Rincian Capaian:**
  * **A. Pembenahan Autentikasi & Akun Pengguna (PRD Modul 1):**
    * Fitur Lupa Kata Sandi (*Forgot Password*): Alur kirim email reset sandi di `forgot_password_screen.dart` dan penanganan token tautan reset di `reset_password_screen.dart`.
    * Konfirmasi Email Registrasi: Penanganan registrasi baru di `register_screen.dart` disesuaikan menampilkan instruksi verifikasi email saat fitur Email Confirmation Supabase aktif.
    * Pembersihan Mode Pengguna & Personalisasi UI: Menghapus tombol toggle manual "Beralih Mode Pemilik / Penghuni" demi kepatuhan RBAC (*Role-Based Access Control*) murni. Menghilangkan data dummy "BU RINA BU RINA" dan menambahkan ucapan personal nama pengguna dinamis ("Halo, [Nama Pengguna]") di dasbor Pemilik dan Penghuni.
    * Perbaikan Error Layout & Backend: Memperbaiki bug `RenderFlex overflowed` (104px, 195px, 128px) pada antarmuka autentikasi web, serta mengatasi HTTP 500 (*Database error saving new user*) saat pendaftaran.
  * **B. Kode Undangan & Alokasi Kamar (PRD Modul 2 - US-2.2):**
    * Kode Undangan Properti Kos Dinamis: Pemilik memiliki kode undangan kos nyata (misal `PRINCESS` atau kombinasi nama kos + angka unik), dengan fitur salin ke clipboard dan bagikan ke WhatsApp calon penghuni.
    * Alur Masuk Penghuni: Calon penghuni memasukkan kode undangan di dasbor (`joinKosByInvitationCode`), akun otomatis terhubung ke properti kos (`profiles.kost_id`).
    * Layar Alokasi Kamar Pemilik (`tenant_allocation_screen.dart`): Menampilkan calon penghuni yang menunggu alokasi, pemilihan kamar kosong, penentuan harga sewa kesepakatan, dan siklus jatuh tempo.
    * Otomasi Tagihan Pertama: Saat alokasi disimpan, status kamar menjadi terisi, data sewa tercatat di `tenants`, dan tagihan sewa perdana otomatis terbit di tabel `invoices`.
  * **C. Keamanan Database & Penyelesaian Isu Nama "Fatimah":**
    * Evaluasi Keamanan RLS Supabase: Menetapkan arsitektur keamanan ketat melalui `supabase_secure_rbac_policies.sql` untuk mengisolasi data keuangan, bukti bayar, dan kamar antarpenghuni.
    * Perbaikan Sinkronisasi Nama Calon Penghuni: Mengatasi masalah nama calon penghuni tampil sebagai "Calon Penghuni" padahal di database bernama Fatimah dengan perbaikan pembacaan data di `kos_service.dart`, `tenant_allocation_screen.dart`, dan `auth_service.dart` serta skrip `supabase_sync_candidate_names.sql`.

* **Bukti/Artefak:**
  * File SQL: `supabase_secure_rbac_policies.sql`, `supabase_sync_candidate_names.sql`, `supabase_fix_rls_tenants.sql`, `supabase_fix_signup.sql`
  * File Flutter: `tenant_allocation_screen.dart`, `tenant_dashboard_screen.dart`, `owner_dashboard_screen.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart`, `kos_service.dart`, `auth_service.dart`, `format_utils.dart`

### 2. Kemajuan Skripsi
* **Capaian:**
  * Penyusunan laporan implementasi arsitektur keamanan basis data Supabase PostgreSQL dengan *Row Level Security* (RLS).
  * Validasi alur logika alokasi multi-tenant kamar dan otomasi penagihan pertama untuk dokumentasi Bab 4 (Implementasi dan Pengujian).

### 3. Komitmen Output Selanjutnya (Roadmap PRD)
* **Modul 3:** Alur pembayaran & verifikasi bukti transfer (US-3.2 & US-3.3) serta reminder WhatsApp (US-3.4).
* **Modul 4:** Sistem tiket keluhan/komplain fasilitas dengan foto (US-4.1 & US-4.2).
* **Modul 5:** Papan pengumuman digital & ekspor laporan keuangan (US-5.1 & US-5.5).

---

## 📅 Minggu, 11 Oktober 2026 (Migrasi PRD v2 SaaS Multi-Tenant: Super Admin & Freemium 2-Tier)

### 1. Kemajuan Project (Atur Kos)
* **Ringkasan Status:**
  * PRD v2.0.0 & Database Migration v2: **Dipetakan & Diadopsi (100%)**
  * Fitur 1 (Fondasi RBAC & Role Super Admin): **SELESAI (100%)**
  * Fitur 2 (Super Admin Portal & Verifikasi Properti Kos): **SELESAI (100%)**
  * Fitur 3 (Enforcement Paket Freemium 2-Tier: Starter vs Juragan): **SELESAI (100%)**
  * Kondisi Kode Flutter: **Stabil & Bersih** (`flutter analyze`: 0 issues found).

* **Rincian Capaian:**
  * **A. Perluasan RBAC & Model Properti Multi-Tenant (PRD v2 Modul 1 & 2):**
    * Penambahan peran `superAdmin` pada enum `UserRole` di [user_profile.dart](file:///d:/Atur%20kos/atur_kos/lib/models/user_profile.dart).
    * Pembuatan model [kost_model.dart](file:///d:/Atur%20kos/atur_kos/lib/models/kost_model.dart) mencakup geolokasi (`latitude`, `longitude`, `google_maps_url`), dokumen fisik (`dokumen_ktp_url`, `foto_bangunan_url`), status verifikasi (`KostStatus`), dan paket langganan (`SubscriptionTier`).
    * Pembaruan routing terpusat di [main.dart](file:///d:/Atur%20kos/atur_kos/lib/main.dart): rute otomatis diarahkan ke `SuperAdminDashboardScreen` untuk super admin, `OwnerDashboardScreen` untuk pemilik, dan `TenantDashboardScreen` untuk penghuni.
  * **B. Portal Super Admin & Tata Kelola Properti Kos:**
    * Pembangunan antarmuka [super_admin_dashboard_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/admin/super_admin_dashboard_screen.dart) dengan fitur pencarian, filter status tab, preview foto KTP pemilik & foto tampak depan kos, koordinat maps, serta tombol aksi *Setujui (Approve)*, *Tolak (Reject)* dengan catatan, dan *Bekukan (Suspend)*.
    * Penambahan metode manajemen kos oleh Super Admin di [kos_service.dart](file:///d:/Atur%20kos/atur_kos/lib/services/kos_service.dart): `getAllKostsForAdmin` dan `verifyKostByAdmin`.
  * **C. Enforcement Kuota Paket 2-Tier (Starter vs Juragan) (PRD v2 Modul 3):**
    * Penambahan indikator kuota kamar dan progress bar di [room_management_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/owner/room_management_screen.dart).
    * Penguncian penambahan kamar jika kuota paket Starter (maksimal 5 kamar) telah tercapai, otomatis menampilkan modal penawaran upgrade ke Paket Juragan (kuota s/d 25 kamar, otomasi WA reminder, dan AI poster) dengan pilihan langganan Bulanan (Rp 50.000) dan Tahunan (Rp 500.000, hemat 2 bulan).
    * Pemasangan banner status verifikasi (`pending_verification` / `rejected` / `active`) pada dasbor pemilik kos di [owner_dashboard_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/dashboard/owner_dashboard_screen.dart).

* **Bukti/Artefak:**
  * File Baru: `super_admin_dashboard_screen.dart`, `kost_model.dart`
  * File Diperbarui: `user_profile.dart`, `main.dart`, `kos_service.dart`, `owner_dashboard_screen.dart`, `room_management_screen.dart`

### 2. Komitmen Output Selanjutnya (Fitur 4: Midtrans Smart Billing & Kuitansi Digital)
* Integrasi pembayaran Midtrans Snap (QRIS & Virtual Account) di sisi penghuni.
* Penerbitan Kuitansi Digital ber-QR Code verifikasi anti-manipulasi.
* Sinkronisasi kas masuk otomatis (`cash_ledgers`) via webhook saat pembayaran lunas.

---

## 📅 Senin, 12 Oktober 2026 (Penyelesaian Modul 2: Dual-Mode Geolocation & Dokumen Verifikasi Kos)

### 1. Kemajuan Project (Atur Kos)
* **Ringkasan Status:**
  * Modul 2 (Onboarding Properti Kos & Geolocation): **SELESAI (100%)**
  * Integrasi GPS & Google Maps: **Berhasil (`geolocator` & `url_launcher`)**
  * Kondisi Kode Flutter: **Stabil & Bersih** (`flutter analyze`: 0 issues found).

* **Rincian Capaian:**
  * **A. Dual-Mode Geolocation Engine (PRD v2 Modul 2 - 6.2):**
    * **Opsi A (GPS 1-Klik Otomatis):** Implementasi tombol deteksi koordinat perangkat (`Geolocator.getCurrentPosition`). Sistem otomatis mendeteksi Latitude dan Longitude akurat serta menyusun tautan Google Maps (`https://maps.google.com/?q=lat,lng`).
    * **Penanganan Kasus Gagal (Edge Cases):** Dilengkapi penanganan *Permission Denied* atau *Location Services Disabled* yang otomatis beralih ramah ke Opsi B (manual) tanpa menyebabkan crash.
    * **Opsi B (Koordinat Manual & Buka Peta):** Pemilik dapat memasukkan/mengoreksi koordinat manual dan menekan tombol verifikasi titik di Google Maps (`url_launcher`).
  * **B. Dokumen Keabsahan Fisik Kos (KTP & Foto Bangunan):**
    * Field input URL berkas KTP pemilik dan foto fisik tampak depan kos di [kos_settings_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/owner/kos_settings_screen.dart).
    * Dilengkapi tombol pratinjau gambar instan (*image preview dialog*) untuk memastikan berkas yang diinput tidak salah.
  * **C. Siklus Verifikasi & Pembaruan Data:**
    * Menyempurnakan metode `updateKosProfile` di [kos_service.dart](file:///d:/Atur%20kos/atur_kos/lib/services/kos_service.dart) untuk menyimpan koordinat GPS, URL peta, berkas KTP, dan foto bangunan ke tabel `kosts`.
    * Jika properti sebelumnya berstatus `rejected`, simpan ulang otomatis mengembalikan status menjadi `pending_verification` untuk ditinjau kembali oleh Super Admin.
    * Status verifikasi, badge paket langganan (Starter vs Juragan), dan kuota kamar ditampilkan jelas di banner status atas.

* **Bukti/Artefak:**
  * File Diperbarui: `kos_settings_screen.dart`, `kos_service.dart`, `pubspec.yaml`, `LOGBOOK-HARIAN.md`, `PROGRESS-PROJECT.md`

### 2. Komitmen Output Selanjutnya (Roadmap PRD v2 Modul 4)
* **Modul 4 (Smart Billing & Midtrans Payment Gateway):**
  * Tampilan rincian tagihan sewa & tombol "Bayar Sekarang" di akun penghuni.
  * Integrasi pembayaran instan via Midtrans Snap (QRIS & Virtual Account).
  * Webhook listener / simulator settlement & penerbitan Kuitansi Digital Sah ber-QR Code verifikasi anti-manipulasi.

---

## 📅 Hari/Tanggal: Selasa, 13 Oktober 2026

### 1. Capaian Progres (Iterasi Feedback Pengujian Pengguna - Modul 2)
* **Status Modul:**
  * Akses Super Admin: **SELESAI (Pintasan Menu Dasbor Pemilik)**
  * Penyederhanaan Lokasi Kos: **SELESAI (Google Maps Link Only & GPS Timeout Protection)**
  * Upload Foto KTP & Bangunan dari Kamera / Galeri: **SELESAI (`image_picker` & visual thumbnail)**
  * Alur Onboarding Verifikasi Kos Baru: **SELESAI (Prompt Otomatis & Banner Aksi Langsung ke Super Admin)**
  * Status Lints: **0 errors, 0 warnings** (`flutter analyze` bersih)

* **Rincian Capaian:**
  * **A. Akses Cepat Super Admin:**
    * Menambahkan tombol pintasan Portal Super Admin di menu dasbor pemilik [owner_dashboard_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/dashboard/owner_dashboard_screen.dart) menggunakan `PopupMenuButton` responsif (mencegah overflow pada layar sempit/mobile).
  * **B. Penyederhanaan Form Lokasi Kos ([kos_settings_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/owner/kos_settings_screen.dart)):**
    * Menghilangkan kewajiban input manual Latitude & Longitude yang membingungkan pemilik kos.
    * Menyediakan 1 kolom utama yang ramah: **Tautan / Link Google Maps Kos** dengan tombol langsung buka / salin pin Google Maps.
    * Menambahkan proteksi *timeout* (3s service check, 6s position) pada tombol GPS 1-klik agar tidak macet/spinner selamanya di web browser.
    * Otomatisasi ekstraksi koordinat Lat/Lng via Regex saat tautan Google Maps disimpan, menjaga data spasial database tetap lengkap.
  * **C. Upload Foto KTP & Bangunan Visual ([kos_settings_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/owner/kos_settings_screen.dart) & [super_admin_dashboard_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/admin/super_admin_dashboard_screen.dart)):**
    * Mengganti kolom teks URL menjadi kartu upload visual interaktif dengan pilihan **"Ambil dari Kamera"** dan **"Buka Galeri"** menggunakan `image_picker`.
    * Menyediakan thumbnail pratinjau instan di layar, indikator status terlampir, serta tombol perbesar/ganti/hapus foto.
    * Mendukung kompresi otomatis dan penyimpanan multi-skema (Supabase Storage upload dengan fallback Base64 Data URL aman).
    * Layar Super Admin diperbarui sehingga mampu merender dokumen baik dari tautan HTTP maupun Base64 memory.
  * **D. Alur Pengajuan Verifikasi Wajib Kos Baru Pemilik ([register_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/auth/register_screen.dart), [owner_dashboard_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/dashboard/owner_dashboard_screen.dart), [kos_settings_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/owner/kos_settings_screen.dart)):**
    * Notifikasi Sukses Registrasi Pemilik Baru: Mengarahkan secara eksplisit bahwa setelah akun dibuat, langkah wajib berikutnya adalah mengajukan dokumen verifikasi kos ke Super Admin.
    * Onboarding Prompt Dialog Otomatis: Saat pemilik baru masuk ke Dasbor pertama kali dan kos berstatus belum aktif / dokumen belum lengkap, sistem secara otomatis menampilkan modal penyambutan dengan checklist dokumen (Maps, Foto Bangunan, KTP) dan tombol CTA langsung **"Lengkapi & Ajukan Sekarang"**.
    * Banner Interaktif Terpadu di Dasbor Pemilik: Menampilkan kartu peringatan interaktif di dasbor pemilik dengan tombol aksi langsung yang membuka form verifikasi (`_openKosSettings`), indikator kelengkapan dokumen foto dan KTP secara real-time, serta penanganan status penolakan (*rejection reason*).
    * Penyesuaian Tombol Simpan Form Kos: Tombol utama beradaptasi dinamis dengan teks **"Kirim Pengajuan Verifikasi ke Super Admin"** saat status properti belum aktif.

  * **E. Pre-fill Data Registrasi, Pencegahan Duplikasi Kode Undangan, & Gating Akses Fitur Belum Terverifikasi:**
    * **Pre-fill Data Informasi Umum Kos:** Di [kos_settings_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/owner/kos_settings_screen.dart), data Informasi Umum & Alamat Kos otomatis terisi sesuai isian registrasi awal akun pemilik baru (Nama Kos, Alamat Lengkap, Nomor Kontak Pemilik, dan Kode Undangan Bawaan). Ditambahkan badge hijau *"Terisi dari Pendaftaran"* sehingga pemilik cukup fokus memverifikasi 3 hal: Tautan Google Maps, Foto Bangunan, dan Foto KTP Asli.
    * **Pencegahan Duplikasi Kode Undangan Kos:**
      * Dibuat skrip SQL [supabase_unique_kode_kost.sql](file:///d:/Atur%20kos/supabase_unique_kode_kost.sql) dengan index unik case-insensitive (`CREATE UNIQUE INDEX idx_kosts_kode_kost_unique ON public.kosts (UPPER(TRIM(kode_kost)))`).
      * Penambahan metode `isKodeKostAvailable` di [kos_service.dart](file:///d:/Atur%20kos/atur_kos/lib/services/kos_service.dart) untuk validasi real-time.
      * Pencegahan update jika kode sudah digunakan pemilik lain dengan modal peringatan *"Kode Sudah Digunakan"* di antarmuka pengaturan kos.
    * **Pembatasan Akses Fitur (*Feature Gating*) saat Belum Terverifikasi:**
      * Selama properti belum berstatus `active` (masih `pending_verification` / `rejected`), seluruh fitur operasional di [owner_dashboard_screen.dart](file:///d:/Atur%20kos/atur_kos/lib/screens/dashboard/owner_dashboard_screen.dart) terkunci secara visual (indikator gembok kuning/abu-abu).
      * Penerapan `_guardedFeatureAction` pada 4 Kartu Metrik Operasional (Okupansi, Kas Masuk, Tunggakan, Verifikasi Bayar), 5 Menu Utama Pemilik (Kelola Kamar, Alokasi Penghuni, Smart Billing & Kas, Helpdesk Keluhan, Poster Promosi AI & Radar H-30), tombol Bagikan Kode Undangan, dan tombol Verifikasi Pembayaran 1-Klik.
      * Menampilkan dialog instruktif *"Fitur Terkunci"* dengan CTA langsung *"Ajukan Verifikasi"* jika pemilik belum terverifikasi mencoba mengakses fitur.

* **Bukti/Artefak:**
  * File Baru: `supabase_unique_kode_kost.sql`
  * File Diperbarui: `kos_service.dart`, `kos_settings_screen.dart`, `owner_dashboard_screen.dart`, `LOGBOOK-HARIAN.md`
  * Validasi Linter: `flutter analyze` exit code 0 (No issues found!).



