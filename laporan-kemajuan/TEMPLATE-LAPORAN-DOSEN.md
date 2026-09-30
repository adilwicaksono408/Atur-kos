# Template Pesan Laporan Harian ke Dosen Pembimbing

Gunakan template di bawah ini untuk mengirimkan laporan harian melalui WhatsApp / Email / Sistem Bimbingan Kampus. Cukup ganti teks di dalam tanda kurung siku `[...]`.

---

## 1. Format Standar Harian (Paling Sering Digunakan)

```text
Selamat [pagi/siang/sore] Pak/Bu [Nama Dosen],
Izin melaporkan progres harian pengerjaan Project dan Skripsi saya per [Hari, Tanggal Bulan Tahun]:

A. KEMAJUAN PROJECT (Aplikasi Kos Princess):
1. [Modul/Fitur]: Selesai mengimplementasikan [Nama Fitur]
   - Hasil konkret: [Jelaskan apa yang sudah jalan, misal: Skema database 5 tabel + RLS di Supabase]
   - Bukti: [Lampirkan screenshot / file / link commit GitHub]
2. [Testing/Fix]: [Misal: Pengujian otentikasi login email & Google OAuth berhasil]

B. KEMAJUAN SKRIPSI (Dokumen Naskah):
1. [Bab/Subbab]: Selesai menulis [Misal: Bab 3 Subbab 3.3 Perancangan Basis Data]
   - Hasil konkret: Penambahan [X] halaman (total draft saat ini: [Y] halaman)
   - Artefak: [Misal: Selesai membuat Diagram ERD & Kamus Data 5 entitas utama]
   - Draft naskah: [Terlampir file PDF / Google Docs link]

C. KOMITMEN OUTPUT BESOK:
- Project: [Satu fitur konkret yang akan selesai besok, misal: CRUD Manajemen Kamar]
- Skripsi: [Satu subbab konkret yang akan selesai besok, misal: Bab 3 Subbab Perancangan Antarmuka]

Terima kasih banyak atas bimbingan dan arahannya, Pak/Bu. 🙏
```

---

## 2. Format Laporan Saat Menghadapi Kendala Teknis (*Stuck / Bug*)

> **Penting:** Jika mengalami kendala/bug, jangan hanya lapor "sedang error". Laporkan apa yang sudah dicoba dan solusi alternatif yang sedang diuji.

```text
Selamat [pagi/siang/sore] Pak/Bu [Nama Dosen],
Izin melaporkan progres harian Project dan Skripsi per [Hari, Tanggal Bulan Tahun]:

A. KEMAJUAN PROJECT:
1. Selesai membuat [fitur yang berhasil dibuat hari ini].
2. Catatan Kendala & Solusi:
   - Kendala: [Misal: Sinkronisasi webhook WhatsApp reminder mengalami delay]
   - Langkah yang sudah dicoba: [Mencoba alternatif polling cron job via Supabase Edge Function]
   - Status: Sudah teratasi 80% dan sedang dalam tahap pengujian akhir.

B. KEMAJUAN SKRIPSI:
1. Selesai menulis [Bab/Subbab], bertambah [X] halaman.
2. Selesai membuat [Diagram/Tabel referensi pendukung].

C. KOMITMEN OUTPUT BESOK:
- Project: Finalisasi [fitur yang sempat terkendala] + [fitur berikutnya].
- Skripsi: Penulisan [subbab berikutnya].

Terima kasih banyak, Pak/Bu. 🙏
```

---

## 3. Format Laporan Milestone Mingguan / Siap Demo

```text
Selamat [pagi/siang/sore] Pak/Bu [Nama Dosen],
Izin melaporkan bahwa modul [Nama Modul, misal: Smart Billing & WhatsApp Reminder] pada aplikasi Kos Princess telah selesai dibangun dan siap didemokan.

Ringkasan Pencapaian:
1. Project:
   - Fitur X, Y, Z telah berfungsi penuh dan terintegrasi dengan basis data.
   - Video demonstrasi alur (1 menit) dapat dilihat pada tautan berikut: [Link Video/Drive]
2. Dokumen Skripsi:
   - Bab [X] telah rampung ditulis lengkap dengan dokumentasi pengujian black-box.
   - Total naskah: [Jumlah] halaman (file PDF terlampir).

Jika Bapak/Ibu berkenan, saya siap mendemonstrasikan aplikasi ini secara langsung pada jadwal bimbingan berikutnya. Terima kasih, Pak/Bu. 🙏
```
