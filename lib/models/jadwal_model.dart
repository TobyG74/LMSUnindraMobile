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
}
