import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import '../../services/api_service.dart';

class PresensiMonitoringTuScreen extends StatefulWidget {
  final String monitoringKode;
  final String? title;

  const PresensiMonitoringTuScreen({
    super.key,
    required this.monitoringKode,
    this.title,
  });

  @override
  State<PresensiMonitoringTuScreen> createState() =>
      _PresensiMonitoringTuScreenState();
}

class _PresensiMonitoringTuScreenState
    extends State<PresensiMonitoringTuScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, String> _classInfo = {};
  List<_MonitoringRow> _rows = [];
  List<String> _periodHeaders = [];

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
      final html = await _apiService.fetchPresensiMonitoringTu(
        widget.monitoringKode,
      );

      if (html == null || html.isEmpty) {
        setState(() {
          _errorMessage = 'Data monitoring TU tidak tersedia.';
          _isLoading = false;
        });
        return;
      }

      final doc = html_parser.parse(html);
      _classInfo
        ..clear()
        ..addAll(_parseClassInfo(doc));
      final tableData = _parseMonitoringTable(doc);
      _periodHeaders = tableData.$1;
      _rows = tableData.$2;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, String> _parseClassInfo(dynamic doc) {
    final info = <String, String>{};
    final table = doc.querySelector('div.box-info table.table.table-striped') ??
        doc.querySelector('table.table.table-striped');
    if (table == null) return info;

    for (final tr in table.querySelectorAll('tr')) {
      final children = tr.children;
      for (int i = 0; i < children.length; i++) {
        final cell = children[i];
        if (cell.localName != 'th') continue;

        final key = _normalizeCellText(cell.text);
        if (key.isEmpty) continue;

        String value = '';
        for (int j = i + 1; j < children.length; j++) {
          final nextCell = children[j];
          if (nextCell.localName == 'th') {
            break;
          }
          if (nextCell.localName != 'td') {
            continue;
          }

          final candidate = _normalizeCellText(nextCell.text);
          if (candidate.isNotEmpty && candidate != ':') {
            value = candidate;
            break;
          }
        }

        if (value.isNotEmpty) {
          info[key] = value;
        }
      }
    }

    return info;
  }

  String _normalizeCellText(String raw) {
    return raw.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  (List<String>, List<_MonitoringRow>) _parseMonitoringTable(dynamic doc) {
    dynamic targetTable;

    for (final table in doc.querySelectorAll('table')) {
      final headerTexts = table
          .querySelectorAll('thead th')
          .map((e) => e.text.trim().toLowerCase())
          .toList();
      if (headerTexts.contains('aktifitas')) {
        targetTable = table;
        break;
      }
    }

    if (targetTable == null) return (<String>[], <_MonitoringRow>[]);

    final headers = targetTable
        .querySelectorAll('thead th')
        .map((e) => e.text.trim())
        .toList();

    final periodHeaders = <String>[];
    for (int i = 2; i < headers.length; i++) {
      periodHeaders.add(headers[i]);
    }

    final rows = <_MonitoringRow>[];
    for (final tr in targetTable.querySelectorAll('tbody tr')) {
      final tds = tr.querySelectorAll('td');
      if (tds.length < 2) continue;

      final activity = tds[1].text.trim();
      if (activity.isEmpty || activity.toLowerCase().contains('kontrol tu')) {
        continue;
      }

      final statuses = <bool>[];
      for (int i = 2; i < tds.length; i++) {
        final cell = tds[i];
        final icon = cell.querySelector('i');
        final iconClass = icon?.attributes['class'] ?? '';
        final isDone = iconClass.contains('fa-check-circle');
        statuses.add(isDone);
      }

      rows.add(
        _MonitoringRow(
          no: tds[0].text.trim(),
          activity: activity,
          statuses: statuses,
        ),
      );
    }

    return (periodHeaders, rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.title ?? 'Monitoring TU'),
        backgroundColor: const Color(0xFF073163),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
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
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_errorMessage!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_classInfo.isNotEmpty) _buildInfoCard(),
                    const SizedBox(height: 12),
                    const Text(
                      'Monitoring Perkuliahan',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    if (_rows.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('Belum ada data monitoring.'),
                        ),
                      )
                    else
                      _buildMonitoringTable(),
                  ],
                ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Kelas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._classInfo.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text(': '),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringTable() {
    final columns = <DataColumn>[
      const DataColumn(label: Text('No')),
      const DataColumn(label: Text('Aktifitas')),
      ..._periodHeaders.map((e) => DataColumn(label: Text(e))),
    ];

    final rows = _rows
        .map(
          (row) => DataRow(
            cells: [
              DataCell(Text(row.no)),
              DataCell(SizedBox(width: 180, child: Text(row.activity))),
              ...List.generate(
                _periodHeaders.length,
                (index) {
                  final active =
                      index < row.statuses.length && row.statuses[index];
                  return DataCell(
                    Icon(
                      active
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: active ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  );
                },
              ),
            ],
          ),
        )
        .toList();

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: columns, rows: rows),
      ),
    );
  }
}

class _MonitoringRow {
  final String no;
  final String activity;
  final List<bool> statuses;

  const _MonitoringRow({
    required this.no,
    required this.activity,
    required this.statuses,
  });
}
