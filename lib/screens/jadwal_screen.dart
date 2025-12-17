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
    'Manajemen Bisnis': Icons.business,
    'Matematika Ekonomi': Icons.trending_up,
    'Pengantar Pendidikan': Icons.school,
    'Bahasa Inggris Bisnis': Icons.language,
    'Manajemen Umum': Icons.admin_panel_settings,
    'Perkembangan Peserta Didik': Icons.child_care,
    'Prinsip-prinsip Dasar Akuntansi': Icons.account_balance_wallet,
    'Akuntansi Lanjutan': Icons.receipt_long,
    'Kurikulum Pendidikan': Icons.menu_book,
    'Manajemen Sumber Daya Manusia': Icons.group,
    'Pengantar Manajemen Keuangan': Icons.monetization_on,
    'Pengantar Manajemen Pemasaran': Icons.campaign,
    'Sejarah Pemikiran Ekonomi': Icons.history_edu,
    'Teori Ekonomi Mikro': Icons.price_check,
    'Akuntansi Biaya': Icons.calculate,
    'Manajemen Keuangan & Investasi': Icons.show_chart,
    'Manajemen Pemasaran': Icons.storefront,
    'Sejarah Pendidikan & PGRI': Icons.history,
    'Statistik Deskriptif': Icons.bar_chart,
    'Strategi Belajar Pembelajaran': Icons.lightbulb,
    'Teori Ekonomi Makro': Icons.account_balance,
    'Bank Dan Lembaga Keuangan Lainnya': Icons.account_balance,
    'Manajemen Produksi': Icons.precision_manufacturing,
    'Perencanaan Pembelajaran': Icons.calendar_month,
    'Perpajakan': Icons.receipt,
    'Profesi Kependidikan': Icons.badge,
    'Statistik Inferensial': Icons.insights,
    'Ekonomi Pembangunan': Icons.construction,
    'Perdagangan Luar Negeri': Icons.public,
    'Ekonomi Syariah': Icons.mosque,
    'Pasar Uang Pasar Modal': Icons.currency_exchange,
    'Dasar-Dasar Ilmu Pendidikan': Icons.school,
    'Dasar-Dasar Pelayanan BK': Icons.support_agent,
    'Belajar dan Pembelajaran': Icons.auto_stories,
    'Manajemen BK': Icons.settings,
    'Pengembangan Profesi Konseling': Icons.psychology,
    'Psikologi Pendidikan': Icons.psychology,
    'Psikologi Perkembangan Anak & Remaja': Icons.child_care,
    'Psikologi Sosial': Icons.groups,
    'Instrumentasi Nontes': Icons.quiz,
    'Keterampilan Dasar Konseling': Icons.chat,
    'Metodologi Pembelajaran': Icons.menu_book,
    'Psikologi Kepribadian': Icons.person,
    'Aplikasi Statistika dalam BK': Icons.analytics,
    'Instrumentasi Tes': Icons.assignment,
    'Kesehatan Mental': Icons.health_and_safety,
    'Konseling Format Khusus': Icons.video_call,
    'Konseling Format Klasikal': Icons.meeting_room,
    'Layanan BK Kelompok': Icons.group_work,
    'Model-Model Konseling': Icons.psychology,
    'Kegiatan Pendukung BK': Icons.support,
    'Konseling Pernikahan dan Keluarga': Icons.family_restroom,
    'Konstruksi dan Pengukuran BK': Icons.construction,
    'Metode Penelitian Kualitatif': Icons.science,
    'Praktik Laboratorium BK Kelompok': Icons.biotech,
    'Teknologi Informasi dalam BK': Icons.computer,
    'Desain Elementer Dwimatra': Icons.grid_4x4,
    'Pengantar Ilmu Komunikasi': Icons.campaign,
    'Bahasa Inggris Desain': Icons.language,
    'Pengantar Budaya Nusantara': Icons.temple_buddhist,
    'Teknik Presentasi': Icons.present_to_all,
    'Filsafat Seni': Icons.palette,
    'Fotografi Dasar': Icons.photo_camera,
    'Perkembangan Media': Icons.trending_up,
    'Ragam Hias Nusantara': Icons.texture,
    'Wawasan Budaya Nusantara': Icons.public,
    'Desain dan Kebudayaan': Icons.palette_outlined,
    'Desain Komunikasi Visual': Icons.design_services,
    'Fotografi Terapan': Icons.photo_camera_front,
    'Gambar Eunik': Icons.draw,
    'Kajian Seni Rupa dan Desain': Icons.art_track,
    'Ruang Visual Nusantara': Icons.view_in_ar,
    'Tipografi Terapan': Icons.text_fields,
    'Filsafat Nusantara': Icons.auto_stories,
    'Komunikasi Bisnis': Icons.business_center,
    'Logika Berpikir Desain': Icons.psychology_alt,
    'Manajemen Proyek': Icons.manage_accounts,
    'Metode Grafika': Icons.graphic_eq,
    'Sosiologi Desain': Icons.groups_2,
    'Kekayaan Intelektual': Icons.copyright,
    'Infografik': Icons.insert_chart,
    'Manajemen Publikasi': Icons.publish,
    'Pengantar Sinematografi': Icons.movie,
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
    'Manajemen Bisnis': Colors.teal,
    'Matematika Ekonomi': Colors.orange,
    'Pengantar Pendidikan': Colors.blue,
    'Bahasa Inggris Bisnis': Colors.lightBlue,
    'Manajemen Umum': Colors.deepPurple,
    'Perkembangan Peserta Didik': Colors.pink,
    'Prinsip-prinsip Dasar Akuntansi': Colors.green,
    'Akuntansi Lanjutan': Colors.teal,
    'Kurikulum Pendidikan': Colors.indigo,
    'Manajemen Sumber Daya Manusia': Colors.purple,
    'Pengantar Manajemen Keuangan': Colors.amber,
    'Pengantar Manajemen Pemasaran': Colors.red,
    'Sejarah Pemikiran Ekonomi': Colors.brown,
    'Teori Ekonomi Mikro': Colors.cyan,
    'Akuntansi Biaya': Colors.deepOrange,
    'Manajemen Keuangan & Investasi': Colors.blue,
    'Manajemen Pemasaran': Colors.pink,
    'Sejarah Pendidikan & PGRI': Colors.brown,
    'Statistik Deskriptif': Colors.green,
    'Strategi Belajar Pembelajaran': Colors.orange,
    'Teori Ekonomi Makro': Colors.indigo,
    'Bank Dan Lembaga Keuangan Lainnya': Colors.blueGrey,
    'Manajemen Produksi': Colors.purple,
    'Perencanaan Pembelajaran': Colors.teal,
    'Perpajakan': Colors.amber,
    'Profesi Kependidikan': Colors.blue,
    'Statistik Inferensial': Colors.deepPurple,
    'Ekonomi Pembangunan': Colors.green,
    'Perdagangan Luar Negeri': Colors.lightBlue,
    'Ekonomi Syariah': Colors.teal,
    'Pasar Uang Pasar Modal': Colors.cyan,
    'Dasar-Dasar Ilmu Pendidikan': Colors.blue,
    'Dasar-Dasar Pelayanan BK': Colors.purple,
    'Belajar dan Pembelajaran': Colors.orange,
    'Manajemen BK': Colors.indigo,
    'Pengembangan Profesi Konseling': Colors.deepPurple,
    'Psikologi Pendidikan': Colors.teal,
    'Psikologi Perkembangan Anak & Remaja': Colors.pink,
    'Psikologi Sosial': Colors.lightBlue,
    'Instrumentasi Nontes': Colors.amber,
    'Keterampilan Dasar Konseling': Colors.green,
    'Metodologi Pembelajaran': Colors.brown,
    'Psikologi Kepribadian': Colors.deepOrange,
    'Aplikasi Statistika dalam BK': Colors.cyan,
    'Instrumentasi Tes': Colors.purple,
    'Kesehatan Mental': Colors.green,
    'Konseling Format Khusus': Colors.indigo,
    'Konseling Format Klasikal': Colors.blue,
    'Layanan BK Kelompok': Colors.orange,
    'Model-Model Konseling': Colors.deepPurple,
    'Kegiatan Pendukung BK': Colors.teal,
    'Konseling Pernikahan dan Keluarga': Colors.pink,
    'Konstruksi dan Pengukuran BK': Colors.amber,
    'Metode Penelitian Kualitatif': Colors.blueGrey,
    'Praktik Laboratorium BK Kelompok': Colors.lightBlue,
    'Teknologi Informasi dalam BK': Colors.indigo,
    'Desain Elementer Dwimatra': Colors.purple,
    'Pengantar Ilmu Komunikasi': Colors.orange,
    'Bahasa Inggris Desain': Colors.lightBlue,
    'Pengantar Budaya Nusantara': Colors.brown,
    'Teknik Presentasi': Colors.teal,
    'Filsafat Seni': Colors.deepPurple,
    'Fotografi Dasar': Colors.pink,
    'Perkembangan Media': Colors.cyan,
    'Ragam Hias Nusantara': Colors.amber,
    'Wawasan Budaya Nusantara': Colors.green,
    'Desain dan Kebudayaan': Colors.teal,
    'Desain Komunikasi Visual': Colors.purple,
    'Fotografi Terapan': Colors.pink,
    'Gambar Eunik': Colors.orange,
    'Kajian Seni Rupa dan Desain': Colors.deepPurple,
    'Ruang Visual Nusantara': Colors.indigo,
    'Tipografi Terapan': Colors.blueGrey,
    'Filsafat Nusantara': Colors.brown,
    'Komunikasi Bisnis': Colors.blue,
    'Logika Berpikir Desain': Colors.cyan,
    'Manajemen Proyek': Colors.green,
    'Metode Grafika': Colors.deepOrange,
    'Sosiologi Desain': Colors.lightBlue,
    'Kekayaan Intelektual': Colors.amber,
    'Infografik': Colors.purple,
    'Manajemen Publikasi': Colors.teal,
    'Pengantar Sinematografi': Colors.red,
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

  IconData _getIconForMataKuliah(String mataKuliah) {
    if (_iconMap.containsKey(mataKuliah)) {
      return _iconMap[mataKuliah]!;
    }
    
    final mataKuliahLower = mataKuliah.toLowerCase();
    for (var entry in _iconMap.entries) {
      if (entry.key.toLowerCase().contains(mataKuliahLower) ||
          mataKuliahLower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    return Icons.book; 
  }

  Color _getColorForMataKuliah(String mataKuliah) {
    if (_colorMap.containsKey(mataKuliah)) {
      return _colorMap[mataKuliah]!;
    }
    
    final mataKuliahLower = mataKuliah.toLowerCase();
    for (var entry in _colorMap.entries) {
      if (entry.key.toLowerCase().contains(mataKuliahLower) ||
          mataKuliahLower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    return Colors.blue; 
  }

  List<JadwalItem> _parseJadwalHtml(String html) {
    final document = html_parser.parse(html);
    final List<JadwalItem> items = [];

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
        
        String kode = '';
        String mataKuliah = '';
        String singkatan = '';
        
        if (headerText.contains(' -')) {
          final parts = headerText.split(' -');
          kode = parts[0].trim();
          
          mataKuliah = parts[1]
              .replaceAll(RegExp(r'^[\*\+\#\s]+'), '')
              .replaceAll(RegExp(r'\s*[\*\#\)]+\s*$'), '')
              .trim();
          
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
          final icon = _getIconForMataKuliah(mataKuliah);
          final color = _getColorForMataKuliah(mataKuliah);

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
                  Icon(Icons.calendar_today_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Jadwal Kuliah',
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
                onPressed: _isLoading ? null : _loadJadwal,
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
                              'Gagal memuat jadwal',
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
                              onPressed: _loadJadwal,
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
                  : _jadwalList.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Tidak ada jadwal',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : _buildJadwalList(),
        ],
      ),
    );
  }

  Widget _buildJadwalList() {
    final groupedJadwal = _groupByDay();
    final orderedDays = _getOrderedDays();

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
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
          childCount: orderedDays.length,
        ),
      ),
    );
  }
}
