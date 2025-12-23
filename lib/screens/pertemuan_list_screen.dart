import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'pertemuan_detail_screen.dart';

class PertemuanListScreen extends StatefulWidget {
  final String encryptedKelasId;
  final String namaMataKuliah;
  final String hari;
  final String waktu;

  const PertemuanListScreen({
    super.key,
    required this.encryptedKelasId,
    required this.namaMataKuliah,
    required this.hari,
    required this.waktu,
  });

  @override
  State<PertemuanListScreen> createState() => _PertemuanListScreenState();
}

class _PertemuanListScreenState extends State<PertemuanListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<PertemuanItem> _pertemuanList = [];
  Set<String> _openedPertemuan = {};

  @override
  void initState() {
    super.initState();
    _loadOpenedPertemuan();
    _loadPertemuanList();
  }

  Future<void> _loadOpenedPertemuan() async {
    final prefs = await SharedPreferences.getInstance();
    final opened = prefs.getStringList('opened_pertemuan') ?? [];
    setState(() {
      _openedPertemuan = opened.toSet();
    });
  }

  Future<void> _markPertemuanAsOpened(String encryptedUrl) async {
    final prefs = await SharedPreferences.getInstance();
    _openedPertemuan.add(encryptedUrl);
    await prefs.setStringList('opened_pertemuan', _openedPertemuan.toList());
    setState(() {});
  }

  Future<void> _loadPertemuanList() async {
    setState(() => _isLoading = true);

    try {
      final html = await _apiService.fetchDashboardPage();
      
      if (html.isNotEmpty) {
        _parsePertemuanList(html);
      }
    } catch (e) {
      print('Error loading pertemuan list: $e');
    }

    setState(() => _isLoading = false);
  }

  void _parsePertemuanList(String html) {
    final document = html_parser.parse(html);
    final List<PertemuanItem> items = [];

    final treeviews = document.querySelectorAll('li.treeview');

    for (var treeview in treeviews) {
      final mainLink = treeview.querySelector('a');
      if (mainLink == null) continue;

      final span = mainLink.querySelector('span');
      if (span == null) continue;

      final spanText = span.text.trim();
      
      // Cek apakah spanText mengandung hari dan waktu
      // Format spanText: "Senin 07:00-09:30 RPL*#"
      final isMatch = spanText.toUpperCase().contains(widget.hari.toUpperCase()) && 
                      spanText.contains(widget.waktu);
      
      if (!isMatch) continue;

      final treeviewMenu = treeview.querySelector('ul.treeview-menu');
      if (treeviewMenu == null) continue;

      final pertemuanItems = treeviewMenu.querySelectorAll('li');
      
      for (var li in pertemuanItems) {
        try {
          final link = li.querySelector('a[href*="pertemuan/pke/"]');
          if (link == null) continue;

          final href = link.attributes['href'] ?? '';
          final match = RegExp(r'pertemuan/pke/(.+)$').firstMatch(href);

          if (match != null) {
            final encryptedUrl = match.group(1) ?? '';
            final pertemuanSpan = link.querySelector('span');
            final title = pertemuanSpan?.text.trim() ?? link.text.trim();

            final pertemuanMatch = RegExp(r'Pertemuan\s+(\d+)', caseSensitive: false).firstMatch(title);
            int? pertemuanKe;
            if (pertemuanMatch != null) {
              pertemuanKe = int.tryParse(pertemuanMatch.group(1) ?? '0');
            }

            if (title.isNotEmpty && encryptedUrl.isNotEmpty) {
              items.add(PertemuanItem(
                title: title,
                encryptedUrl: encryptedUrl,
                pertemuanKe: pertemuanKe,
              ));
            }
          }
        } catch (e) {
          print('Error parsing pertemuan link: $e');
        }
      }
      break;
    }

    setState(() {
      _pertemuanList = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  const Icon(Icons.list_alt_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.namaMataKuliah,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _pertemuanList.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(
                        child: Text('Belum ada pertemuan'),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 60),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                    final pertemuan = _pertemuanList[index];
                    final maxPertemuanKe = _pertemuanList
                        .where((p) => p.pertemuanKe != null)
                        .map((p) => p.pertemuanKe!)
                        .fold<int>(0, (max, current) => current > max ? current : max);
                    final isLatest = pertemuan.pertemuanKe == maxPertemuanKe && maxPertemuanKe > 0;
                    final isNew = isLatest && !_openedPertemuan.contains(pertemuan.encryptedUrl);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF073163),
                          child: Text(
                            pertemuan.pertemuanKe?.toString() ?? '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(pertemuan.title)),
                            if (isNew) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Baru',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          await _markPertemuanAsOpened(pertemuan.encryptedUrl);
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PertemuanDetailScreen(
                                  encryptedUrl: pertemuan.encryptedUrl,
                                  title: pertemuan.title,
                                  namaMataKuliah: widget.namaMataKuliah,
                                  pertemuanKe: pertemuan.pertemuanKe,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                  childCount: _pertemuanList.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PertemuanItem {
  final String title;
  final String encryptedUrl;
  final int? pertemuanKe;

  PertemuanItem({
    required this.title,
    required this.encryptedUrl,
    this.pertemuanKe,
  });
}
