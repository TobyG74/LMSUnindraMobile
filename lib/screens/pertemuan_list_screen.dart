import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
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

  @override
  void initState() {
    super.initState();
    _loadPertemuanList();
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
      appBar: AppBar(
        title: Text(
          widget.namaMataKuliah,
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pertemuanList.isEmpty
              ? const Center(
                  child: Text('Belum ada pertemuan'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pertemuanList.length,
                  itemBuilder: (context, index) {
                    final pertemuan = _pertemuanList[index];
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
                        title: Text(pertemuan.title),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
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
                        },
                      ),
                    );
                  },
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
