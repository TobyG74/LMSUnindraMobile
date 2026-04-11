import 'package:flutter/material.dart';

class JadwalItem {
  final String hari;
  final String waktu;
  final String mataKuliah;
  final String singkatan;
  final String kode;
  final String kelas;
  final String ruang;
  final String encryptedKelasId;
  final IconData icon;
  final Color color;

  JadwalItem({
    required this.hari,
    required this.waktu,
    required this.mataKuliah,
    required this.singkatan,
    required this.kode,
    required this.kelas,
    required this.ruang,
    required this.encryptedKelasId,
    this.icon = Icons.book,
    this.color = Colors.blue,
  });

  Map<String, dynamic> toJson() => {
        'hari': hari,
        'waktu': waktu,
        'mataKuliah': mataKuliah,
        'singkatan': singkatan,
        'kode': kode,
        'kelas': kelas,
        'ruang': ruang,
        'encryptedKelasId': encryptedKelasId,
      };

  factory JadwalItem.fromJson(Map<String, dynamic> json) => JadwalItem(
        hari: (json['hari'] as String?) ?? '',
        waktu: (json['waktu'] as String?) ?? '',
        mataKuliah: (json['mataKuliah'] as String?) ?? '',
        singkatan: (json['singkatan'] as String?) ?? '',
        kode: (json['kode'] as String?) ?? '',
        kelas: (json['kelas'] as String?) ?? '',
        ruang: (json['ruang'] as String?) ?? '',
        encryptedKelasId: (json['encryptedKelasId'] as String?) ?? '',
      );
}
