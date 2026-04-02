import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import 'presensi_kelas_dosen_screen.dart';

class PresensiRekapDosenScreen extends StatefulWidget {
  final String rekapUrl;
  final String? title;

  const PresensiRekapDosenScreen({
    super.key,
    required this.rekapUrl,
    this.title,
  });

  @override
  State<PresensiRekapDosenScreen> createState() =>
      _PresensiRekapDosenScreenState();
}

class _PresensiRekapDosenScreenState extends State<PresensiRekapDosenScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String? _errorMessage;
  final Map<String, String> _classInfo = {};
  List<String> _meetingHeaders = [];
  List<_RekapRow> _rows = [];
  String? _presensiKelasUrl;
  String? _cetakKode;

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
      final html = await _apiService.fetchPageByUrl(widget.rekapUrl);
      if (html == null || html.isEmpty) {
        setState(() {
          _errorMessage = 'Data rekap tidak ditemukan.';
          _isLoading = false;
        });
        return;
      }

      final doc = html_parser.parse(html);
      _classInfo
        ..clear()
        ..addAll(_parseClassInfo(doc));
      final rekapAction = _parseRekapActionData(doc);
      _presensiKelasUrl = rekapAction.$1;
      _cetakKode = rekapAction.$2;
      final parsed = _parseRekapTable(doc);
      _meetingHeaders = List<String>.from(parsed.$1);
      _rows = List<_RekapRow>.from(parsed.$2);

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

  Map<String, String> _parseClassInfo(dynamic doc) {
    final info = <String, String>{};
    final table = doc.querySelector(
          'div.content-wrapper div.box-info.table-responsive > table.table.table-striped',
        ) ??
        doc.querySelector('div.box-info table.table.table-striped') ??
        doc.querySelector('table.table.table-striped');
    if (table == null) return info;

    for (final tr in table.querySelectorAll('tr')) {
      final children = tr.children;
      for (int i = 0; i < children.length; i++) {
        final cell = children[i];
        if (cell.localName != 'th') continue;

        final key = _normalizeLabel(cell.text);
        if (key.isEmpty) continue;

        String value = '';
        for (int j = i + 1; j < children.length; j++) {
          final nextCell = children[j];
          if (nextCell.localName == 'th') break;
          if (nextCell.localName != 'td') continue;

          final candidate = _normalizeCellText(nextCell.text);
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

  String _normalizeLabel(String raw) {
    return _normalizeCellText(raw).replaceAll(RegExp(r':+$'), '');
  }

  (String?, String?) _parseRekapActionData(dynamic doc) {
    String? presensiKelasUrl;
    String? cetakKode;

    final actionArea = doc.querySelector('div.box-header div.box-tools');
    if (actionArea == null) {
      return (null, null);
    }

    for (final anchor in actionArea.querySelectorAll('a')) {
      final text = _normalizeCellText(anchor.text).toLowerCase();
      final href = anchor.attributes['href'];
      final onClick = anchor.attributes['onclick'] ?? '';

      if (text.contains('presensi kelas') && href != null && href.isNotEmpty) {
        presensiKelasUrl = href;
      }

      final m =
          RegExp(r"cetak_rekap_presensi\('([^']+)'\)").firstMatch(onClick);
      if (m != null) {
        cetakKode = m.group(1);
      }
    }

    return (presensiKelasUrl, cetakKode);
  }

  (List<String>, List<_RekapRow>) _parseRekapTable(dynamic doc) {
    dynamic rekapTable;
    for (final table in doc.querySelectorAll('table')) {
      final firstHeader = <String>[];
      final headerRows = table.querySelectorAll('thead tr');
      for (final row in headerRows) {
        final thCells = row.querySelectorAll('th');
        for (final th in thCells) {
          firstHeader.add(_normalizeCellText(th.text).toLowerCase());
        }
      }

      if (firstHeader.contains('nim') &&
          firstHeader.contains('nama') &&
          firstHeader.any((h) => h.contains('persen'))) {
        rekapTable = table;
        break;
      }
    }

    if (rekapTable == null) {
      return (<String>[], <_RekapRow>[]);
    }

    final meetingHeaders = <String>[];
    final headerRows = rekapTable.querySelectorAll('thead tr');
    if (headerRows.length >= 2) {
      final secondRowTh = headerRows[1].querySelectorAll('th');
      for (final th in secondRowTh) {
        final text = _normalizeCellText(th.text);
        if (int.tryParse(text) != null) {
          meetingHeaders.add(text);
        }
      }
    }

    final rows = <_RekapRow>[];
    for (final tr in rekapTable.querySelectorAll('tbody tr')) {
      final tds = tr.querySelectorAll('td');
      if (tds.length < 4) continue;

      final no = _normalizeCellText(tds[0].text);
      final nim = _normalizeCellText(tds[1].text);
      final nama = _normalizeCellText(tds[2].text);
      final persen = _normalizeCellText(tds.last.text);

      final statusCells = tds.sublist(3, tds.length - 1);
      final statuses = List<String>.from(
        statusCells.map((td) => _parseStatusCell(td)),
      );

      if (meetingHeaders.isEmpty) {
        meetingHeaders.addAll(
          List.generate(statuses.length, (i) => '${i + 1}'),
        );
      }

      rows.add(
        _RekapRow(
          no: no,
          nim: nim,
          nama: nama,
          statuses: statuses,
          persen: persen,
        ),
      );
    }

    return (meetingHeaders, rows);
  }

  String _parseStatusCell(dynamic td) {
    final icon = td.querySelector('i');
    final iconClass = icon?.attributes['class'] ?? '';

    if (iconClass.contains('fa-calendar-check-o')) {
      return 'H';
    }
    if (iconClass.contains('fa-calendar-minus-o')) {
      return 'A';
    }

    final text = _normalizeCellText(td.text);
    return text.isEmpty ? '-' : text;
  }

  String _normalizeCellText(String raw) {
    return raw.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _openPresensiKelas() async {
    final raw = _presensiKelasUrl;
    if (raw == null || raw.isEmpty) return;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PresensiKelasDosenScreen(
          kelasUrl: raw,
          title: 'Presensi Kelas',
        ),
      ),
    );
  }

  Future<void> _cetakRekapPdf() async {
    final kdJdw = _cetakKode;
    if (kdJdw == null || kdJdw.isEmpty || _isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final fileName = await _apiService.generatePresensiRekapPdf(kdJdw);
      if (!mounted) return;

      if (fileName == null || fileName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat file PDF rekap.')),
        );
        return;
      }

      await _downloadAndOpenRekapPdf(fileName);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat cetak rekap.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<void> _downloadAndOpenRekapPdf(String fileName) async {
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
      final rekapDir = Directory('${lmsDir.path}/Rekap Presensi');

      if (!await lmsDir.exists()) await lmsDir.create(recursive: true);
      if (!await rekapDir.exists()) await rekapDir.create(recursive: true);

      final safeFileName =
          fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final savePath = '${rekapDir.path}/$safeFileName';

      final progressNotifier = ValueNotifier<double>(0.0);
      final receivedNotifier = ValueNotifier<int>(0);
      final totalNotifier = ValueNotifier<int>(0);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (context, progress, _) {
              return ValueListenableBuilder<int>(
                valueListenable: receivedNotifier,
                builder: (context, received, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: totalNotifier,
                    builder: (context, total, _) {
                      return AlertDialog(
                        title: const Text('Mengunduh PDF Rekap'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 16),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (total > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${(received / 1024 / 1024).toStringAsFixed(2)} MB / ${(total / 1024 / 1024).toStringAsFixed(2)} MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      }

      final encodedName = Uri.encodeComponent(fileName);
      final url =
          '${ApiService.baseUrl}/lms_publik/presensi/$encodedName?uid=${DateTime.now().millisecondsSinceEpoch}';

      final result = await _apiService.downloadByUrl(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
            receivedNotifier.value = received;
            totalNotifier.value = total;
          }
        },
      );

      progressNotifier.dispose();
      receivedNotifier.dispose();
      totalNotifier.dispose();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (result == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh PDF rekap.')),
        );
        return;
      }

      final openResult = await OpenFilex.open(savePath);
      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File tersimpan di: $savePath',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unduh PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Rekap Presensi Dosen'),
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
                    if (_classInfo.isNotEmpty) _buildInfoCard(),
                    const SizedBox(height: 10),
                    if (_meetingHeaders.isEmpty || _rows.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Rekap belum tersedia untuk kelas ini.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      _buildRekapTable(),
                  ],
                ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Kelas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._classInfo.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text(': '),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_presensiKelasUrl == null || _isLoading)
                    ? null
                    : _openPresensiKelas,
                icon: const Icon(Icons.groups_rounded),
                label: const Text('Presensi Kelas'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_cetakKode == null || _isLoading || _isGeneratingPdf)
                        ? null
                        : _cetakRekapPdf,
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_rounded),
                label: Text(
                    _isGeneratingPdf ? 'Mencetak Rekap...' : 'Cetak Rekap PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRekapTable() {
    final columns = <DataColumn>[
      const DataColumn(label: Text('No')),
      const DataColumn(label: Text('NIM')),
      const DataColumn(label: Text('Nama')),
      ..._meetingHeaders.map((h) => DataColumn(label: Text(h))),
      const DataColumn(label: Text('Persen')),
    ];

    final rows = _rows
        .map(
          (row) => DataRow(
            cells: [
              DataCell(Text(row.no)),
              DataCell(Text(row.nim)),
              DataCell(SizedBox(width: 180, child: Text(row.nama))),
              ...List.generate(_meetingHeaders.length, (index) {
                final status =
                    index < row.statuses.length ? row.statuses[index] : '-';
                if (status == 'H') {
                  return const DataCell(
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: Colors.green),
                  );
                }
                if (status == 'A') {
                  return const DataCell(
                    Icon(Icons.cancel_rounded, size: 18, color: Colors.red),
                  );
                }
                return DataCell(Text(status));
              }),
              DataCell(Text(row.persen)),
            ],
          ),
        )
        .toList();

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: columns, rows: rows),
      ),
    );
  }
}

class _RekapRow {
  final String no;
  final String nim;
  final String nama;
  final List<String> statuses;
  final String persen;

  const _RekapRow({
    required this.no,
    required this.nim,
    required this.nama,
    required this.statuses,
    required this.persen,
  });
}
