import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../../services/api_service.dart';
import 'nilai_view_dosen_screen.dart';

class NilaiDosenScreen extends StatefulWidget {
  const NilaiDosenScreen({super.key});

  @override
  State<NilaiDosenScreen> createState() => _NilaiDosenScreenState();
}

class _NilaiDosenScreenState extends State<NilaiDosenScreen> {
  final ApiService _apiService = ApiService();
  final List<Color> _palette = const [
    Color(0xFF3F51B5),
    Color(0xFF00897B),
    Color(0xFFE65100),
    Color(0xFF6A1B9A),
    Color(0xFF1565C0),
  ];

  bool _isLoading = true;
  String? _errorMessage;
  List<_NilaiKelasItem> _items = [];

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
      final html = await _apiService.fetchNilaiPage();
      if (html == null || html.isEmpty) {
        setState(() {
          _errorMessage = 'Data nilai tidak ditemukan.';
          _isLoading = false;
        });
        return;
      }

      final doc = html_parser.parse(html);
      final parsedItems = _parseRows(doc);

      setState(() {
        _items = parsedItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<_NilaiKelasItem> _parseRows(dynamic doc) {
    String normalize(String raw) {
      return raw
          .replaceAll('\u00A0', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    dynamic targetTable;
    for (final table in doc.querySelectorAll('table')) {
      final headers = table
          .querySelectorAll('thead th')
          .map((th) => normalize(th.text).toLowerCase())
          .toList();

      if (headers.contains('kode mk') &&
          headers.contains('nama mk') &&
          headers.contains('aksi')) {
        targetTable = table;
        break;
      }
    }

    if (targetTable == null) {
      return <_NilaiKelasItem>[];
    }

    final items = <_NilaiKelasItem>[];
    for (final tr in targetTable.querySelectorAll('tbody tr')) {
      final tds = tr.querySelectorAll('td');
      if (tds.length < 8) continue;

      final aksiCell = tds.last;
      final viewAnchor =
          aksiCell.querySelector('a[href*="/nilai/daftar_nilai/"]') ??
              aksiCell.querySelector('a[href]');
      final viewUrl = viewAnchor?.attributes['href'] ?? '';
      if (viewUrl.isEmpty) continue;

      // Format LMS saat ini memiliki kolom No di index 0.
      final hasNoColumn = tds.length >= 9;
      final offset = hasNoColumn ? 1 : 0;

      items.add(
        _NilaiKelasItem(
          prodi: normalize(tds[offset].text),
          kodeMk: normalize(tds[offset + 1].text),
          namaMk: normalize(tds[offset + 2].text),
          kelas: normalize(tds[offset + 3].text),
          jadwal: normalize(tds[offset + 4].text),
          dosen: normalize(tds[offset + 5].text),
          peserta: normalize(tds[offset + 6].text),
          detailUrl: viewUrl,
        ),
      );
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
                  Icon(Icons.grading_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Daftar Nilai',
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
                onPressed: _isLoading ? null : _loadData,
                icon: const Icon(Icons.refresh_rounded),
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
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  : _items.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(child: Text('Belum ada data nilai.')),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(12),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _items[index];
                                return _buildNilaiCard(item);
                              },
                              childCount: _items.length,
                            ),
                          ),
                        ),
        ],
      ),
    );
  }

  Color _getColorForNilaiCard(_NilaiKelasItem item) {
    final seed = '${item.kodeMk}-${item.kelas}'.runes.fold<int>(
          0,
          (sum, rune) => sum + rune,
        );
    return _palette[seed % _palette.length];
  }

  Widget _buildNilaiCard(_NilaiKelasItem item) {
    final cardColor = _getColorForNilaiCard(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NilaiViewDosenScreen(
                  detailUrl: item.detailUrl,
                  title: item.namaMk,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: cardColor, width: 4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cardColor.withOpacity(0.15),
                        cardColor.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.grading_rounded,
                    color: cardColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.namaMk,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.kodeMk,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Kelas ${item.kelas}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.jadwal,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Peserta: ${item.peserta} • ${item.dosen}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NilaiKelasItem {
  final String prodi;
  final String kodeMk;
  final String namaMk;
  final String kelas;
  final String jadwal;
  final String dosen;
  final String peserta;
  final String detailUrl;

  _NilaiKelasItem({
    required this.prodi,
    required this.kodeMk,
    required this.namaMk,
    required this.kelas,
    required this.jadwal,
    required this.dosen,
    required this.peserta,
    required this.detailUrl,
  });
}
