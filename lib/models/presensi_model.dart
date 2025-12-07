import 'package:flutter/material.dart';

class PresensiItem {
  final String kode;
  final String mataKuliah;
  final String dosen;
  final String kelas;
  final String hari;
  final String waktu;
  final String ruang;
  final int pertemuanTerlaksana;
  final int totalPertemuan;
  final int persentasePertemuan;
  final int persentaseKehadiran;
  final String encryptedJadwalId;
  final String encryptedNim;

  PresensiItem({
    required this.kode,
    required this.mataKuliah,
    required this.dosen,
    required this.kelas,
    required this.hari,
    required this.waktu,
    required this.ruang,
    required this.pertemuanTerlaksana,
    required this.totalPertemuan,
    required this.persentasePertemuan,
    required this.persentaseKehadiran,
    required this.encryptedJadwalId,
    required this.encryptedNim,
  });

  factory PresensiItem.fromJson(Map<String, dynamic> json) {
    return PresensiItem(
      kode: json['kode'] ?? '',
      mataKuliah: json['mataKuliah'] ?? '',
      dosen: json['dosen'] ?? '',
      kelas: json['kelas'] ?? '',
      hari: json['hari'] ?? '',
      waktu: json['waktu'] ?? '',
      ruang: json['ruang'] ?? '',
      pertemuanTerlaksana: json['pertemuanTerlaksana'] ?? 0,
      totalPertemuan: json['totalPertemuan'] ?? 0,
      persentasePertemuan: json['persentasePertemuan'] ?? 0,
      persentaseKehadiran: json['persentaseKehadiran'] ?? 0,
      encryptedJadwalId: json['encryptedJadwalId'] ?? '',
      encryptedNim: json['encryptedNim'] ?? '',
    );
  }

  Color getKehadiranColor() {
    if (persentaseKehadiran >= 80) {
      return const Color(0xFF00A65A);
    } else if (persentaseKehadiran >= 60) {
      return const Color(0xFFF39C12); 
    } else {
      return const Color(0xFFDD4B39); 
    }
  }
}
