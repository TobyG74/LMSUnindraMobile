import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/matakuliah_model.dart';
import '../services/api_service.dart';
import 'matakuliah_detail_screen.dart';

class MataKuliahScreen extends StatefulWidget {
  const MataKuliahScreen({super.key});

  @override
  State<MataKuliahScreen> createState() => _MataKuliahScreenState();
}

class _MataKuliahScreenState extends State<MataKuliahScreen> {
  final ApiService _apiService = ApiService();
  List<MataKuliahItem> _mataKuliahList = [];
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
    'Evaluasi Pembelajaran': Icons.assessment,
    'Konseling Kesehatan': Icons.medical_services,
    'Konseling Lintas Budaya': Icons.public,
    'Layanan BK di Pendidikan Dasar': Icons.school,
    'Diagnostik Kesulitan Belajar & Remedial': Icons.healing,
    'Metode Penelitian Kuantitatif': Icons.data_exploration,
    'Praktik Laboratorium Konseling Perorangan': Icons.person_search,
    'Studi Kasus dalam BK': Icons.cases,
    'English for Guidance': Icons.translate,
    'Layanan BK di Pendidikan Menengah dan Tinggi': Icons.account_balance,
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
    'Evaluasi Pembelajaran': Colors.purple,
    'Konseling Kesehatan': Colors.red,
    'Konseling Lintas Budaya': Colors.brown,
    'Layanan BK di Pendidikan Dasar': Colors.blue,
    'Diagnostik Kesulitan Belajar & Remedial': Colors.orange,
    'Metode Penelitian Kuantitatif': Colors.teal,
    'Praktik Laboratorium Konseling Perorangan': Colors.deepPurple,
    'Studi Kasus dalam BK': Colors.cyan,
    'English for Guidance': Colors.lightBlue,
    'Layanan BK di Pendidikan Menengah dan Tinggi': Colors.indigo,    'Desain Elementer Dwimatra': Colors.purple,
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
    _loadMataKuliah();
  }

  IconData _getIconForMataKuliah(String nama) {
    if (_iconMap.containsKey(nama)) {
      return _iconMap[nama]!;
    }
    
    final namaLower = nama.toLowerCase();
    for (var entry in _iconMap.entries) {
      if (entry.key.toLowerCase().contains(namaLower) ||
          namaLower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    return Icons.book;
  }

  Color _getColorForMataKuliah(String nama) {
    if (_colorMap.containsKey(nama)) {
      return _colorMap[nama]!;
    }
    
    final namaLower = nama.toLowerCase();
    for (var entry in _colorMap.entries) {
      if (entry.key.toLowerCase().contains(namaLower) ||
          namaLower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    return Colors.blue;
  }

  Future<void> _loadMataKuliah() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final html = await _apiService.fetchDashboardPage();
      final items = _parseMataKuliahHtml(html);
      
      setState(() {
        _mataKuliahList = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<MataKuliahItem> _parseMataKuliahHtml(String html) {
    final document = html_parser.parse(html);
    final List<MataKuliahItem> items = [];

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
        String nama = '';
        
        if (headerText.contains(' -')) {
          final parts = headerText.split(' -');
          kode = parts[0].trim();
          
          nama = parts[1]
              .replaceAll(RegExp(r'^[\*\+\#\s]+'), '') 
              .replaceAll(RegExp(r'\s*[\*\#\)]+\s*$'), '')
              .trim();
        }

        String dosen = '';
        String? nomorHp;
        String? fotoDosen;
        
        final dosenName = card.querySelector('.widget-user-username');
        if (dosenName != null) {
          dosen = dosenName.text.trim();
        }
        
        final dosenPhone = card.querySelector('.widget-user-desc');
        if (dosenPhone != null) {
          final phoneText = dosenPhone.text.trim();
          if (phoneText.startsWith('HP :')) {
            final phone = phoneText.replaceAll('HP :', '').trim();
            if (phone.isNotEmpty) {
              nomorHp = phone;
            }
          }
        }
        
        final fotoDosenImg = card.querySelector('img[alt="Foto Dosen"]');
        if (fotoDosenImg != null) {
          fotoDosen = fotoDosenImg.attributes['src'];
        }

        String kelas = '';
        String? ruang;
        String? waktu;
        
        // Format: "Kelas: R7 |  Ruang: R.8.1-9    |  Waktu: Senin, 07:00-09:30"
        final isiBadge = card.querySelector('div.isi_badge');
        if (isiBadge != null) {
          final badgeText = isiBadge.text.trim();
          
          // Parse Kelas
          final kelasMatch = RegExp(r'Kelas:\s*([^|]+)').firstMatch(badgeText);
          if (kelasMatch != null) {
            kelas = kelasMatch.group(1)?.trim() ?? '';
          }
          
          // Parse Ruang
          final ruangMatch = RegExp(r'Ruang:\s*([^|]+)').firstMatch(badgeText);
          if (ruangMatch != null) {
            ruang = ruangMatch.group(1)?.trim();
          }
          
          // Parse Waktu
          final waktuMatch = RegExp(r'Waktu:\s*(.+)').firstMatch(badgeText);
          if (waktuMatch != null) {
            waktu = waktuMatch.group(1)?.trim();
          }
        }
        
        if (kelas.isEmpty) {
          final kelasBadge = card.querySelector('.pull-right.text-bold.badge');
          if (kelasBadge != null) {
            kelas = kelasBadge.text.trim();
          }
        }

        String semester = '1';
        String sks = '3'; 

        if (nama.isNotEmpty && kode.isNotEmpty) {
          final icon = _getIconForMataKuliah(nama);
          final color = _getColorForMataKuliah(nama);

          items.add(MataKuliahItem(
            nama: nama,
            kode: kode,
            kelas: kelas,
            semester: semester,
            sks: sks,
            dosen: dosen,
            nomorHp: nomorHp,
            fotoDosen: fotoDosen,
            ruang: ruang,
            waktu: waktu,
            encryptedKelasId: encryptedKelasId,
            icon: icon,
            color: color,
          ));
        }
      } catch (e) {
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
                  Icon(Icons.book_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Mata Kuliah',
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
                onPressed: _isLoading ? null : _loadMataKuliah,
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
                              'Gagal memuat mata kuliah',
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
                              onPressed: _loadMataKuliah,
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
                  : _mataKuliahList.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Tidak ada mata kuliah',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 60),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final mataKuliah = _mataKuliahList[index];
                                return _buildMataKuliahCard(mataKuliah);
                              },
                              childCount: _mataKuliahList.length,
                            ),
                          ),
                        ),
        ],
      ),
    );
  }

  Widget _buildMataKuliahCard(MataKuliahItem mataKuliah) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MataKuliahDetailScreen(
                  namaMataKuliah: mataKuliah.nama,
                  kodeMataKuliah: mataKuliah.kode,
                  kelas: mataKuliah.kelas,
                  semester: mataKuliah.semester,
                  sks: mataKuliah.sks,
                  dosenPengampu: mataKuliah.dosen,
                  nomorHpDosen: mataKuliah.nomorHp,
                  fotoDosen: mataKuliah.fotoDosen,
                  ruang: mataKuliah.ruang,
                  waktu: mataKuliah.waktu,
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
                left: BorderSide(
                  color: mataKuliah.color,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                // Icon dengan gradient background
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        mataKuliah.color.withOpacity(0.15),
                        mataKuliah.color.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    mataKuliah.icon,
                    color: mataKuliah.color,
                    size: 28,
                  ),
                ),
                
                const SizedBox(width: 14),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama Mata Kuliah
                      Text(
                        mataKuliah.nama,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Kode Mata Kuliah
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
                          mataKuliah.kode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Kelas dan Waktu
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
                              'Kelas ${mataKuliah.kelas}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          if (mataKuliah.waktu != null && mataKuliah.waktu!.isNotEmpty) ...[
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
                                  mataKuliah.waktu!,
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
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Arrow Icon
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
