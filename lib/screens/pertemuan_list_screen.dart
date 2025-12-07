import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../services/api_service.dart';
import 'pertemuan_detail_screen.dart';

class PertemuanListScreen extends StatefulWidget {
  final String encryptedKelasId;
  final String namaMataKuliah;
  final String kodeMataKuliah;

  const PertemuanListScreen({
    super.key,
    required this.encryptedKelasId,
    required this.namaMataKuliah,
    required this.kodeMataKuliah,
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
      final html = await _apiService.fetchPertemuanPage(widget.encryptedKelasId);
      
      if (html != null) {
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

    // Ambil dari sidebar-menu > treeview-menu
    final treeviewMenus = document.querySelectorAll('ul.treeview-menu');

    for (var menu in treeviewMenus) {
      final links = menu.querySelectorAll('li a[href*="pertemuan/pke/"]');
      
      for (var link in links) {
        try {
          final href = link.attributes['href'] ?? '';
          final match = RegExp(r'pertemuan/pke/(.+)$').firstMatch(href);
          
          if (match != null) {
            final encryptedUrl = match.group(1) ?? '';
            final span = link.querySelector('span');
            final title = span?.text.trim() ?? link.text.trim();
            
            // Ambil nomor pertemuan dari judul
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
    }

    setState(() {
      _pertemuanList = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.namaMataKuliah,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              widget.kodeMataKuliah,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
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
                                kodeMataKuliah: widget.kodeMataKuliah,
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
