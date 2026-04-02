import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import 'nilai_form_dosen_screen.dart';

class NilaiViewDosenScreen extends StatefulWidget {
  final String detailUrl;
  final String? title;

  const NilaiViewDosenScreen({
    super.key,
    required this.detailUrl,
    this.title,
  });

  @override
  State<NilaiViewDosenScreen> createState() => _NilaiViewDosenScreenState();
}

class _NilaiViewDosenScreenState extends State<NilaiViewDosenScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String? _errorMessage;
  String? _kdJdw;
  final Map<String, String> _classInfo = {};
  final Map<String, String> _formUrls = {};
  final List<_NilaiMahasiswaRow> _rows = [];

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
          _errorMessage = 'Data nilai kelas tidak ditemukan.';
          _isLoading = false;
        });
        return;
      }

      final doc = html_parser.parse(html);

      _classInfo
        ..clear()
        ..addAll(_parseClassInfo(doc));
      _formUrls
        ..clear()
        ..addAll(_parseFormUrls(doc));
      _rows
        ..clear()
        ..addAll(_parseRows(doc));
      _kdJdw = _parseKdJdw(doc);

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

  String? _parseKdJdw(dynamic doc) {
    for (final element in doc.querySelectorAll('button, a')) {
      final onClick = element.attributes['onclick'] ?? '';
      final match = RegExp(r"cetak_nilai\('([^']+)'\s*,\s*'(uts|uas|akhir)'\)")
          .firstMatch(onClick);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  Map<String, String> _parseFormUrls(dynamic doc) {
    final result = <String, String>{};
    final orderedUrls = <String>[];

    String normalizeUrl(String raw) {
      final href = raw.trim();
      if (href.isEmpty) return '';
      if (href.startsWith('http://') || href.startsWith('https://')) {
        final uri = Uri.tryParse(href);
        if (uri != null && uri.host.contains('lms.unindra.ac.id')) {
          final path = uri.path.isEmpty ? '/' : uri.path;
          final query = uri.hasQuery ? '?${uri.query}' : '';
          return '$path$query';
        }
        return href;
      }
      if (href.startsWith('/')) {
        return href;
      }
      return '/$href';
    }

    for (final anchor in doc.querySelectorAll('a[href*="nilai_form"]')) {
      final href = normalizeUrl(anchor.attributes['href'] ?? '');
      if (href.isEmpty) continue;
      orderedUrls.add(href);

      final text = _normalize(anchor.text).toLowerCase();
      final parentTitle = _normalize(
        anchor.parent?.attributes['title'] ?? '',
      ).toLowerCase();

      final marker = '$text $parentTitle';
      if (marker.contains('tugas') || marker.contains('tgs')) {
        result['tgs'] = href;
      } else if (marker.contains('uts')) {
        result['uts'] = href;
      } else if (marker.contains('uas')) {
        result['uas'] = href;
      }
    }

    // Fallback mengikuti urutan kolom nilai pada halaman LMS: TGS, UTS, UAS.
    if (!result.containsKey('tgs') && orderedUrls.isNotEmpty) {
      result['tgs'] = orderedUrls[0];
    }
    if (!result.containsKey('uts') && orderedUrls.length >= 2) {
      result['uts'] = orderedUrls[1];
    }
    if (!result.containsKey('uas') && orderedUrls.length >= 3) {
      result['uas'] = orderedUrls[2];
    }

    return result;
  }

  List<_NilaiMahasiswaRow> _parseRows(dynamic doc) {
    dynamic table;
    for (final t in doc.querySelectorAll('table')) {
      final List<String> headers = t
          .querySelectorAll('thead th')
          .map<String>((dynamic th) => _normalize(th.text).toLowerCase())
          .toList();
      if (headers.contains('mahasiswa') &&
          headers.any((String h) => h.contains('tgs'))) {
        table = t;
        break;
      }
    }

    if (table == null) return <_NilaiMahasiswaRow>[];

    final List<String> headerCells = table
        .querySelectorAll('thead tr')
        .first
        .querySelectorAll('th')
        .map<String>((dynamic th) => _cleanGradeHeader(_normalize(th.text)))
        .toList();

    final rows = <_NilaiMahasiswaRow>[];
    for (final tr in table.querySelectorAll('tbody tr')) {
      final tds = tr.querySelectorAll('td');
      if (tds.length < 3) continue;

      final values = <String, String>{};
      for (int i = 0; i < tds.length && i < headerCells.length; i++) {
        final key = headerCells[i].isEmpty ? 'COL_$i' : headerCells[i];
        values[key] = _normalize(tds[i].text);
      }

      final mahasiswaRaw = '${tds[1].text}';
      final mahasiswaLines = mahasiswaRaw
          .split('\n')
          .map((line) => _normalize(line))
          .where((String line) => line.isNotEmpty)
          .toList();

      String nim = '';
      String nama = '';

      if (mahasiswaLines.length >= 2) {
        nim = mahasiswaLines.first;
        nama = mahasiswaLines.sublist(1).join(' ');
      } else {
        final single = mahasiswaLines.isNotEmpty
            ? mahasiswaLines.first
            : _normalize(tds[1].text);
        final match = RegExp(r'^(\d{8,})\s+(.+)$').firstMatch(single);
        if (match != null) {
          nim = (match.group(1) ?? '').trim();
          nama = (match.group(2) ?? '').trim();
        } else {
          nim = single;
          nama = single;
        }
      }

      rows.add(
        _NilaiMahasiswaRow(
          nim: nim,
          nama: nama,
          nilaiMap: values,
        ),
      );
    }

    return rows;
  }

  String _cleanGradeHeader(String header) {
    if (header.isEmpty) return header;
    final cleaned = header
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
    return cleaned;
  }

  Future<void> _openForm(String key) async {
    final url = _formUrls[key];
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Form ${key.toUpperCase()} belum tersedia untuk kelas ini.'),
        ),
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NilaiFormDosenScreen(
          formUrl: url,
          title: 'Form Nilai ${key.toUpperCase()}',
        ),
      ),
    );

    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _cetakNilai(String jenis) async {
    if (_isGeneratingPdf) return;
    final kdJdw = _kdJdw;
    if (kdJdw == null || kdJdw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode jadwal tidak ditemukan.')),
      );
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final fileName =
          await _apiService.generateNilaiPdf(kdJdw: kdJdw, jenisNilai: jenis);
      if (!mounted) return;

      if (fileName == null || fileName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat file PDF nilai.')),
        );
        return;
      }

      await _downloadAndOpenPdf(fileName, jenis);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal cetak nilai: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<void> _downloadAndOpenPdf(String fileName, String jenis) async {
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
        const SnackBar(
          content: Text('Izin penyimpanan diperlukan untuk unduh PDF.'),
        ),
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
      final nilaiDir = Directory('${lmsDir.path}/Nilai');
      if (!await lmsDir.exists()) await lmsDir.create(recursive: true);
      if (!await nilaiDir.exists()) await nilaiDir.create(recursive: true);

      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final savePath = '${nilaiDir.path}/$safeName';
      final encodedName = Uri.encodeComponent(fileName);
      final url =
          '${ApiService.baseUrl}/lms_publik/nilai/$encodedName?uid=${DateTime.now().millisecondsSinceEpoch}';

      final downloaded = await _apiService.downloadByUrl(url, savePath);
      if (downloaded == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh PDF nilai.')),
        );
        return;
      }

      final openResult = await OpenFilex.open(savePath);
      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File $jenis tersimpan di: $savePath',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unduh PDF: $e')),
      );
    }
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: _isGeneratingPdf ? null : () => _cetakNilai('uts'),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Cetak UTS'),
        ),
        FilledButton.tonalIcon(
          onPressed: _isGeneratingPdf ? null : () => _cetakNilai('uas'),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Cetak UAS'),
        ),
        FilledButton.tonalIcon(
          onPressed: _isGeneratingPdf ? null : () => _cetakNilai('akhir'),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Cetak Nilai Akhir'),
        ),
        FilledButton.icon(
          onPressed: () => _openForm('tgs'),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Input Tugas'),
        ),
        FilledButton.icon(
          onPressed: () => _openForm('uts'),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Input UTS'),
        ),
        FilledButton.icon(
          onPressed: () => _openForm('uas'),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Input UAS'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Nilai Kelas'),
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
                            children: _classInfo.entries
                                .map(
                                  (e) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('${e.key}: ${e.value}'),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    _buildActionButtons(),
                    const SizedBox(height: 12),
                    const Text(
                      'Daftar Nilai Mahasiswa',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (_rows.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Belum ada data nilai mahasiswa.'),
                        ),
                      )
                    else
                      _buildMahasiswaTable(),
                  ],
                ),
    );
  }

  String _getNilaiValue(Map<String, String> nilaiMap, String key) {
    final direct = (nilaiMap[key] ?? '').trim();
    if (direct.isNotEmpty) return direct;

    for (final entry in nilaiMap.entries) {
      if (entry.key.trim().toUpperCase() == key) {
        final value = entry.value.trim();
        return value.isEmpty ? '-' : value;
      }
    }

    return '-';
  }

  Widget _buildMahasiswaTable() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => const Color(0xFFEAF1FF),
          ),
          columns: const [
            DataColumn(label: Text('No')),
            DataColumn(label: Text('NIM')),
            DataColumn(label: Text('Nama')),
            DataColumn(label: Text('PRE')),
            DataColumn(label: Text('TGS')),
            DataColumn(label: Text('UTS')),
            DataColumn(label: Text('UAS')),
            DataColumn(label: Text('NAK')),
            DataColumn(label: Text('NH')),
            DataColumn(label: Text('NA')),
          ],
          rows: List<DataRow>.generate(_rows.length, (index) {
            final row = _rows[index];
            return DataRow(
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text(row.nim)),
                DataCell(SizedBox(width: 220, child: Text(row.nama))),
                DataCell(Text(_getNilaiValue(row.nilaiMap, 'PRE'))),
                DataCell(Text(_getNilaiValue(row.nilaiMap, 'TGS'))),
                DataCell(Text(_getNilaiValue(row.nilaiMap, 'UTS'))),
                DataCell(Text(_getNilaiValue(row.nilaiMap, 'UAS'))),
                DataCell(Text(_getNilaiValue(row.nilaiMap, 'NAK'))),
                DataCell(Text(_getNilaiValue(row.nilaiMap, 'NH'))),
                DataCell(Text(_getNilaiValue(row.nilaiMap, 'NA'))),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _NilaiMahasiswaRow {
  final String nim;
  final String nama;
  final Map<String, String> nilaiMap;

  _NilaiMahasiswaRow({
    required this.nim,
    required this.nama,
    required this.nilaiMap,
  });
}
