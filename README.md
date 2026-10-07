# 🏠 Atur Kos — Sistem Manajemen & Otomasi Kos Princess

Platform manajemen hunian sewa (kost) modern yang dibangun dengan **Flutter** dan **Supabase (PostgreSQL, Auth, Storage)**. Dirancang untuk mengeliminasi friksi penagihan, menjamin transparansi keluhan fasilitas, dan meminimalkan tingkat kekosongan kamar (*vacancy lag*) melalui sistem terintegrasi.

---

## 📊 1. Ringkasan Status Proyek Saat Ini

* **Modul 1 (Autentikasi & RBAC):** ✅ **SELESAI (100%)**
* **Modul 2 (Manajemen Kamar & Alokasi Penghuni):** ✅ **SELESAI (100%)**
* **Modul 3 (Finansial, Tagihan & Pembayaran):** 🔄 **BERJALAN (50%)** — Tahap 1 Selesai: Penerbitan Tagihan Otomatis
* **Modul 4 (Tiket Keluhan & Perbaikan):** ⏳ **MENUNGGU (0%)**
* **Modul 5 (Dashboard, Mitigasi H-30 & Poster AI):** 🔄 **BERJALAN (40%)**
* **Kondisi Kode Flutter:** 🛡️ **Stabil & Bersih** (`flutter analyze`: 0 errors, 0 warnings).

---

## 🚀 2. Rincian Pekerjaan yang Telah Diselesaikan (Completed Work)

### A. Pembenahan Autentikasi & Akun Pengguna (PRD Modul 1)
* **Fitur Lupa Kata Sandi (*Forgot Password*):**
  * Dibuat alur kirim email reset sandi di `forgot_password_screen.dart` dan penanganan token tautan reset di `reset_password_screen.dart`.
* **Konfirmasi Email Registrasi:**
  * Penanganan registrasi baru di `register_screen.dart` disesuaikan agar menampilkan instruksi verifikasi email saat fitur *Email Confirmation* Supabase aktif.
* **Pembersihan Mode Pengguna & Personalisasi UI:**
  * Menghapus tombol toggle manual *"Beralih Mode Pemilik / Penghuni"* demi kepatuhan RBAC (*Role-Based Access Control*) murni.
  * Menghilangkan data dummy *"BU RINA BU RINA"*.
  * Menambahkan ucapan pembuka personal nama pengguna secara dinamis (*"Halo, [Nama Pengguna]"*) di dasbor Pemilik dan Penghuni.
* **Perbaikan Error Layout & Backend:**
  * Memperbaiki bug `RenderFlex overflowed` (104px, 195px, 128px) pada antarmuka autentikasi web.
  * Mengatasi HTTP 500 (*Database error saving new user*) saat pendaftaran.

### B. Kode Undangan & Alokasi Kamar (PRD Modul 2 - US-2.2)
* **Kode Undangan Properti Kos Dinamis:**
  * Pemilik memiliki kode undangan kos nyata (misal `PRINCESS`, atau kombinasi nama kos + angka unik).
  * Tersedia fitur salin ke clipboard dan bagikan ke WhatsApp calon penghuni.
* **Alur Calon Penghuni Masuk ke Kos:**
  * Penghuni memasukkan kode undangan di dasbor penghuni (`joinKosByInvitationCode`), akun langsung terhubung ke properti kos terkait (`profiles.kost_id`).
* **Layar Alokasi Kamar Pemilik (`tenant_allocation_screen.dart`):**
  * Menampilkan bagian teratas: *"Calon Penghuni Menunggu Alokasi"*.
  * Pemilik dapat memilih calon penghuni, memilih kamar kosong, menentukan harga sewa yang disepakati, dan siklus tanggal jatuh tempo.
* **Otomasi Tagihan Pertama:**
  * Saat alokasi disimpan, status kamar otomatis berubah jadi terisi, data sewa aktif tercatat di tabel `tenants`, dan tagihan sewa perdana otomatis terbit di tabel `invoices`.

### C. Keamanan Database & Penyelesaian Isu Nama "Fatimah"
* **Evaluasi Keamanan RLS Supabase:**
  * Menghindari risiko keamanan RLS dimatikan di lingkungan produksi.
  * Dibuat skrip arsitektur keamanan ketat `supabase_secure_rbac_policies.sql` untuk mengisolasi data keuangan, bukti bayar, dan kamar antarpenghuni.
* **Perbaikan Sinkronisasi Nama Calon Penghuni:**
  * Mengatasi masalah nama calon penghuni tampil sebagai *"Calon Penghuni"* padahal di database bernama *Fatimah*.
  * Diperbaiki pembacaan data di `kos_service.dart`, `tenant_allocation_screen.dart`, dan `auth_service.dart`.
  * Disediakan skrip SQL sinkronisasi instan di `supabase_sync_candidate_names.sql`.

---

## 📁 3. File Kunci yang Dibuat & Dimodifikasi

| Kategori | File | Peran / Fungsi |
| :--- | :--- | :--- |
| **Database SQL** | `supabase_secure_rbac_policies.sql` | Kebijakan keamanan RLS granular berbasis Role (Owner vs Tenant). |
| **Database SQL** | `supabase_sync_candidate_names.sql` | Sinkronisasi nama pengguna dari `auth.users` ke `public.profiles`. |
| **Database SQL** | `supabase_fix_rls_tenants.sql` | Perbaikan izin RLS pada relasi tabel penyewa. |
| **Database SQL** | `supabase_fix_signup.sql` | Penanganan trigger pendaftaran pengguna baru. |
| **Flutter UI** | `tenant_allocation_screen.dart` | Antarmuka alokasi kamar kosong ke calon penghuni & daftar penghuni aktif. |
| **Flutter UI** | `tenant_dashboard_screen.dart` | Dasbor penghuni, input kode undangan kos, info sewa & tagihan. |
| **Flutter UI** | `owner_dashboard_screen.dart` | Dasbor ringkasan pemilik, KPI hunian kamar, dan aksi cepat. |
| **Flutter UI** | `forgot_password_screen.dart` | Layar permintaan kirim tautan reset kata sandi ke email. |
| **Flutter UI** | `reset_password_screen.dart` | Layar pengisian kata sandi baru dari tautan reset. |
| **Flutter UI** | `room_poster_generator_screen.dart` | Generator poster kamar kosong berbasis template. |
| **Flutter Service** | `kos_service.dart` | Logika operasional kos: alokasi kamar, kode undangan, tagihan, KPI kas. |
| **Flutter Service** | `auth_service.dart` | Manajemen login, Google OAuth, sinkronisasi profil, dan lupa sandi. |
| **Flutter Utils** | `format_utils.dart` | Utilitas format mata uang Rupiah dan tanggal Indonesia. |

---

## 📈 4. Pemetaan Progres Sesuai Dokumen PRD

```text
PRD Modul 1: Autentikasi & RBAC           [████████████████████] 100% (SELESAI)
PRD Modul 2: Inventaris & Alokasi Kamar   [████████████████████] 100% (SELESAI)
PRD Modul 3: Finansial & Tagihan Sewa     [██████████░░░░░░░░░░]  50% (SEDANG BERJALAN)
PRD Modul 4: Tiket Keluhan & Perbaikan    [░░░░░░░░░░░░░░░░░░░░]   0% (MENUNGGU)
PRD Modul 5: Dashboard & Pengumuman       [████████░░░░░░░░░░░░]  40% (SEDANG BERJALAN)
```

---

## 🎯 5. Langkah Selanjutnya Sesuai PRD (Next Roadmap)

* **Modul 3: Alur Pembayaran & Verifikasi Bukti Transfer (US-3.2 & US-3.3)**
  * **Sisi Penghuni:** Menampilkan rincian tagihan sewa bulanan dan formulir unggah bukti transfer pembayaran (foto/gambar struk).
  * **Sisi Pemilik Kos:** Menu verifikasi pembayaran masuk (Terima / Tolak bukti pembayaran) yang otomatis mengubah status tagihan menjadi *Lunas* dan mencatatnya ke pemasukan kas riil.
* **Modul 3: Peringatan Jatuh Tempo & Reminder WhatsApp (US-3.4)**
  * Notifikasi/tombol kirim tagihan & pengingat jatuh tempo ke WhatsApp penghuni yang menunggak bayar.
* **Modul 4: Sistem Tiket Keluhan (*Ticketing System*) (US-4.1 & US-4.2)**
  * Penghuni dapat mengajukan komplain fasilitas (Kamar Pribadi vs Fasilitas Umum) lengkap dengan foto.
  * Pemilik memproses status keluhan (`Diajukan` $\rightarrow$ `Diproses` $\rightarrow$ `Selesai`).
* **Modul 5: Papan Pengumuman Digital Kos & Ekspor Laporan Keuangan (US-5.1 & US-5.5)**
  * Siaran informasi operasional kos dari pemilik ke seluruh penghuni.
  * Ekspor laporan pemasukan dan tunggakan sewa.

---

## 🛠️ Cara Menjalankan Aplikasi

1. Masuk ke folder aplikasi Flutter:
   ```bash
   cd atur_kos
   ```
2. Jalankan dependensi:
   ```bash
   flutter pub get
   ```
3. Jalankan aplikasi ke perangkat terhubung:
   ```bash
   flutter run
   ```
