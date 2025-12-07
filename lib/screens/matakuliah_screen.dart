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
  String? _npm;
  String? _userPhotoUrl;

  final Map<String, IconData> _iconMap = {
    'Rekayasa Perangkat Lunak': Icons.code,
    'Riset Operasional': Icons.analytics,
    'Etika Profesi': Icons.gavel,
    'Sistem Berbasis Pengetahuan': Icons.storage,
    'Sistem Basis Pengetahuan': Icons.storage,
    'Filsafat Ilmu': Icons.school,
    'E-Commerce': Icons.shopping_cart,
    'Komputer Grafis': Icons.brush,
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
    'UAS': Icons.assessment,
    'Akhlak dan Etika': Icons.favorite,
    'Aplikasi Kewirausahaan': Icons.business_center,
    'Interaksi Manusia dan Komputer': Icons.touch_app,
    'Interaksi Manusia dan Komputer 2': Icons.touch_app,
    'Pemrograman Visual': Icons.visibility,
    'Pemrograman Web Lanjut': Icons.web,
    'Penambangan Data': Icons.data_usage,
    'Penulisan Ilmiah 1': Icons.article,
    'Penulisan Ilmiah 2': Icons.description,
    'Teknik Kompilasi': Icons.build,
    'Teknik Kompilasi 2': Icons.construction,
    'Ilmu Sosial dan Budaya Dasar': Icons.public,
    'Kecakapan Antar Personal (Interpersonal Skilll)': Icons.people,
    'Kecakapan Antar Personal': Icons.people,
    'Kewirausahaan': Icons.store,
    'Pemrograman Berorientasi Objek 1': Icons.class_,
    'Pemrograman Berorientasi Objek 2': Icons.class_,
    'Pemrograman Web Dasar': Icons.web_asset,
    'Sistem Operasi': Icons.settings_applications,
    'Statistika Lanjut': Icons.insights,
    'Teori Bahasa Automata': Icons.abc,
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
    'Sistem Berbasis Pengetahuan': Colors.purple,
    'Sistem Basis Pengetahuan': Colors.purple,
    'Filsafat Ilmu': Colors.teal,
    'E-Commerce': Colors.pink,
    'Komputer Grafis': Colors.indigo,
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
    'Teori Bahasa Automata': Colors.orange,
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
    _loadMataKuliah();
  }

  Future<void> _loadMataKuliah() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final html = await _apiService.fetchDashboardPage();
      
      final document = html_parser.parse(html);
      final userBody = document.querySelector('li.user-body');
      if (userBody != null) {
        final strongTag = userBody.querySelector('strong');
        if (strongTag != null) {
          _npm = strongTag.text.trim();
        }
      }
      
      final userHeader = document.querySelector('li.user-header');
      if (userHeader != null) {
        final imgTag = userHeader.querySelector('img.img-circle');
        if (imgTag != null) {
          _userPhotoUrl = imgTag.attributes['src'];
        }
      }
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
          
          nama = parts[1].replaceAll(RegExp(r'\s*[\*\#\)]+\s*$'), '').trim();
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
          final icon = _iconMap[nama] ?? Icons.book;
          final color = _colorMap[nama] ?? Colors.blue;

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
      appBar: AppBar(
        title: const Text('Mata Kuliah'),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMataKuliah,
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
                        'Gagal memuat mata kuliah',
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
                        onPressed: _loadMataKuliah,
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
              : _mataKuliahList.isEmpty
                  ? const Center(child: Text('Tidak ada mata kuliah'))
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF073163),
                                const Color(0xFF073163).withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_mataKuliahList.length} Mata Kuliah',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _mataKuliahList.length,
                            itemBuilder: (context, index) {
                              final mk = _mataKuliahList[index];
                              return _buildMataKuliahCard(mk);
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildMataKuliahCard(MataKuliahItem mk) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MataKuliahDetailScreen(
                namaMataKuliah: mk.nama,
                kodeMataKuliah: mk.kode,
                kelas: mk.kelas,
                semester: mk.semester,
                sks: mk.sks,
                dosenPengampu: mk.dosen,
                nomorHpDosen: mk.nomorHp,
                fotoDosen: mk.fotoDosen,
                ruang: mk.ruang,
                waktu: mk.waktu,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mk.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  mk.icon,
                  color: mk.color,
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mk.nama,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mk.kode,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildChip(
                          Icons.class_,
                          'Kelas ${mk.kelas}',
                          Colors.green,
                        ),
                        if (mk.waktu != null && mk.waktu!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: _buildChip(
                              Icons.schedule,
                              mk.waktu!,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
