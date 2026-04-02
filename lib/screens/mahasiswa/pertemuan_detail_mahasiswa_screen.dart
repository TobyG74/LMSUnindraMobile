import 'package:flutter/material.dart';
import '../pertemuan_detail_screen.dart';

class PertemuanDetailMahasiswaScreen extends StatelessWidget {
  final String? encryptedUrl;
  final String? title;
  final String? encryptedKelasId;
  final String? namaMataKuliah;
  final String? kodeMataKuliah;
  final String? mataKuliah;
  final int? pertemuanKe;

  const PertemuanDetailMahasiswaScreen({
    super.key,
    this.encryptedUrl,
    this.title,
    this.encryptedKelasId,
    this.namaMataKuliah,
    this.kodeMataKuliah,
    this.mataKuliah,
    this.pertemuanKe,
  });

  @override
  Widget build(BuildContext context) {
    return PertemuanDetailScreen(
      encryptedUrl: encryptedUrl,
      title: title,
      encryptedKelasId: encryptedKelasId,
      namaMataKuliah: namaMataKuliah,
      kodeMataKuliah: kodeMataKuliah,
      mataKuliah: mataKuliah,
      pertemuanKe: pertemuanKe,
      isDosenView: false,
    );
  }
}
