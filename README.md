# LMS UNINDRA Mobile

Aplikasi mobile buat akses LMS UNINDRA, buat bikin gampang akses materi kuliah dari HP.

## Releases

- [v1.0.3 - Latest Release](https://github.com/TobyG74/LMSUnindraMobile/releases/tag/v1.0.3)
- [v1.0.2](https://github.com/TobyG74/LMSUnindraMobile/releases/tag/v1.0.2)
- [v1.0.1](https://github.com/TobyG74/LMSUnindraMobile/releases/tag/v1.0.1)
- [v1.0.0 - Initial Release](https://github.com/TobyG74/LMSUnindraMobile/releases/tag/v1.0.0)

## Screenshots

- [Login](#login)
- [Dashboard Mahasiswa & Dosen](#dashboard-mahasiswa--dosen)
- [Mata Kuliah Mahasiswa & Dosen](#mata-kuliah-mahasiswa--dosen)
- [Laporan Perkuliahan Dosen](#laporan-perkuliahan-dosen)
- [Jadwal Kuliah & Pertemuan Mahasiswa](#jadwal-kuliah--pertemuan-mahasiswa)
- [Jadwal Kuliah & Pertemuan Dosen](#jadwal-kuliah--pertemuan-dosen)
- [Pertemuan: Tugas, External URL, Forum Diskusi Mahasiswa](#pertemuan-tugas-external-url-forum-diskusi-mahasiswa)
- [Presensi Mahasiswa](#presensi-mahasiswa)
- [Presensi Dosen](#presensi-dosen)
- [Cari Mahasiswa & Cari Dosen](#cari-mahasiswa--cari-dosen)

### Login
<p align="center">
  <img src="assets/select_login.png" alt="Captcha" width="200"/>
  <img src="assets/login.png" alt="Login" width="200"/>
  <img src="assets/reset_password.png" alt="Reset Password" width="200"/>
</p>

### Dashboard Mahasiswa & Dosen
<p align="center">
  <img src="assets/mahasiswa_dashboard.png" alt="Dashboard Mahasiswa" width="200"/>
  <img src="assets/dosen_dashboard.png" alt="Dashboard Dosen" width="200"/>
</p>

### Mata Kuliah Mahasiswa & Dosen
<p align="center">
  <img src="assets/matakuliah.png" alt="Mata Kuliah" width="200"/>
  <img src="assets/matakuliah_detail.png" alt="Detail Mata Kuliah" width="200"/>
</p>

### Laporan Perkuliahan Dosen
<p align="center">
  <img src="assets/dosen_laporan_perkuliahan.png" alt="Laporan Perkuliahan" width="200"/>
  <img src="assets/dosen_laporan_perkuliahan_detail.png" alt="Detail Laporan Perkuliahan" width="200"/>
</p>

### Jadwal Kuliah & Pertemuan Mahasiswa
<p align="center">
  <img src="assets/mahasiswa_jadwalkuliah.png" alt="Jadwal Kuliah" width="200"/>
  <img src="assets/mahasiswa_pertemuan.png" alt="Detail Jadwal" width="200"/>
  <img src="assets/mahasiswa_pertemuan_detail.png" alt="Detail Jadwal" width="200"/>
</p>

### Jadwal Kuliah & Pertemuan Dosen
<p align="center">
  <img src="assets/dosen_jadwalkuliah.png" alt="Jadwal Kuliah" width="200"/>
  <img src="assets/dosen_pertemuan.png" alt="Detail Jadwal" width="200"/>
  <img src="assets/dosen_pertemuan_detail.png" alt="Detail Jadwal" width="200"/>
  <img src="assets/dosen_pertemuan_detail_tambahlesson.png" alt="Detail Jadwal" width="200"/>
</p>

### Pertemuan: Tugas, External URL, Forum Diskusi Mahasiswa
<p align="center">
  <img src="assets/pertemuan_tugas.png" alt="Tugas" width="200"/>
  <img src="assets/pertemuan_external.png" alt="External URL" width="200"/>
  <img src="assets/pertemuan_forum.png" alt="Forum Diskusi" width="200"/>
</p>

### Presensi Mahasiswa
<p align="center">
  <img src="assets/mahasiswa_presensi.png" alt="Presensi Mahasiswa" width="200"/>
  <img src="assets/mahasiswa_presensi_detail.png" alt="Presensi Mahasiswa" width="200"/>
</p>

### Presensi Dosen
<p align="center">
  <img src="assets/dosen_presensi.png" alt="Presensi Dosen" width="200"/>
  <img src="assets/dosen_presensi_kelas.png" alt="Presensi Dosen" width="200"/>
  <img src="assets/dosen_presensi_rekap.png" alt="Presensi Dosen" width="200"/>
  <img src="assets/dosen_presensi_monitoring.png" alt="Presensi Dosen" width="200"/>
</p>

### Cari Mahasiswa & Cari Dosen
<p align="center">
  <img src="assets/cari_mahasiswa.png" alt="Cari Mahasiswa" width="200"/>
  <img src="assets/cari_dosen.png" alt="Cari Dosen" width="200"/>
  <img src="assets/cari_dosen_detail.png" alt="Cari Dosen" width="200"/>
</p>

## Tabel Konten

- [Fitur](#fitur)
- [Tech Stack](#tech-stack)
- [Instalasi](#instalasi)
- [Build Aplikasi](#build-aplikasi)
- [Auto Solve Captcha](#auto-solve-captcha)
- [Struktur Project](#struktur-project)
- [License](#license)

## Fitur

- Login otomatis (captcha auto-solve pake OCR)
- Remember me buat nyimpen login
- Dashboard yang simpel
- Jadwal kuliah dengan indikator hari ini
- Presensi
- Materi pertemuan dengan badge "Baru"
- Download materi (PDF, Word, PPT, Excel, dll)
- Upload tugas dengan validasi deadline
- Google Meet integration
- Forum diskusi
- URL eksternal

## Tech Stack

- Flutter
- Dio (HTTP client)
- Google ML Kit (buat OCR captcha)
- Provider (state management)
- Shared Preferences
- Cookie Manager

## Instalasi

### Yang dibutuhin:

- Flutter SDK (minimal versi 3.0.0)
- Android SDK / Xcode
- Internet

### Cara install:

1. Clone repo ini
2. Install dependencies:

```bash
flutter pub get
```

3. Jalanin aplikasi:

```bash
flutter run
```

## Build Aplikasi

### Android APK

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

## Auto Solve Captcha

Fitur auto solve captcha pake Google ML Kit buat baca soal matematika di captcha terus solve otomatis.

Support operasi:
- Tambah: `6+2=?`
- Kurang: `7-2=?`
- Kali: `8x2=?`
- Bagi: `9/3=?`

Cara kerjanya:
1. Ambil gambar captcha dari server
2. Pre-process gambar biar lebih jelas
3. OCR pake ML Kit
4. Parse soal matematika
5. Hitung & isi otomatis

## Struktur Project

```
lib/
├── main.dart
├── models/          # Model data
├── services/        # API & service layer
└── screens/         # UI screens
```

## License

[MIT License](https://github.com/TobyG74/LMSUnindraMobile/blob/master/LICENSE)

---
