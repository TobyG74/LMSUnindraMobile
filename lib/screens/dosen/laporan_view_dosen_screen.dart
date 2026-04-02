import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import 'laporan_form_dosen_screen.dart';

class LaporanViewDosenScreen extends StatefulWidget {
  final String detailUrl;
  final String? title;

  const LaporanViewDosenScreen({
    super.key,
    required this.detailUrl,
    this.title,
  });

  @override
  State<LaporanViewDosenScreen> createState() => _LaporanViewDosenScreenState();
}

class _LaporanViewDosenScreenState extends State<LaporanViewDosenScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isGenerating = false;
  String? _errorMessage;

  final Map<String, String> _classInfo = {};
  List<_RpsRow> _rows = [];

  String? _kdJdwCetak;
  String? _kdJdwGenerate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final html = await _apiService.fetchPageByUrl(widget.detailUrl);
      if (html == null || html.isEmpty) {
        setState(() {
          _errorMessage = 'Data detail laporan tidak ditemukan.';
          _isLoading = false;
        });
        return;
      }

      final doc = html_parser.parse(html);
      _classInfo
        ..clear()
        ..addAll(_parseClassInfo(doc));
      final actions = _parseTopAction(doc);
      _kdJdwCetak = actions.$1;
      _kdJdwGenerate = actions.$2;
      _rows = _parseRows(doc);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _normalize(String raw) {
    return raw.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Map<String, String> _parseClassInfo(dynamic doc) {
    final info = <String, String>{};
    final table = doc.querySelector(
          'div.box-info.table-responsive > table.table.table-striped',
        ) ??
        doc.querySelector('table.table.table-striped');
    if (table == null) return info;

    for (final tr in table.querySelectorAll('tr')) {
      final children = tr.children;
      for (int i = 0; i < children.length; i++) {
        final cell = children[i];
        if (cell.localName != 'th') continue;

        final key = _normalize(cell.text).replaceAll(RegExp(r':+$'), '');
        if (key.isEmpty) continue;

        String value = '';
        for (int j = i + 1; j < children.length; j++) {
          final next = children[j];
          if (next.localName == 'th') break;
          if (next.localName != 'td') continue;
          final candidate = _normalize(next.text);
          if (candidate.isNotEmpty && candidate != ':') {
            value = candidate;
            break;
          }
        }

        if (value.isNotEmpty) {
          info[key] = value;
        }
      }
    }

    return info;
  }

  (String?, String?) _parseTopAction(dynamic doc) {
    String? cetak;
    String? generate;

    for (final anchor in doc.querySelectorAll('a')) {
      final onClick = anchor.attributes['onclick'] ?? '';

      final mCetak = RegExp(r"cetak_rps\('([^']+)'\)").firstMatch(onClick);
      if (mCetak != null) {
        cetak = mCetak.group(1);
      }

      final mGenerate =
          RegExp(r"generate_rps\('([^']+)'\)").firstMatch(onClick);
      if (mGenerate != null) {
        generate = mGenerate.group(1);
      }
    }

    return (cetak, generate);
  }

  List<_RpsRow> _parseRows(dynamic doc) {
    dynamic targetTable;
    for (final table in doc.querySelectorAll('table')) {
      final headers = table
          .querySelectorAll('thead th')
          .map((th) => _normalize(th.text).toLowerCase())
          .toList();
      if (headers.contains('materi rps') &&
          headers.contains('realisasi') &&
          headers.contains('aksi')) {
        targetTable = table;
        break;
      }
    }

    if (targetTable == null) return <_RpsRow>[];

    final result = <_RpsRow>[];
    for (final tr in targetTable.querySelectorAll('tbody tr')) {
      final tds = tr.querySelectorAll('td');
      if (tds.length < 10) continue;

      String? editKode;
      String? deleteUrl;
      final aksiCell = tds[9];
      for (final a in aksiCell.querySelectorAll('a')) {
        final onClick = a.attributes['onclick'] ?? '';
        final m = RegExp(r"ubah_rps\('([^']+)'\)").firstMatch(onClick);
        if (m != null) {
          editKode = m.group(1);
        }
        final href = (a.attributes['href'] ?? '').trim();
        if (href.contains('/rps/hapus_pertemuan/')) {
          deleteUrl = href;
        }
      }

      result.add(
        _RpsRow(
          no: _normalize(tds[0].text),
          tanggalWaktu: tds[1].text.replaceAll('\u00A0', ' ').trim(),
          ruang: _normalize(tds[2].text),
          subCpmk: _normalize(tds[3].text),
          kemampuan: _normalize(tds[4].text),
          materiRps: _normalize(tds[5].text),
          realisasi: _normalize(tds[6].text),
          tglRealisasi: _normalize(tds[7].text),
          sesuai: _normalize(tds[8].text),
          editKode: editKode,
          deleteUrl: deleteUrl,
        ),
      );
    }

    return result;
  }

  Future<void> _generateRps() async {
    final kode = _kdJdwGenerate;
    if (kode == null || kode.isEmpty || _isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final message = await _apiService.generateRps(kode);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Generate RPS'),
          content: Text(
            message?.isNotEmpty == true
                ? message!
                : 'Generate RPS selesai diproses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal generate RPS: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _cetakRps() async {
    final kode = _kdJdwCetak;
    if (kode == null || kode.isEmpty || _isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final fileName = await _apiService.generateRpsPdf(kode);
      if (!mounted) return;

      if (fileName == null || fileName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat file PDF laporan.')),
        );
        return;
      }

      await _downloadAndOpenPdf(fileName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal cetak laporan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _downloadAndOpenPdf(String fileName) async {
    bool isGranted = false;

    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted) {
      isGranted = true;
    } else {
      var status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        isGranted = true;
      } else {
        status = await Permission.storage.request();
        if (status.isGranted) {
          isGranted = true;
        }
      }
    }

    if (!isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin penyimpanan diperlukan.')),
      );
      return;
    }

    try {
      Directory baseDir;
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0/Documents');
        if (!await baseDir.exists()) {
          baseDir = Directory('/storage/emulated/0/Download');
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      final lmsDir = Directory('${baseDir.path}/LMS');
      final rpsDir = Directory('${lmsDir.path}/Laporan Perkuliahan');
      if (!await lmsDir.exists()) await lmsDir.create(recursive: true);
      if (!await rpsDir.exists()) await rpsDir.create(recursive: true);

      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final savePath = '${rpsDir.path}/$safeName';
      final encodedName = Uri.encodeComponent(fileName);
      final url =
          '${ApiService.baseUrl}/lms_publik/rps/$encodedName?uid=${DateTime.now().millisecondsSinceEpoch}';

      final result = await _apiService.downloadByUrl(url, savePath);
      if (result == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh PDF laporan.')),
        );
        return;
      }

      final openResult = await OpenFilex.open(savePath);
      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File tersimpan di: $savePath')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unduh PDF: $e')),
      );
    }
  }

  Future<void> _openEdit(String kode) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => LaporanFormDosenScreen(editKode: kode),
      ),
    );

    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _hapus(String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Laporan'),
        content: const Text('Yakin mau dihapus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _apiService.deleteRpsPertemuan(url);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus laporan.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Laporan berhasil dihapus.')),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Detail Laporan'),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF073163), Color(0xFF1756A5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_errorMessage!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_classInfo.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informasi Kelas',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._classInfo.entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 140,
                                        child: Text(
                                          e.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Text(': '),
                                      Expanded(child: Text(e.value)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isGenerating ? null : _cetakRps,
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Cetak Laporan'),
                        ),
                        FilledButton.icon(
                          onPressed: _isGenerating ? null : _generateRps,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                              _isGenerating ? 'Memproses...' : 'Generate RPS'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_rows.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Belum ada data laporan pertemuan.'),
                        ),
                      ),
                    ..._rows.map(_buildRowCard),
                  ],
                ),
    );
  }

  Widget _buildRowCard(_RpsRow row) {
    String safeText(String value) {
      final text = value.trim();
      return text.isEmpty ? '-' : text;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Pertemuan ${row.no}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A2A57),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.schedule_rounded, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    safeText(row.tanggalWaktu),
                    style: TextStyle(color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildInfoLine('Ruang', safeText(row.ruang)),
            const SizedBox(height: 6),
            _buildInfoLine('Sub-CPMK', safeText(row.subCpmk)),
            const SizedBox(height: 6),
            _buildInfoLine('Kemampuan', safeText(row.kemampuan)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoLine('Materi RPS', safeText(row.materiRps)),
                  const SizedBox(height: 8),
                  _buildInfoLine('Realisasi', safeText(row.realisasi)),
                  const SizedBox(height: 8),
                  _buildInfoLine('Tgl Realisasi', safeText(row.tglRealisasi)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: row.editKode == null
                      ? null
                      : () => _openEdit(row.editKode!),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Ubah'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                  ),
                  onPressed: row.deleteUrl == null
                      ? null
                      : () => _hapus(row.deleteUrl!),
                  child: const Text('Hapus'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const Text(': '),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _RpsRow {
  final String no;
  final String tanggalWaktu;
  final String ruang;
  final String subCpmk;
  final String kemampuan;
  final String materiRps;
  final String realisasi;
  final String tglRealisasi;
  final String sesuai;
  final String? editKode;
  final String? deleteUrl;

  const _RpsRow({
    required this.no,
    required this.tanggalWaktu,
    required this.ruang,
    required this.subCpmk,
    required this.kemampuan,
    required this.materiRps,
    required this.realisasi,
    required this.tglRealisasi,
    required this.sesuai,
    required this.editKode,
    required this.deleteUrl,
  });
}
