import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../../services/api_service.dart';
import 'presensi_kelas_dosen_screen.dart';
import 'presensi_monitoring_tu_screen.dart';
import 'presensi_rekap_dosen_screen.dart';

class PresensiDosenScreen extends StatefulWidget {
  final String headerTitle;
  final IconData headerIcon;

  const PresensiDosenScreen({
    super.key,
    this.headerTitle = 'Presensi Dosen',
    this.headerIcon = Icons.how_to_reg_rounded,
  });

  @override
  State<PresensiDosenScreen> createState() => _PresensiDosenScreenState();
}

class _PresensiDosenScreenState extends State<PresensiDosenScreen> {
  final ApiService _apiService = ApiService();

  List<_PresensiDosenItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPresensi();
  }

  Future<void> _loadPresensi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final html = await _apiService.fetchPresensiPage();
      final items = _parsePresensiDosenHtml(html ?? '');
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<_PresensiDosenItem> _parsePresensiDosenHtml(String html) {
    final doc = html_parser.parse(html);
    final rows = doc.querySelectorAll('table tbody tr');
    final result = <_PresensiDosenItem>[];

    for (final row in rows) {
      final tds = row.querySelectorAll('td');
      if (tds.length < 9) continue;

      final prodi = tds[1].text.trim();
      final kodeMk = tds[2].text.trim();
      final namaMk = tds[3].text.trim();
      final kelas = tds[4].text.trim();
      final jadwal = tds[5].text.trim();
      final dosen = tds[6].text.trim();
      final pesertaRaw = tds[7].text.trim();

      final aksiCell = tds[8];
      String? presensiKelasUrl;
      String? rekapUrl;
      String? monitoringKode;

      for (final anchor in aksiCell.querySelectorAll('a')) {
        final text = anchor.text.trim().toLowerCase();
        final href = anchor.attributes['href'];
        if (text.contains('presensi kelas') &&
            href != null &&
            href.isNotEmpty) {
          presensiKelasUrl = href;
        } else if (text.contains('rekap presensi') &&
            href != null &&
            href.isNotEmpty) {
          rekapUrl = href;
        }

        final onClick = anchor.attributes['onclick'] ?? '';
        final m = RegExp(r"presensi_dosen\('([^']+)'\)").firstMatch(onClick);
        if (m != null) {
          monitoringKode = m.group(1);
        }
      }

      if (namaMk.isEmpty && kodeMk.isEmpty) continue;

      result.add(
        _PresensiDosenItem(
          prodi: prodi,
          kodeMk: kodeMk,
          namaMk: namaMk,
          kelas: kelas,
          jadwal: jadwal,
          dosen: dosen,
          peserta: pesertaRaw,
          presensiKelasUrl: presensiKelasUrl,
          rekapPresensiUrl: rekapUrl,
          monitoringKode: monitoringKode,
        ),
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 40,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF073163),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 0, bottom: 15),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.headerIcon, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    widget.headerTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              background: Container(
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
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _isLoading ? null : _loadPresensi,
              ),
            ],
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _errorMessage != null
                  ? SliverFillRemaining(
                      child: Center(child: Text(_errorMessage!)),
                    )
                  : _items.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                              child: Text('Tidak ada data presensi dosen')),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildCard(_items[index]),
                              childCount: _items.length,
                            ),
                          ),
                        ),
        ],
      ),
    );
  }

  Widget _buildCard(_PresensiDosenItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1.5,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.namaMk,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text('${item.kodeMk} • Kelas ${item.kelas}'),
              const SizedBox(height: 4),
              Text(item.jadwal),
              const SizedBox(height: 4),
              Text('Peserta: ${item.peserta}'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: item.presensiKelasUrl == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PresensiKelasDosenScreen(
                                  kelasUrl: item.presensiKelasUrl!,
                                  title: item.namaMk,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text('Presensi Kelas'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: item.rekapPresensiUrl == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PresensiRekapDosenScreen(
                                  rekapUrl: item.rekapPresensiUrl!,
                                  title: 'Rekap ${item.namaMk}',
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.summarize_rounded),
                    label: const Text('Rekap'),
                  ),
                  OutlinedButton.icon(
                    onPressed: item.monitoringKode == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    PresensiMonitoringTuScreen(
                                  monitoringKode: item.monitoringKode!,
                                  title: 'Monitoring ${item.namaMk}',
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.desktop_windows_rounded),
                    label: const Text('Monitoring TU'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresensiDosenItem {
  final String prodi;
  final String kodeMk;
  final String namaMk;
  final String kelas;
  final String jadwal;
  final String dosen;
  final String peserta;
  final String? presensiKelasUrl;
  final String? rekapPresensiUrl;
  final String? monitoringKode;

  const _PresensiDosenItem({
    required this.prodi,
    required this.kodeMk,
    required this.namaMk,
    required this.kelas,
    required this.jadwal,
    required this.dosen,
    required this.peserta,
    required this.presensiKelasUrl,
    required this.rekapPresensiUrl,
    required this.monitoringKode,
  });
}
