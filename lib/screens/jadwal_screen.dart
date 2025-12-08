import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/jadwal_model.dart';
import '../services/api_service.dart';
import 'pertemuan_list_screen.dart';

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  final ApiService _apiService = ApiService();
  List<JadwalItem> _jadwalList = [];
  bool _isLoading = true;
  String? _errorMessage;

  final Map<String, IconData> _iconMap = {
    'Rekayasa Perangkat Lunak': Icons.code,
    'Riset Operasional': Icons.analytics,
    'Etika Profesi': Icons.gavel,
    'Sistem Basis Pengetahuan': Icons.storage,
    'Sistem Berbasis Pengetahuan': Icons.storage,
    'Filsafat Ilmu': Icons.school,
    'E-Commerce': Icons.shopping_cart,
    'Komputer Grafik': Icons.brush,
    'Keamanan Komputer': Icons.security,
    'Algoritma': Icons.account_tree,
    'Bahasa Indonesia': Icons.translate,
    'Bahasa Inggris': Icons.language,
    'Kalkulus Dasar': Icons.functions,
    'Kalkulus Lanjut': Icons.calculate,
    'Pancasila': Icons.flag,
    'Pemrograman': Icons.code,
    'Pendidikan Agama Islam': Icons.mosque,
    'Pengantar Teknologi Informasi': Icons.computer,
    'Kewarganegaraan': Icons.account_balance,
    'Komputer dan Masyarakat': Icons.groups,
    'Logika Matematika': Icons.psychology,
    'Sistem Digital': Icons.memory,
    'Fisika Gerak': Icons.speed,
    'Jaringan Komputer': Icons.router,
    'Matematika Diskrit': Icons.grid_on,
    'Praktikum Struktur Data': Icons.data_object,
    'Sistem Informasi': Icons.info,
    'Statistika Dasar': Icons.bar_chart,
    'Struktur Data': Icons.data_array,
    'Akhlak dan Etika': Icons.favorite,
    'Aplikasi Kewirausahaan': Icons.business_center,
    'Interaksi Manusia dan Komputer': Icons.touch_app,
    'Interaksi Manusia dan Komputer 2': Icons.touch_app,
    'Pemrograman Visual': Icons.visibility,
    'Pemrograman Web Lanjut': Icons.web,
    'Penambangan Data': Icons.data_usage,
    'Penulisan Ilmiah': Icons.article,
    'Teknik Kompilasi': Icons.build,
    'Ilmu Sosial dan Budaya Dasar': Icons.public,
    'Kecakapan Antar Personal': Icons.people,
    'Kewirausahaan': Icons.store,
    'Pemrograman Berorientasi Objek': Icons.class_,
    'Pemrograman Web Dasar': Icons.web_asset,
    'Sistem Operasi': Icons.settings_applications,
    'Statistika Lanjut': Icons.insights,
    'Teori Bahasa dan Automata': Icons.abc,
    'Analisa dan Perancangan Sistem Informasi': Icons.design_services,
    'Jaringan Syaraf Tiruan': Icons.psychology_alt,
    'Kuliah Kerja Praktek': Icons.work,
    'Multimedia': Icons.perm_media,
    'Pengolahan Citra': Icons.image,
    'Teknik Simulasi': Icons.analytics,
  };

  final Map<String, Color> _colorMap = {
    'Rekayasa Perangkat Lunak': Colors.blue,
    'Riset Operasional': Colors.green,
    'Etika Profesi': Colors.orange,
    'Sistem Basis Pengetahuan': Colors.purple,
    'Sistem Berbasis Pengetahuan': Colors.purple,
    'Filsafat Ilmu': Colors.teal,
    'E-Commerce': Colors.pink,
    'Komputer Grafik': Colors.indigo,
    'Keamanan Komputer': Colors.red,
    'Algoritma': Colors.deepPurple,
    'Bahasa Indonesia': Colors.brown,
    'Bahasa Inggris': Colors.lightBlue,
    'Kalkulus Dasar': Colors.cyan,
    'Kalkulus Lanjut': Colors.deepOrange,
    'Pancasila': Colors.red,
    'Pemrograman': Colors.blue,
    'Pendidikan Agama Islam': Colors.green,
    'Pengantar Teknologi Informasi': Colors.blueGrey,
    'Kewarganegaraan': Colors.amber,
    'Komputer dan Masyarakat': Colors.lime,
    'Logika Matematika': Colors.indigo,
    'Sistem Digital': Colors.purple,
    'Fisika Gerak': Colors.teal,
    'Jaringan Komputer': Colors.orange,
    'Matematika Diskrit': Colors.pink,
    'Praktikum Struktur Data': Colors.deepPurple,
    'Sistem Informasi': Colors.blue,
    'Statistika Dasar': Colors.green,
    'Struktur Data': Colors.indigo,
    'Akhlak dan Etika': Colors.pink,
    'Aplikasi Kewirausahaan': Colors.teal,
    'Interaksi Manusia dan Komputer': Colors.cyan,
    'Pemrograman Visual': Colors.purple,
    'Pemrograman Web Lanjut': Colors.deepOrange,
    'Penambangan Data': Colors.brown,
    'Penulisan Ilmiah': Colors.blueGrey,
    'Teknik Kompilasi': Colors.amber,
    'Ilmu Sosial dan Budaya Dasar': Colors.lightGreen,
    'Kecakapan Antar Personal': Colors.pinkAccent,
    'Kewirausahaan': Colors.green,
    'Pemrograman Berorientasi Objek': Colors.deepPurple,
    'Pemrograman Web Dasar': Colors.lightBlue,
    'Sistem Operasi': Colors.indigo,
    'Statistika Lanjut': Colors.teal,
    'Teori Bahasa dan Automata': Colors.orange,
    'Analisa dan Perancangan Sistem Informasi': Colors.blue,
    'Jaringan Syaraf Tiruan': Colors.purple,
    'Kuliah Kerja Praktek': Colors.brown,
    'Multimedia': Colors.pink,
    'Pengolahan Citra': Colors.cyan,
    'Teknik Simulasi': Colors.green,
  };

  @override
  void initState() {
    super.initState();
    _loadJadwal();
  }

  Future<void> _loadJadwal() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final html = await _apiService.fetchDashboardPage();
      final items = _parseJadwalHtml(html);
      
      setState(() {
        _jadwalList = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<JadwalItem> _parseJadwalHtml(String html) {
    final document = html_parser.parse(html);
    final List<JadwalItem> items = [];

    // Ambil semua card mata kuliah
    final cards = document.querySelectorAll('.box.box-widget.widget-user-2.card');

    for (var card in cards) {
      try {
        final pertemuanLink = card.querySelector('a[href*="pertemuan/plist"]');
        if (pertemuanLink == null) continue;

        final href = pertemuanLink.attributes['href'] ?? '';
        final match = RegExp(r'pertemuan/plist/([^"]+)').firstMatch(href);
        if (match == null) continue;
        
        final encryptedKelasId = match.group(1) ?? '';

        final headerBadeg = card.querySelector('.header_badeg');
        if (headerBadeg == null) continue;

        final headerText = headerBadeg.text.trim();
        
        // Ambil kode dan nama matkul
        String kode = '';
        String mataKuliah = '';
        String singkatan = '';
        
        if (headerText.contains(' -')) {
          final parts = headerText.split(' -');
          kode = parts[0].trim();
          
          mataKuliah = parts[1].replaceAll(RegExp(r'\s*[\*\#\)]+\s*$'), '').trim();
          
          final singkatanMatch = RegExp(r'\*\)\s*([^\)]+)\)').firstMatch(parts[1]);
          if (singkatanMatch != null) {
            singkatan = singkatanMatch.group(1)?.trim() ?? '';
          }
        }

        final scheduleLabel = card.querySelector('.label.text-green');
        if (scheduleLabel == null) continue;

        final scheduleText = scheduleLabel.text.trim();
        
        String kelas = '';
        String ruang = '';
        String hari = '';
        String waktu = '';
        
        final scheduleParts = scheduleText.split('|');
        for (var part in scheduleParts) {
          part = part.trim();
          if (part.startsWith('Kelas:')) {
            kelas = part.replaceAll('Kelas:', '').trim();
          } else if (part.startsWith('Ruang:')) {
            ruang = part.replaceAll('Ruang:', '').trim();
          } else if (part.startsWith('Waktu:')) {
            final waktuText = part.replaceAll('Waktu:', '').trim();
            if (waktuText.contains(',')) {
              final waktuParts = waktuText.split(',');
              hari = waktuParts[0].trim();
              if (waktuParts.length > 1) {
                waktu = waktuParts[1].trim();
              }
            }
          }
        }

        if (mataKuliah.isNotEmpty && kode.isNotEmpty) {
          final icon = _iconMap[mataKuliah] ?? Icons.book;
          final color = _colorMap[mataKuliah] ?? Colors.blue;

          items.add(JadwalItem(
            hari: hari,
            waktu: waktu,
            mataKuliah: mataKuliah,
            singkatan: singkatan.isEmpty ? kode : singkatan,
            kode: kode,
            kelas: kelas,
            ruang: ruang,
            encryptedKelasId: encryptedKelasId,
            icon: icon,
            color: color,
          ));
        }
      } catch (e) {
        print('Error parsing jadwal card: $e');
        continue;
      }
    }

    return items;
  }

  Map<String, List<JadwalItem>> _groupByDay() {
    final grouped = <String, List<JadwalItem>>{};
    for (var jadwal in _jadwalList) {
      final hari = jadwal.hari;
      if (!grouped.containsKey(hari)) {
        grouped[hari] = [];
      }
      grouped[hari]!.add(jadwal);
    }
    return grouped;
  }

  List<String> _getOrderedDays() {
    return ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jum\'at', 'Sabtu', 'Minggu'];
  }

  String _getCurrentDay() {
    final now = DateTime.now();
    const days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jum\'at', 'Sabtu'];
    return days[now.weekday % 7];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Kuliah'),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadJadwal,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Gagal memuat jadwal',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadJadwal,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF073163),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _jadwalList.isEmpty
                  ? const Center(child: Text('Tidak ada jadwal'))
                  : _buildJadwalList(),
    );
  }

  Widget _buildJadwalList() {
    final groupedJadwal = _groupByDay();
    final orderedDays = _getOrderedDays();

    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orderedDays.length,
        itemBuilder: (context, index) {
          final hari = orderedDays[index];
          final jadwalHari = groupedJadwal[hari];

          if (jadwalHari == null || jadwalHari.isEmpty) {
            return const SizedBox.shrink();
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        hari,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (hari == _getCurrentDay()) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Hari ini',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${jadwalHari.length} Kelas',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: jadwalHari.length,
                  separatorBuilder: (context, _) => Divider(
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  itemBuilder: (context, idx) {
                    final jadwal = jadwalHari[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: jadwal.color.withOpacity(0.2),
                        radius: 30,
                        child: Icon(
                          jadwal.icon,
                          color: jadwal.color,
                          size: 28,
                        ),
                      ),
                      title: Text(
                        jadwal.mataKuliah,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                jadwal.waktu,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.room,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${jadwal.ruang} - Kelas ${jadwal.kelas}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.bookmark,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                jadwal.kode,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: jadwal.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          jadwal.singkatan,
                          style: TextStyle(
                            color: jadwal.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PertemuanListScreen(
                              encryptedKelasId: jadwal.encryptedKelasId,
                              namaMataKuliah: jadwal.mataKuliah,
                              hari: jadwal.hari,
                              waktu: jadwal.waktu,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
    );
  }
}
