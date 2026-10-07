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

