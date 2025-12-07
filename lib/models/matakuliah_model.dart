import 'package:flutter/material.dart';

class MataKuliahItem {
  final String nama;
  final String kode;
  final String kelas;
  final String semester;
  final String sks;
  final String dosen;
  final String? nomorHp;
  final String encryptedKelasId;
  final IconData icon;
  final Color color;

  MataKuliahItem({
    required this.nama,
    required this.kode,
    required this.kelas,
    required this.semester,
    required this.sks,
    required this.dosen,
    this.nomorHp,
    required this.encryptedKelasId,
    this.icon = Icons.book,
    this.color = Colors.blue,
  });
}
