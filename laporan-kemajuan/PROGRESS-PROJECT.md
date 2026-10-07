# Matriks Kemajuan Project: Aplikasi Kos Princess

**Nama Aplikasi:** Sistem Manajemen Operasional & Otomasi Kos Princess  
**Tech Stack:** Next.js (App Router), Supabase (PostgreSQL, Auth, Storage), Tailwind CSS, WhatsApp Gateway  
**Dokumen Acuan:** [PRD.md](file:///d:/Kos%20Princess/PRD.md)

---

## 📊 Ringkasan Status Keseluruhan

| Modul | Status | Persentase | Terakhir Diperbarui |
| :--- | :---: | :---: | :---: |
| **Fondasi & Basis Data (Supabase & RLS)** | Selesai | 100% | 6 Oktober 2026 |
| **Modul 1: Autentikasi & RBAC** | Selesai | 100% | 6 Oktober 2026 |
| **Modul 2: Inventaris & Alokasi Kamar** | Selesai | 100% | 6 Oktober 2026 |
| **Modul 3: Finansial & Tagihan Sewa** | In Progress | 50% | 6 Oktober 2026 |
| **Modul 4: Tiket Keluhan & Perbaikan** | Belum Mulai | 0% | - |
| **Modul 5: Mitigasi Kamar Kosong & Poster AI** | In Progress | 40% | 6 Oktober 2026 |
| **Pengujian Sistem (Testing & UAT)** | In Progress | 40% | 6 Oktober 2026 |

---

## 🛠️ Rincian Status per Modul

### 0. Fondasi & Basis Data (Supabase & RLS)
- [x] Inisialisasi Proyek Flutter (`atur_kos`) & konfigurasi Supabase SDK
- [x] DDL Skrip SQL Pembuatan Tabel:
  - [x] Tabel `profiles` (Sinkronisasi `auth.users` dengan role `owner` & `tenant`)
  - [x] Tabel `rooms` (Nomor kamar, tipe, harga, fasilitas, status)
  - [x] Tabel `tenants` (Relasi user dengan kamar, tanggal sewa, siklus bayar)
  - [x] Tabel `invoices` (Nomor invoice, periode, nominal, bukti bayar, status)
  - [x] Tabel `complaints` (Kategori kamar pribadi/umum, deskripsi, foto, status)
- [x] Arsitektur Keamanan Ketat Row Level Security (RLS) (`supabase_secure_rbac_policies.sql`)
- [x] Skrip Sinkronisasi Nama Calon Penghuni (`supabase_sync_candidate_names.sql`)

### 1. Modul 1: Autentikasi, Profil & RBAC (100% Selesai)
- [x] Halaman Registrasi & Login Email/Password (`login_screen.dart`, `register_screen.dart`)
- [x] Integrasi Login dengan Google OAuth
- [x] Fitur Lupa Kata Sandi / Reset Password (`forgot_password_screen.dart`, `reset_password_screen.dart`)
- [x] Konfirmasi Email Registrasi & Penanganan Email Confirmation
- [x] Kepatuhan RBAC Murni: Penghapusan toggle role manual & pembersihan data dummy
- [x] Personalisasi UI dinamis ("Halo, [Nama Pengguna]") di Dasbor Pemilik & Penghuni
- [x] Perbaikan error layout web (`RenderFlex overflowed`) & backend HTTP 500

### 2. Modul 2: Inventaris & Alokasi Kamar (100% Selesai)
- [x] Dasbor Pemilik (Owner Overview)
- [x] Kode Undangan Properti Kos Dinamis (Salin clipboard & bagikan ke WhatsApp)
- [x] Alur Masuk Calon Penghuni via Kode Undangan (`joinKosByInvitationCode`)
- [x] Layar Alokasi Kamar Pemilik (`tenant_allocation_screen.dart`): Calon penghuni menunggu alokasi
- [x] Pemilihan kamar kosong, penentuan harga sewa kesepakatan, dan siklus jatuh tempo
- [x] Otomasi penerbitan tagihan pertama saat kamar berhasil dialokasikan

### 3. Modul 3: Finansial & Tagihan Sewa (50% Berjalan)
- [x] Penerbitan Tagihan Otomatis Perdana saat alokasi kamar tersimpan
- [x] Logika operasional kas & KPI keuangan di `kos_service.dart`
- [ ] Formulir Unggah Bukti Transfer Pembayaran di sisi Penghuni (US-3.2)
- [ ] Menu Verifikasi Pembayaran Masuk (Terima / Tolak) oleh Pemilik (US-3.3)
- [ ] Otomasi Pengingat Jatuh Tempo WhatsApp (US-3.4)

### 4. Modul 4: Helpdesk & Tiket Keluhan Fasilitas (Menunggu)
- [ ] Form Pengajuan Komplain oleh Penghuni (Kamar Pribadi / Fasilitas Umum + Foto)
- [ ] Dasbor Pelacakan Status Keluhan Penghuni (`Diajukan` $\rightarrow$ `Sedang Dikerjakan` $\rightarrow$ `Selesai`)
- [ ] Dasbor Manajemen Komplain untuk Pemilik (Update status & catatan perbaikan)

### 5. Modul 5: Mitigasi Kamar Kosong H-30 & Poster AI (40% Berjalan)
- [x] Generator Poster Promosi Kamar Kosong (`room_poster_generator_screen.dart`)
- [ ] Formulir Komitmen Perpanjangan Sewa H-30 di akun penghuni
- [ ] Papan Pengumuman Digital Kos & Ekspor Laporan Keuangan (US-5.1 & US-5.5)
