# Matriks Kemajuan Project: Aplikasi Kos Princess

**Nama Aplikasi:** Sistem Manajemen Operasional & Otomasi Kos Princess  
**Tech Stack:** Next.js (App Router), Supabase (PostgreSQL, Auth, Storage), Tailwind CSS, WhatsApp Gateway  
**Dokumen Acuan:** [PRD.md](file:///d:/Kos%20Princess/PRD.md)

---

## 📊 Ringkasan Status Keseluruhan

| Modul | Status | Persentase | Terakhir Diperbarui |
| :--- | :---: | :---: | :---: |
| **Fondasi & Basis Data (Supabase)** | In Progress | 40% | 22 September 2026 |
| **Modul 1: Autentikasi & RBAC** | In Progress | 60% | 22 September 2026 |
| **Modul 2: Manajemen Kamar & Penghuni** | Belum Mulai | 0% | - |
| **Modul 3: Smart Billing & WhatsApp Reminder** | Belum Mulai | 0% | - |
| **Modul 4: Helpdesk Kerusakan Fasilitas** | Belum Mulai | 0% | - |
| **Modul 5: Mitigasi Kamar Kosong & Poster AI**| Belum Mulai | 0% | - |
| **Pengujian Sistem (Testing & UAT)** | Belum Mulai | 0% | - |

---

## 🛠️ Rincian Status per Modul

### 0. Fondasi & Basis Data (Supabase)
- [x] Inisialisasi Proyek Next.js & konfigurasi Tailwind CSS
- [x] Konfigurasi Supabase Client & SSR helper
- [ ] DDL Skrip SQL Pembuatan Tabel:
  - [ ] Tabel `profiles` (Sinkronisasi `auth.users` dengan role `owner` & `tenant`)
  - [ ] Tabel `rooms` (Nomor kamar, tipe, harga, fasilitas, status)
  - [ ] Tabel `tenants` (Relasi user dengan kamar, tanggal sewa, siklus bayar)
  - [ ] Tabel `invoices` (Nomor invoice, periode, nominal, bukti bayar, status)
  - [ ] Tabel `complaints` (Kategori kamar pribadi/umum, deskripsi, foto, status)
- [ ] Konfigurasi Row Level Security (RLS) di Supabase
- [ ] Konfigurasi Supabase Storage Bucket (`room-photos`, `payment-proofs`, `complaint-photos`)

### 1. Modul 1: Autentikasi, Profil & RBAC
- [x] Halaman Registrasi & Login Email/Password (`/login`)
- [x] Integrasi Login dengan Google OAuth
- [x] Halaman Sambutan Dasar (`/welcome`)
- [ ] Middleware proteksi rute berdasarkan Role (`owner` vs `tenant`)
- [ ] Profil Pengguna & Kelola Nomor WhatsApp

### 2. Modul 2: Manajemen Kamar & Penghuni
- [ ] Dasbor Pemilik (Owner Overview)
- [ ] Halaman Daftar & Status Kamar (Kosong, Terisi, Akan Kosong, Perbaikan)
- [ ] Form Tambah & Edit Kamar + Unggah Foto Kamar
- [ ] Alur Alokasi Kamar (Menghubungkan akun penghuni ke kamar)
- [ ] Alur Check-Out Penghuni (Pengembalian status kamar ke kosong)

### 3. Modul 3: Keuangan, Smart Billing & WhatsApp Reminder
- [ ] Generator Tagihan Bulanan (Otomatis sesuai siklus jatuh tempo)
- [ ] Dasbor Tagihan Penghuni (Rincian sewa & rekening pemilik)
- [ ] Fitur Unggah Bukti Pembayaran (Format gambar, simpan ke Supabase Storage)
- [ ] Halaman Verifikasi Pembayaran oleh Pemilik (1-klik konfirmasi/tolak)
- [ ] Otomasi Pengingat WhatsApp (Integrasi Gateway / Cron Job H-3, Hari H, H+2)

### 4. Modul 4: Helpdesk & Tiket Keluhan Kerusakan Fasilitas
- [ ] Form Pengajuan Komplain oleh Penghuni (Kamar Pribadi / Fasilitas Umum + Foto)
- [ ] Dasbor Pelacakan Status Keluhan Penghuni (`Diajukan` $\rightarrow$ `Sedang Dikerjakan` $\rightarrow$ `Selesai`)
- [ ] Dasbor Manajemen Komplain untuk Pemilik (Update status & catatan perbaikan)
- [ ] Tampilan Keluhan Fasilitas Umum (Dapat dilihat semua penghuni)

### 5. Modul 5: Mitigasi Kamar Kosong H-30 & Poster AI
- [ ] Formulir Komitmen Perpanjangan Sewa H-30 di akun penghuni
- [ ] Notifikasi otomatis kamar yang akan kosong ke dasbor pemilik
- [ ] Generator Poster Promosi Kamar Kosong (Canvas / Template siap sebar)
