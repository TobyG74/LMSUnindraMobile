import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/jadwal_model.dart';
import '../../services/api_service.dart';
import 'pertemuan_detail_dosen_screen.dart';

class PertemuanDosenListScreen extends StatefulWidget {
  final JadwalItem jadwal;

  const PertemuanDosenListScreen({
    super.key,
    required this.jadwal,
  });

  @override
  State<PertemuanDosenListScreen> createState() =>
      _PertemuanDosenListScreenState();
}

class _PertemuanDosenListScreenState extends State<PertemuanDosenListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<_PertemuanDosenItem> _pertemuanList = [];

  @override
  void initState() {
    super.initState();
    _loadPertemuanDosen();
  }

  Future<void> _loadPertemuanDosen() async {
    setState(() => _isLoading = true);

    try {
      final html = await _apiService.fetchDashboardPage();
      _parsePertemuanDosen(html);
    } catch (e) {
      debugPrint('Error loading dosen pertemuan: $e');
    }

    setState(() => _isLoading = false);
  }

  void _parsePertemuanDosen(String html) {
    final document = html_parser.parse(html);
    final treeviews = document.querySelectorAll('li.treeview');
    final items = <_PertemuanDosenItem>[];

    for (final treeview in treeviews) {
      final mainSpan = treeview.querySelector('a > span');
      if (mainSpan == null) {
        continue;
      }

      final classTitle = mainSpan.text.trim();
      if (classTitle.isEmpty) {
        continue;
      }

      final isSameSchedule = classTitle.toLowerCase().contains(
            '${widget.jadwal.hari} ${widget.jadwal.waktu}'.toLowerCase(),
          );
      final isSameCourse = classTitle
          .toLowerCase()
          .contains(widget.jadwal.singkatan.toLowerCase());

      if (!isSameSchedule && !isSameCourse) {
        continue;
      }

      final liItems = treeview.querySelectorAll('ul.treeview-menu > li');
      for (final li in liItems) {
        final link = li.querySelector('a[href*="pertemuan/pke/"]');
        if (link == null) {
          continue;
        }

        final href = link.attributes['href'] ?? '';
        final match = RegExp(r'pertemuan/pke/(.+)$').firstMatch(href);
        if (match == null) {
          continue;
        }

        final encryptedUrl = match.group(1) ?? '';
        final title =
            link.querySelector('span')?.text.trim() ?? link.text.trim();
        final numberMatch = RegExp(r'Pertemuan\s+(\d+)', caseSensitive: false)
            .firstMatch(title);

        items.add(
          _PertemuanDosenItem(
            title: title,
            encryptedUrl: encryptedUrl,
            pertemuanKe: numberMatch != null
                ? int.tryParse(numberMatch.group(1) ?? '')
                : null,
          ),
        );
      }

      if (items.isNotEmpty) {
        break;
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
        title: Text(widget.jadwal.mataKuliah),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pertemuanList.isEmpty
              ? const Center(child: Text('Belum ada pertemuan dosen'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final item = _pertemuanList[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(item.pertemuanKe?.toString() ?? '?'),
                        ),
                        title: Text(item.title),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PertemuanDetailDosenScreen(
                                encryptedUrl: item.encryptedUrl,
                                title: item.title,
                                namaMataKuliah: widget.jadwal.mataKuliah,
                                pertemuanKe: item.pertemuanKe,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: _pertemuanList.length,
                ),
    );
  }
}

class _PertemuanDosenItem {
  final String title;
  final String encryptedUrl;
  final int? pertemuanKe;

  _PertemuanDosenItem({
    required this.title,
    required this.encryptedUrl,
    required this.pertemuanKe,
  });
}
