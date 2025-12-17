import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/presensi_model.dart';
import '../services/api_service.dart';

class PresensiScreen extends StatefulWidget {
  const PresensiScreen({super.key});

  @override
  State<PresensiScreen> createState() => _PresensiScreenState();
}

class _PresensiScreenState extends State<PresensiScreen> {
  final ApiService _apiService = ApiService();
  List<PresensiItem> _presensiList = [];
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
      final items = _parsePresensiHtml(html ?? '');
      
      setState(() {
        _presensiList = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<PresensiItem> _parsePresensiHtml(String html) {
    final document = html_parser.parse(html);
    final List<PresensiItem> items = [];

    // Ambil semua baris di tabel
    final rows = document.querySelectorAll('table tbody tr');

    for (var row in rows) {
      try {
        final tds = row.querySelectorAll('td');
        if (tds.length < 10) continue;

        String kode = tds[1].text.trim();
        String mataKuliah = tds[2].text.trim();
        String dosen = tds[3].text.trim();
        String kelas = tds[4].text.trim();
        String hari = tds[5].text.trim();
        String waktu = tds[6].text.trim();
        String ruang = tds[7].text.trim();
        
        // Parsing pertemuan dan kehadiran
        int pertemuanTerlaksana = 0;
        int totalPertemuan = 16;
        int persentasePertemuan = 0;
        
        final pertemuanText = tds[8].text.trim();
        final pertemuanMatch = RegExp(r'(\d+)/(\d+)').firstMatch(pertemuanText);
        if (pertemuanMatch != null) {
          pertemuanTerlaksana = int.tryParse(pertemuanMatch.group(1) ?? '0') ?? 0;
          totalPertemuan = int.tryParse(pertemuanMatch.group(2) ?? '16') ?? 16;
          if (totalPertemuan > 0) {
            persentasePertemuan = ((pertemuanTerlaksana / totalPertemuan) * 100).round();
          }
        }
        
        int persentaseKehadiran = 0;
        final kehadiranText = tds[9].text.trim();
        final kehadiranMatch = RegExp(r'(\d+)%').firstMatch(kehadiranText);
        if (kehadiranMatch != null) {
          persentaseKehadiran = int.tryParse(kehadiranMatch.group(1) ?? '0') ?? 0;
        }
        
        // Ambil ID dari onClick
        String encryptedJadwalId = '';
        String encryptedNim = '';
        
        final onClickAttr = tds[9].attributes['onClick'] ?? '';
        final onClickMatch = RegExp(r"absensi_mhs\('([^']+)',\s*'([^']+)'\)").firstMatch(onClickAttr);
        if (onClickMatch != null) {
          encryptedJadwalId = onClickMatch.group(1) ?? '';
          encryptedNim = onClickMatch.group(2) ?? '';
        }

        if (kode.isNotEmpty && mataKuliah.isNotEmpty) {
          items.add(PresensiItem(
            kode: kode,
            mataKuliah: mataKuliah,
            dosen: dosen,
            kelas: kelas,
            hari: hari,
            waktu: waktu,
            ruang: ruang,
            pertemuanTerlaksana: pertemuanTerlaksana,
            totalPertemuan: totalPertemuan,
            persentasePertemuan: persentasePertemuan,
            persentaseKehadiran: persentaseKehadiran,
            encryptedJadwalId: encryptedJadwalId,
            encryptedNim: encryptedNim,
          ));
        }
      } catch (e) {
        print('Error parsing presensi row: $e');
        continue;
      }
    }

    return items;
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
              title: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_reg_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Presensi',
                    style: TextStyle(
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
                    colors: [Color(0xFF073163), Color(0xFF1756a5)],
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
                tooltip: 'Refresh',
              ),
            ],
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _errorMessage != null
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 64,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Gagal memuat presensi',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _loadPresensi,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF073163),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _presensiList.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Tidak ada data presensi',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final presensi = _presensiList[index];
                                return _buildPresensiCard(presensi);
                              },
                              childCount: _presensiList.length,
                            ),
                          ),
                        ),
        ],
      ),
    );
  }

  Widget _buildPresensiCard(PresensiItem presensi) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _showPresensiDetail(context, presensi);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF073163).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      presensi.kode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF073163),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      presensi.mataKuliah,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      presensi.dosen,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${presensi.hari}, ${presensi.waktu}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.room, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    presensi.ruang,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pertemuan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${presensi.pertemuanTerlaksana}/${presensi.totalPertemuan}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: presensi.persentasePertemuan / 100,
                          backgroundColor: Colors.grey[300],
                          color: const Color(0xFF00A65A),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Kehadiran',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${presensi.persentaseKehadiran}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: presensi.getKehadiranColor(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: presensi.persentaseKehadiran / 100,
                          backgroundColor: Colors.grey[300],
                          color: presensi.getKehadiranColor(),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresensiDetail(BuildContext context, PresensiItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.mataKuliah),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Kode', item.kode),
              _buildDetailRow('Dosen', item.dosen),
              _buildDetailRow('Kelas', item.kelas),
              _buildDetailRow('Hari', item.hari),
              _buildDetailRow('Waktu', item.waktu),
              _buildDetailRow('Ruang', item.ruang),
              const Divider(height: 24),
              _buildDetailRow(
                'Pertemuan Terlaksana',
                '${item.pertemuanTerlaksana}/${item.totalPertemuan} (${item.persentasePertemuan}%)',
              ),
              _buildDetailRow(
                'Persentase Kehadiran',
                '${item.persentaseKehadiran}%',
                color: item.getKehadiranColor(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color ?? Colors.grey[800],
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
