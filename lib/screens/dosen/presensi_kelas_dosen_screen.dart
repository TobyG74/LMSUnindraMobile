import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../../services/api_service.dart';
import 'presensi_peserta_dosen_screen.dart';
import 'presensi_rekap_dosen_screen.dart';

class PresensiKelasDosenScreen extends StatefulWidget {
  final String kelasUrl;
  final String? title;

  const PresensiKelasDosenScreen({
    super.key,
    required this.kelasUrl,
    this.title,
  });

  @override
  State<PresensiKelasDosenScreen> createState() =>
      _PresensiKelasDosenScreenState();
}

class _PresensiKelasDosenScreenState extends State<PresensiKelasDosenScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  String? _rekapUrl;
  final Map<String, String> _kelasInfo = {};
  List<_PertemuanRow> _rows = [];

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
      final html = await _apiService.fetchPageByUrl(widget.kelasUrl);
      if (html == null || html.isEmpty) {
        setState(() {
          _errorMessage = 'Data presensi kelas tidak ditemukan.';
          _isLoading = false;
        });
        return;
      }

      final doc = html_parser.parse(html);
      _rekapUrl = _extractRekapUrl(doc);
      _kelasInfo
        ..clear()
        ..addAll(_parseClassInfo(doc));
      _rows = _parsePertemuanRows(doc);

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

  String? _extractRekapUrl(dynamic doc) {
    for (final anchor in doc.querySelectorAll('a')) {
      final text = anchor.text.trim().toLowerCase();
      final href = anchor.attributes['href'];
      if (text.contains('rekap presensi') && href != null && href.isNotEmpty) {
        return href;
      }
    }
    return null;
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

        final key = _normalizeCellText(cell.text);
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

  String _normalizeCellText(String raw) {
    return raw.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<_PertemuanRow> _parsePertemuanRows(dynamic doc) {
    final result = <_PertemuanRow>[];
    dynamic table;

    for (final t in doc.querySelectorAll('table')) {
      final headerTexts = t
          .querySelectorAll('thead th')
          .map((e) => e.text.trim().toLowerCase())
          .toList();
      if (headerTexts.contains('status absen') &&
          headerTexts.contains('materi rps') &&
          headerTexts.contains('realisasi')) {
        table = t;
        break;
      }
    }

    if (table == null) return result;

    for (final tr in table.querySelectorAll('tbody tr')) {
      final tds = tr.querySelectorAll('td');
      if (tds.length < 8) continue;

      String? kdJadwal;
      String? pertemuan;

      final aksiAnchor = tds[7].querySelector('a');
      if (aksiAnchor != null) {
        final onClick = aksiAnchor.attributes['onclick'] ?? '';
        final m =
            RegExp(r"absensi\('([^']+)',\s*'([^']+)'\)").firstMatch(onClick);
        if (m != null) {
          kdJadwal = m.group(1);
          pertemuan = m.group(2);
        }
      }

      result.add(
        _PertemuanRow(
          no: _normalizeCellText(tds[0].text),
          tanggal: tds[1].text.replaceAll('\u00A0', ' ').trim(),
          materiRps: _normalizeCellText(tds[2].text),
          realisasi: _normalizeCellText(tds[3].text),
          statusAbsen: _normalizeCellText(tds[4].text),
          peserta: _normalizeCellText(tds[5].text),
          hadir: _normalizeCellText(tds[6].text),
          kdJadwal: kdJadwal,
          pertemuan: pertemuan,
        ),
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.title ?? 'Presensi Kelas Dosen'),
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_kelasInfo.isNotEmpty)
                      _InfoCard(info: _kelasInfo, rekapUrl: _rekapUrl),
                    const SizedBox(height: 12),
                    const Text(
                      'Daftar Pertemuan',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (_rows.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('Belum ada data pertemuan.'),
                        ),
                      ),
                    ..._rows.map((row) => _buildPertemuanCard(row)),
                  ],
                ),
    );
  }

  Widget _buildPertemuanCard(_PertemuanRow row) {
    final statusOk = row.statusAbsen.toUpperCase() == 'Y';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pertemuan ${row.no}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (statusOk ? Colors.green : Colors.orange)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusOk ? 'Absen Aktif' : 'Belum Aktif',
                    style: TextStyle(
                      color: statusOk ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(row.tanggal),
            const SizedBox(height: 6),
            Text('Materi RPS: ${row.materiRps.isEmpty ? '-' : row.materiRps}'),
            const SizedBox(height: 4),
            Text('Realisasi: ${row.realisasi.isEmpty ? '-' : row.realisasi}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Peserta: ${row.peserta}'),
                const SizedBox(width: 12),
                Text('Hadir: ${row.hadir}'),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: (row.kdJadwal == null || row.pertemuan == null)
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PresensiPesertaDosenScreen(
                            kdJdw: row.kdJadwal!,
                            pertemuan: row.pertemuan!,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.group_rounded),
              label: const Text('Presensi Peserta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Map<String, String> info;
  final String? rekapUrl;

  const _InfoCard({
    required this.info,
    required this.rekapUrl,
  });

  @override
  Widget build(BuildContext context) {
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
            ...info.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        e.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text(': '),
                    Expanded(child: Text(e.value)),
                  ],
                ),
              ),
            ),
            if (rekapUrl != null && rekapUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PresensiRekapDosenScreen(
                        rekapUrl: rekapUrl!,
                        title: 'Rekap Presensi',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.summarize_rounded),
                label: const Text('Lihat Rekap Presensi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PertemuanRow {
  final String no;
  final String tanggal;
  final String materiRps;
  final String realisasi;
  final String statusAbsen;
  final String peserta;
  final String hadir;
  final String? kdJadwal;
  final String? pertemuan;

  const _PertemuanRow({
    required this.no,
    required this.tanggal,
    required this.materiRps,
    required this.realisasi,
    required this.statusAbsen,
    required this.peserta,
    required this.hadir,
    required this.kdJadwal,
    required this.pertemuan,
  });
}
